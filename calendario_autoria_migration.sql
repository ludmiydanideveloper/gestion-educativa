-- =========================================================================
-- CALENDARIO: AUTORÍA DE LOS EVENTOS
--
-- acad_calendario no guardaba quién creaba cada evento, y la política de
-- escritura era "cualquier fila de usr_docentes puede todo": un docente podía
-- borrar o editar la evaluación de otro, y desde la app no había forma de
-- ofrecer "modificar" o "eliminar" porque no se sabía de quién era.
--
-- Correr el archivo COMPLETO. Es idempotente.
--     $env:SUPABASE_DB_PASSWORD = "<password de postgres>"
--     node run_calendario_autoria_migration.js
-- =========================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────
-- 1. AUTOR DEL EVENTO
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.acad_calendario
    ADD COLUMN IF NOT EXISTS creado_por UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.acad_calendario
    ADD COLUMN IF NOT EXISTS docente_id UUID REFERENCES public.usr_docentes(docente_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_acad_calendario_autor
    ON public.acad_calendario (creado_por);

-- ─────────────────────────────────────────────────────────────────────────
-- 2. ¿EL USUARIO ACTUAL DICTA EN ESE CURSO?
--    Se usa para los eventos que ya existían y no tienen autor: los puede
--    mantener cualquier docente del curso, en vez de quedar bloqueados.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dicta_en_curso(p_curso_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $dicta$
    SELECT p_curso_id IS NOT NULL AND EXISTS (
        SELECT 1
        FROM public.acad_docente_materia_curso dmc
        JOIN public.usr_docentes d ON d.docente_id = dmc.docente_id
        WHERE d.auth_id = auth.uid()
          AND dmc.curso_id = p_curso_id
    );
$dicta$;

GRANT EXECUTE ON FUNCTION public.dicta_en_curso(UUID) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 3. POLÍTICAS
--    Lectura: sin cambios, cualquier autenticado.
--    Alta:    cualquier docente, pero firmando el evento como propio.
--    Edición y borrado: sólo el autor, dirección, o —para los eventos
--    heredados sin autor— un docente que dicte en ese curso.
-- ─────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Permitir escritura de calendario para personal" ON public.acad_calendario;
DROP POLICY IF EXISTS calendario_insert ON public.acad_calendario;
DROP POLICY IF EXISTS calendario_update ON public.acad_calendario;
DROP POLICY IF EXISTS calendario_delete ON public.acad_calendario;

CREATE POLICY calendario_insert ON public.acad_calendario
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.usr_docentes WHERE auth_id = auth.uid())
        AND (creado_por IS NULL OR creado_por = auth.uid())
    );

CREATE POLICY calendario_update ON public.acad_calendario
    FOR UPDATE TO authenticated
    USING (
        creado_por = auth.uid()
        OR public.es_personal_directivo()
        OR (creado_por IS NULL AND public.dicta_en_curso(curso_id))
    )
    WITH CHECK (
        creado_por = auth.uid()
        OR public.es_personal_directivo()
        OR (creado_por IS NULL AND public.dicta_en_curso(curso_id))
    );

CREATE POLICY calendario_delete ON public.acad_calendario
    FOR DELETE TO authenticated
    USING (
        creado_por = auth.uid()
        OR public.es_personal_directivo()
        OR (creado_por IS NULL AND public.dicta_en_curso(curso_id))
    );

COMMIT;
