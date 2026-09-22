-- =========================================================================
-- RITE: PERÍODOS DE INTENSIFICACIÓN + ACCESO DEL DOCENTE TITULAR
--
-- acad_materias_adeudadas ya existía (con materia_original_id real), pero
-- panel_materias_adeudadas.dart era una lista inventada en memoria y nunca
-- la tocaba. Esto agrega:
--   1. acad_adeudadas_periodos — historial de mesas/coloquios de
--      intensificación (Febrero, Marzo, la que Dirección abra), con nota y
--      resultado, para las materias con condición PENDIENTE_ACREDITACION.
--   2. Política para que el docente TITULAR de la materia original cargue
--      esas notas desde su propio panel (antes solo podía Dirección).
--
-- condicion usa los códigos ya definidos por el CHECK existente:
--   REGULAR                → "Recursa" (cursa la materia de nuevo, este año)
--   PENDIENTE_ACREDITACION → "Intensifica" (rinde coloquios por período)
--   PREVIA_LIBRE           → "Adeuda Previa" (materia de un año no adyacente)
--
-- Correr COMPLETO. Idempotente.
--   node run_rite_adeudadas_periodos_migration.js
-- =========================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────
-- 1. ¿El usuario autenticado es el docente titular de la materia original
--    de esta adeudada?
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.docente_titular_de_adeudada(p_adeudada_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $adeu$
    SELECT EXISTS (
        SELECT 1
        FROM public.acad_materias_adeudadas a
        JOIN public.acad_materias m ON m.materia_id = a.materia_original_id
        JOIN public.usr_docentes d ON d.docente_id = m.docente_titular_id
        WHERE a.adeudada_id = p_adeudada_id
          AND d.auth_id = auth.uid()
    );
$adeu$;

GRANT EXECUTE ON FUNCTION public.docente_titular_de_adeudada(UUID) TO authenticated;

-- El docente titular también puede actualizar el estado/nota de su propia
-- adeudada (ademas de Dirección, que ya tenía acceso total).
DROP POLICY IF EXISTS docente_titular_update_adeudada ON public.acad_materias_adeudadas;
CREATE POLICY docente_titular_update_adeudada ON public.acad_materias_adeudadas
    FOR UPDATE TO authenticated
    USING (public.docente_titular_de_adeudada(adeudada_id))
    WITH CHECK (public.docente_titular_de_adeudada(adeudada_id));

-- ─────────────────────────────────────────────────────────────────────────
-- 2. HISTORIAL DE PERÍODOS DE INTENSIFICACIÓN
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.acad_adeudadas_periodos (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    adeudada_id            UUID NOT NULL REFERENCES public.acad_materias_adeudadas(adeudada_id) ON DELETE CASCADE,
    periodo                TEXT NOT NULL,
    nota                   NUMERIC(4,2),
    resultado              TEXT NOT NULL DEFAULT 'PENDIENTE'
                             CHECK (resultado IN ('PENDIENTE','APROBADO','DESAPROBADO')),
    registrado_por_auth    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    registrado_por_nombre  TEXT,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_adeudadas_periodos_adeudada
    ON public.acad_adeudadas_periodos (adeudada_id, created_at);

ALTER TABLE public.acad_adeudadas_periodos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS adeudadas_periodos_select ON public.acad_adeudadas_periodos;
CREATE POLICY adeudadas_periodos_select ON public.acad_adeudadas_periodos
    FOR SELECT TO authenticated
    USING (
        public.es_personal_directivo()
        OR public.docente_titular_de_adeudada(adeudada_id)
        OR EXISTS (SELECT 1 FROM public.usr_docentes WHERE auth_id = auth.uid())
        OR EXISTS (
            SELECT 1 FROM public.acad_materias_adeudadas a
            JOIN public.usr_legajo_alumno la ON la.legajo_id = a.alumno_id
            WHERE a.adeudada_id = acad_adeudadas_periodos.adeudada_id
              AND la.auth_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS adeudadas_periodos_write ON public.acad_adeudadas_periodos;
CREATE POLICY adeudadas_periodos_write ON public.acad_adeudadas_periodos
    FOR ALL TO authenticated
    USING (public.es_personal_directivo() OR public.docente_titular_de_adeudada(adeudada_id))
    WITH CHECK (public.es_personal_directivo() OR public.docente_titular_de_adeudada(adeudada_id));

COMMIT;
