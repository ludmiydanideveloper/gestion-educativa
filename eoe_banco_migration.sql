-- =========================================================================
-- EOE (ADECUACIONES CURRICULARES) + BANCO DE EVALUACIONES
--
-- Hasta ahora:
--   * El panel EOE (docente y administración) guardaba bitácora, informes y
--     observaciones sólo en memoria: nada persistía.
--   * banco_evaluaciones existía (fix_banco_evaluaciones.sql) pero sin curso,
--     sin archivo real y con RLS sólo por materia.
--
-- Esta migración crea:
--   1. eoe_ficha        — una ficha por alumno con adecuación (+ formulario JSONB)
--   2. eoe_bitacora     — notas de acompañamiento (gabinete y docentes)
--   3. eoe_documentos   — informes / pautas / evaluaciones (archivo en Storage)
--   4. helper docente_ve_legajo() para las políticas RLS
--   5. columnas nuevas en banco_evaluaciones (curso_id, storage_path, autor)
--   6. buckets privados de Storage: 'eoe' y 'banco-evaluaciones'
--
-- Correr el archivo COMPLETO. Es idempotente.
--     $env:SUPABASE_DB_PASSWORD = "<password de postgres>"
--     node run_eoe_banco_migration.js
-- =========================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────
-- 0. HELPER: ¿el usuario actual (docente) tiene a este alumno en alguno de
--    sus cursos? Se usa en todas las políticas RLS de EOE.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.docente_ve_legajo(p_legajo_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $ve$
    SELECT p_legajo_id IS NOT NULL AND EXISTS (
        SELECT 1
        FROM public.acad_inscripciones ins
        JOIN public.acad_docente_materia_curso dmc ON dmc.curso_id = ins.curso_id
        JOIN public.usr_docentes d ON d.docente_id = dmc.docente_id
        WHERE d.auth_id = auth.uid()
          AND ins.alumno_id = p_legajo_id
    );
$ve$;

GRANT EXECUTE ON FUNCTION public.docente_ve_legajo(UUID) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 1. EOE_FICHA
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.eoe_ficha (
    legajo_id       UUID PRIMARY KEY REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    activa          BOOLEAN NOT NULL DEFAULT true,
    tipo_adecuacion TEXT,
    detalles        TEXT,
    datos_formulario JSONB NOT NULL DEFAULT '{}'::jsonb,
    actualizado_por UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.eoe_ficha ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eoe_ficha_select ON public.eoe_ficha;
CREATE POLICY eoe_ficha_select ON public.eoe_ficha
    FOR SELECT TO authenticated
    USING (public.es_personal_directivo() OR public.docente_ve_legajo(legajo_id));

DROP POLICY IF EXISTS eoe_ficha_write ON public.eoe_ficha;
CREATE POLICY eoe_ficha_write ON public.eoe_ficha
    FOR ALL TO authenticated
    USING (public.es_personal_directivo())
    WITH CHECK (public.es_personal_directivo());

-- ─────────────────────────────────────────────────────────────────────────
-- 2. EOE_BITACORA
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.eoe_bitacora (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legajo_id    UUID NOT NULL REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    autor_auth   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    autor_nombre TEXT,
    autor_rol    TEXT,                       -- 'EOE' | 'ADMIN' | 'DOCENTE'
    nota         TEXT NOT NULL,
    fecha        DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eoe_bitacora_legajo ON public.eoe_bitacora (legajo_id, fecha DESC);

ALTER TABLE public.eoe_bitacora ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eoe_bitacora_select ON public.eoe_bitacora;
CREATE POLICY eoe_bitacora_select ON public.eoe_bitacora
    FOR SELECT TO authenticated
    USING (public.es_personal_directivo() OR public.docente_ve_legajo(legajo_id));

DROP POLICY IF EXISTS eoe_bitacora_insert ON public.eoe_bitacora;
CREATE POLICY eoe_bitacora_insert ON public.eoe_bitacora
    FOR INSERT TO authenticated
    WITH CHECK (
        (autor_auth IS NULL OR autor_auth = auth.uid())
        AND (public.es_personal_directivo() OR public.docente_ve_legajo(legajo_id))
    );

DROP POLICY IF EXISTS eoe_bitacora_update ON public.eoe_bitacora;
CREATE POLICY eoe_bitacora_update ON public.eoe_bitacora
    FOR UPDATE TO authenticated
    USING (autor_auth = auth.uid() OR public.es_personal_directivo())
    WITH CHECK (autor_auth = auth.uid() OR public.es_personal_directivo());

DROP POLICY IF EXISTS eoe_bitacora_delete ON public.eoe_bitacora;
CREATE POLICY eoe_bitacora_delete ON public.eoe_bitacora
    FOR DELETE TO authenticated
    USING (autor_auth = auth.uid() OR public.es_personal_directivo());

-- ─────────────────────────────────────────────────────────────────────────
-- 3. EOE_DOCUMENTOS
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.eoe_documentos (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legajo_id         UUID NOT NULL REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    nombre            TEXT NOT NULL,
    categoria         TEXT NOT NULL DEFAULT 'INFORME'
                        CHECK (categoria IN ('INFORME','PAUTAS','EVAL_ORIGINAL','EVAL_ADECUADA')),
    storage_path      TEXT,
    observaciones_eoe TEXT,
    estado            TEXT NOT NULL DEFAULT 'PENDIENTE'
                        CHECK (estado IN ('PENDIENTE','ADECUADA','ARCHIVADA')),
    subido_por_auth   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    subido_por_nombre TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eoe_documentos_legajo ON public.eoe_documentos (legajo_id, created_at DESC);

ALTER TABLE public.eoe_documentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eoe_docs_select ON public.eoe_documentos;
CREATE POLICY eoe_docs_select ON public.eoe_documentos
    FOR SELECT TO authenticated
    USING (public.es_personal_directivo() OR public.docente_ve_legajo(legajo_id));

-- Alta: dirección todo; el docente sólo puede subir la evaluación ORIGINAL
-- para que el gabinete la adecúe.
DROP POLICY IF EXISTS eoe_docs_insert ON public.eoe_documentos;
CREATE POLICY eoe_docs_insert ON public.eoe_documentos
    FOR INSERT TO authenticated
    WITH CHECK (
        (subido_por_auth IS NULL OR subido_por_auth = auth.uid())
        AND (
            public.es_personal_directivo()
            OR (categoria = 'EVAL_ORIGINAL' AND public.docente_ve_legajo(legajo_id))
        )
    );

DROP POLICY IF EXISTS eoe_docs_update ON public.eoe_documentos;
CREATE POLICY eoe_docs_update ON public.eoe_documentos
    FOR UPDATE TO authenticated
    USING (public.es_personal_directivo())
    WITH CHECK (public.es_personal_directivo());

DROP POLICY IF EXISTS eoe_docs_delete ON public.eoe_documentos;
CREATE POLICY eoe_docs_delete ON public.eoe_documentos
    FOR DELETE TO authenticated
    USING (public.es_personal_directivo() OR subido_por_auth = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- 4. BANCO DE EVALUACIONES  (tabla + columnas nuevas + RLS por materia/curso)
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.banco_evaluaciones (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    materia_id    UUID REFERENCES public.acad_materias(materia_id) ON DELETE CASCADE,
    titulo        TEXT NOT NULL,
    descripcion   TEXT,
    tipo          TEXT DEFAULT 'Parcial Trimestral',
    archivo_url   TEXT,
    estado        TEXT DEFAULT 'PENDIENTE DE APROBACIÓN'
                    CHECK (estado IN ('PENDIENTE DE APROBACIÓN', 'APROBADA', 'RECHAZADA')),
    subido_por    TEXT,
    created_at    TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.banco_evaluaciones
    ADD COLUMN IF NOT EXISTS curso_id        UUID REFERENCES public.acad_cursos(curso_id) ON DELETE CASCADE;
ALTER TABLE public.banco_evaluaciones
    ADD COLUMN IF NOT EXISTS storage_path    TEXT;
ALTER TABLE public.banco_evaluaciones
    ADD COLUMN IF NOT EXISTS subido_por_auth UUID REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_banco_eval_materia_curso
    ON public.banco_evaluaciones (materia_id, curso_id, created_at DESC);

ALTER TABLE public.banco_evaluaciones ENABLE ROW LEVEL SECURITY;

-- ¿El docente actual dicta esta materia en este curso?
CREATE OR REPLACE FUNCTION public.docente_dicta_materia_curso(p_materia_id UUID, p_curso_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $dmc$
    SELECT EXISTS (
        SELECT 1
        FROM public.acad_docente_materia_curso dmc
        JOIN public.usr_docentes d ON d.docente_id = dmc.docente_id
        WHERE d.auth_id = auth.uid()
          AND dmc.materia_id = p_materia_id
          AND (p_curso_id IS NULL OR dmc.curso_id = p_curso_id)
    )
    OR EXISTS (
        SELECT 1 FROM public.acad_materias m
        JOIN public.usr_docentes d ON d.docente_id = m.docente_titular_id
        WHERE d.auth_id = auth.uid() AND m.materia_id = p_materia_id
    );
$dmc$;
GRANT EXECUTE ON FUNCTION public.docente_dicta_materia_curso(UUID, UUID) TO authenticated;

DROP POLICY IF EXISTS banco_eval_select ON public.banco_evaluaciones;
DROP POLICY IF EXISTS banco_eval_insert ON public.banco_evaluaciones;
DROP POLICY IF EXISTS banco_eval_update ON public.banco_evaluaciones;
DROP POLICY IF EXISTS banco_eval_delete ON public.banco_evaluaciones;

CREATE POLICY banco_eval_select ON public.banco_evaluaciones
    FOR SELECT TO authenticated
    USING (public.es_personal_directivo() OR public.docente_dicta_materia_curso(materia_id, curso_id));

CREATE POLICY banco_eval_insert ON public.banco_evaluaciones
    FOR INSERT TO authenticated
    WITH CHECK (
        (subido_por_auth IS NULL OR subido_por_auth = auth.uid())
        AND (public.es_personal_directivo() OR public.docente_dicta_materia_curso(materia_id, curso_id))
    );

CREATE POLICY banco_eval_update ON public.banco_evaluaciones
    FOR UPDATE TO authenticated
    USING (public.es_personal_directivo())
    WITH CHECK (public.es_personal_directivo());

CREATE POLICY banco_eval_delete ON public.banco_evaluaciones
    FOR DELETE TO authenticated
    USING (public.es_personal_directivo() OR subido_por_auth = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- 5. ÍNDICE DE CALENDARIO POR MATERIA (las "Fechas Importantes" filtran por
--    materia; acad_calendario.materia_id ya existe por db_completa_migration).
-- ─────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_acad_calendario_curso_materia
    ON public.acad_calendario (curso_id, materia_id, fecha);

-- ─────────────────────────────────────────────────────────────────────────
-- 6. BUCKETS DE STORAGE (privados)
--    Si el rol de conexión no tiene permisos sobre el schema storage, se
--    avisa y se sigue: crear los buckets 'eoe' y 'banco-evaluaciones'
--    (privados) queda como paso manual desde el dashboard de Supabase.
-- ─────────────────────────────────────────────────────────────────────────
DO $storage$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('eoe', 'eoe', false) ON CONFLICT (id) DO NOTHING;

    INSERT INTO storage.buckets (id, name, public)
    VALUES ('banco-evaluaciones', 'banco-evaluaciones', false) ON CONFLICT (id) DO NOTHING;

    -- Cualquier autenticado puede subir/leer objetos de estos buckets; el
    -- control fino queda en las políticas de las tablas y en que la app sólo
    -- genera signed URLs para los registros que el usuario ya ve.
    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "eoe_banco objetos rw autenticados" ON storage.objects';
        EXECUTE 'CREATE POLICY "eoe_banco objetos rw autenticados" ON storage.objects
                 FOR ALL TO authenticated
                 USING (bucket_id IN (''eoe'', ''banco-evaluaciones''))
                 WITH CHECK (bucket_id IN (''eoe'', ''banco-evaluaciones''))';
    EXCEPTION WHEN insufficient_privilege OR undefined_table THEN
        RAISE NOTICE 'Sin permiso para políticas de storage.objects: configurar el bucket desde el dashboard.';
    END;
EXCEPTION WHEN insufficient_privilege OR undefined_table THEN
    RAISE NOTICE 'Sin permiso sobre schema storage: crear los buckets eoe y banco-evaluaciones (privados) manualmente.';
END
$storage$;

COMMIT;

-- =========================================================================
-- VERIFICACIÓN
--   SELECT table_name FROM information_schema.tables
--     WHERE table_name IN ('eoe_ficha','eoe_bitacora','eoe_documentos');
--   SELECT column_name FROM information_schema.columns
--     WHERE table_name = 'banco_evaluaciones' AND column_name IN ('curso_id','storage_path');
--   SELECT id FROM storage.buckets WHERE id IN ('eoe','banco-evaluaciones');
-- =========================================================================
