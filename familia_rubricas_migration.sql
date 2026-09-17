-- =========================================================================
-- FAMILIA: lectura de rúbricas cualitativas y cierres de etapa
--
-- aca_rubricas_cualitativas / aca_cierres_etapa sólo tenían políticas de
-- lectura para personal (ADMIN/DIRECTIVO/PRECEPTOR/DOCENTE) y para el propio
-- ALUMNO. La familia (rol PADRE, modelada como fila en usr_legajo_alumno con
-- rol_financiero='RESPONSABLE_PAGO', agrupada por grupo_id junto a sus hijos)
-- no tenía ninguna política: el Boletín RITE del portal de familia quedaba
-- siempre vacío en la parte de criterios cualitativos.
--
-- Correr COMPLETO. Idempotente.
--   node run_familia_rubricas_migration.js
-- =========================================================================

BEGIN;

DROP POLICY IF EXISTS "familia_rubricas_read" ON public.aca_rubricas_cualitativas;
CREATE POLICY "familia_rubricas_read" ON public.aca_rubricas_cualitativas
    FOR SELECT TO authenticated
    USING (
        alumno_id IN (
            SELECT legajo_id FROM public.usr_legajo_alumno
            WHERE grupo_id = (
                SELECT grupo_id FROM public.usr_legajo_alumno
                WHERE auth_id = auth.uid() LIMIT 1
            )
        )
    );

DROP POLICY IF EXISTS "familia_cierres_read" ON public.aca_cierres_etapa;
CREATE POLICY "familia_cierres_read" ON public.aca_cierres_etapa
    FOR SELECT TO authenticated
    USING (
        alumno_id IN (
            SELECT legajo_id FROM public.usr_legajo_alumno
            WHERE grupo_id = (
                SELECT grupo_id FROM public.usr_legajo_alumno
                WHERE auth_id = auth.uid() LIMIT 1
            )
        )
    );

COMMIT;
