-- =========================================================================
-- ADMIN: REPOSITORIO PEDAGÓGICO + PROYECTOS INSTITUCIONALES + DISPONIBILIDAD DDJJ
--
-- Tres áreas del panel de administración que estaban en memoria (mock):
--   1. ped_documentos    — planificaciones / contratos / criterios por materia
--   2. proy_institucionales + proy_documentos — proyectos de la institución
--   3. usr_docentes.disponibilidad — franjas horarias declaradas por el docente,
--      para chequear al reasignar una materia en "Horarios".
--
-- Buckets privados: 'pedagogico' y 'proyectos'.
--
-- Correr COMPLETO. Idempotente.
--   $env:SUPABASE_DB_PASSWORD = "..."   (o SUPABASE_DB_URL en .env)
--   node run_admin_pedagogico_proyectos_horarios_migration.js
-- =========================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────
-- 1. REPOSITORIO PEDAGÓGICO
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ped_documentos (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    curso_id       UUID REFERENCES public.acad_cursos(curso_id) ON DELETE CASCADE,
    materia_id     UUID REFERENCES public.acad_materias(materia_id) ON DELETE CASCADE,
    tipo           TEXT NOT NULL DEFAULT 'PLANIFICACION'
                     CHECK (tipo IN ('PLANIFICACION','CONTRATO','CRITERIOS','OTRO')),
    nombre         TEXT NOT NULL,
    storage_path   TEXT,
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE'
                     CHECK (estado IN ('PENDIENTE','APROBADO','OBSERVADO')),
    observaciones  TEXT,
    subido_por_auth   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    subido_por_nombre TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ped_docs_curso_materia
    ON public.ped_documentos (curso_id, materia_id, created_at DESC);

ALTER TABLE public.ped_documentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ped_docs_select ON public.ped_documentos;
CREATE POLICY ped_docs_select ON public.ped_documentos
    FOR SELECT TO authenticated
    USING (
        public.es_personal_directivo()
        OR materia_id IN (
            SELECT m.materia_id FROM public.acad_materias m
            JOIN public.usr_docentes d ON d.docente_id = m.docente_titular_id
            WHERE d.auth_id = auth.uid()
        )
        OR public.docente_dicta_materia_curso(materia_id, curso_id)
    );

DROP POLICY IF EXISTS ped_docs_insert ON public.ped_documentos;
CREATE POLICY ped_docs_insert ON public.ped_documentos
    FOR INSERT TO authenticated
    WITH CHECK (
        (subido_por_auth IS NULL OR subido_por_auth = auth.uid())
        AND (
            public.es_personal_directivo()
            OR public.docente_dicta_materia_curso(materia_id, curso_id)
        )
    );

DROP POLICY IF EXISTS ped_docs_update ON public.ped_documentos;
CREATE POLICY ped_docs_update ON public.ped_documentos
    FOR UPDATE TO authenticated
    USING (public.es_personal_directivo())
    WITH CHECK (public.es_personal_directivo());

DROP POLICY IF EXISTS ped_docs_delete ON public.ped_documentos;
CREATE POLICY ped_docs_delete ON public.ped_documentos
    FOR DELETE TO authenticated
    USING (public.es_personal_directivo() OR subido_por_auth = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- 2. PROYECTOS INSTITUCIONALES
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.proy_institucionales (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre         TEXT NOT NULL,
    descripcion    TEXT,
    responsable    TEXT,
    estado         TEXT NOT NULL DEFAULT 'EN_CURSO'
                     CHECK (estado IN ('PLANIFICADO','EN_CURSO','FINALIZADO','SUSPENDIDO')),
    fecha_inicio   DATE,
    fecha_fin      DATE,
    creado_por     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.proy_documentos (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proyecto_id    UUID NOT NULL REFERENCES public.proy_institucionales(id) ON DELETE CASCADE,
    nombre         TEXT NOT NULL,
    storage_path   TEXT,
    subido_por_nombre TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_proy_docs_proyecto ON public.proy_documentos (proyecto_id);

ALTER TABLE public.proy_institucionales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proy_documentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS proy_select ON public.proy_institucionales;
CREATE POLICY proy_select ON public.proy_institucionales
    FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS proy_write ON public.proy_institucionales;
CREATE POLICY proy_write ON public.proy_institucionales
    FOR ALL TO authenticated
    USING (public.es_personal_directivo())
    WITH CHECK (public.es_personal_directivo());

DROP POLICY IF EXISTS proy_docs_select ON public.proy_documentos;
CREATE POLICY proy_docs_select ON public.proy_documentos
    FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS proy_docs_write ON public.proy_documentos;
CREATE POLICY proy_docs_write ON public.proy_documentos
    FOR ALL TO authenticated
    USING (public.es_personal_directivo())
    WITH CHECK (public.es_personal_directivo());

-- ─────────────────────────────────────────────────────────────────────────
-- 3. DISPONIBILIDAD HORARIA DECLARADA (DDJJ)
--    JSONB: [{"dia":"LUNES","desde":"07:00","hasta":"12:00"}, ...]
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.usr_docentes
    ADD COLUMN IF NOT EXISTS disponibilidad JSONB NOT NULL DEFAULT '[]'::jsonb;

-- El docente puede editar SU disponibilidad; dirección, la de cualquiera.
-- (La política de update de usr_docentes ya existe; se re-crea incluyendo
--  el caso "es el propio docente".)
DROP POLICY IF EXISTS usr_docentes_update_self_or_dir ON public.usr_docentes;
CREATE POLICY usr_docentes_update_self_or_dir ON public.usr_docentes
    FOR UPDATE TO authenticated
    USING (auth_id = auth.uid() OR public.es_personal_directivo())
    WITH CHECK (auth_id = auth.uid() OR public.es_personal_directivo());

-- ─────────────────────────────────────────────────────────────────────────
-- 4. BUCKETS
-- ─────────────────────────────────────────────────────────────────────────
DO $st$
BEGIN
    INSERT INTO storage.buckets (id, name, public) VALUES ('pedagogico','pedagogico',false) ON CONFLICT (id) DO NOTHING;
    INSERT INTO storage.buckets (id, name, public) VALUES ('proyectos','proyectos',false) ON CONFLICT (id) DO NOTHING;
    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "ped_proy objetos rw autenticados" ON storage.objects';
        EXECUTE 'CREATE POLICY "ped_proy objetos rw autenticados" ON storage.objects
                 FOR ALL TO authenticated
                 USING (bucket_id IN (''pedagogico'',''proyectos''))
                 WITH CHECK (bucket_id IN (''pedagogico'',''proyectos''))';
    EXCEPTION WHEN insufficient_privilege OR undefined_table THEN
        RAISE NOTICE 'Sin permiso para políticas de storage.objects: configurar buckets desde el dashboard.';
    END;
EXCEPTION WHEN insufficient_privilege OR undefined_table THEN
    RAISE NOTICE 'Sin permiso sobre storage: crear buckets pedagogico y proyectos (privados) a mano.';
END
$st$;

COMMIT;
