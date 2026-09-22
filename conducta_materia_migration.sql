-- =========================================================================
-- CONDUCTA: MATERIA DE ORIGEN (para poder filtrar por materia)
--
-- aca_conducta no guardaba de qué materia salía cada registro de Conducta
-- Diaria (se tomaba desde la pantalla de una materia puntual, pero esa
-- referencia se perdía). Esto agrega la columna para poder filtrar el
-- historial por materia además de por curso.
--
-- Los registros de "Conducta (Sanciones)" no tienen materia asociada
-- (son incidencias generales, no de una clase puntual): la columna queda
-- NULL para esos y el filtro por materia los ignora, igual que a los
-- registros de Conducta Diaria cargados antes de esta migración.
--
-- Correr COMPLETO. Idempotente.
--   node run_conducta_materia_migration.js
-- =========================================================================

BEGIN;

ALTER TABLE public.aca_conducta
    ADD COLUMN IF NOT EXISTS materia_id UUID REFERENCES public.acad_materias(materia_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_aca_conducta_materia ON public.aca_conducta (materia_id);

COMMIT;
