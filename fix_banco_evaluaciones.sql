-- ================================================================
-- MIGRACIÓN: Banco de Evaluaciones
-- Ejecutar en Supabase SQL Editor → una sola vez
-- ================================================================

CREATE TABLE IF NOT EXISTS banco_evaluaciones (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  materia_id    UUID REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
  titulo        TEXT NOT NULL,
  descripcion   TEXT,
  tipo          TEXT DEFAULT 'Parcial Trimestral',
  archivo_url   TEXT,
  estado        TEXT DEFAULT 'PENDIENTE DE APROBACIÓN'
                  CHECK (estado IN ('PENDIENTE DE APROBACIÓN', 'APROBADA', 'RECHAZADA')),
  subido_por    TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- RLS: docentes ven solo las evaluaciones de sus materias
ALTER TABLE banco_evaluaciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS banco_eval_select ON banco_evaluaciones;
CREATE POLICY banco_eval_select ON banco_evaluaciones
  FOR SELECT TO authenticated
  USING (
    materia_id IN (
      SELECT materia_id FROM acad_materias
      WHERE docente_titular_id = (
        SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1
      )
    )
    OR EXISTS (
      SELECT 1 FROM usr_docentes
      WHERE auth_id = auth.uid()
        AND (ddjj_cargos::text ILIKE '%ADMIN%' OR ddjj_cargos::text ILIKE '%PRECEPTOR%')
    )
  );

DROP POLICY IF EXISTS banco_eval_insert ON banco_evaluaciones;
CREATE POLICY banco_eval_insert ON banco_evaluaciones
  FOR INSERT TO authenticated
  WITH CHECK (
    materia_id IN (
      SELECT materia_id FROM acad_materias
      WHERE docente_titular_id = (
        SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1
      )
    )
  );

DROP POLICY IF EXISTS banco_eval_update ON banco_evaluaciones;
CREATE POLICY banco_eval_update ON banco_evaluaciones
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM usr_docentes
      WHERE auth_id = auth.uid()
        AND (ddjj_cargos::text ILIKE '%ADMIN%' OR ddjj_cargos::text ILIKE '%PRECEPTOR%')
    )
  );

-- Verificación:
-- SELECT COUNT(*) FROM banco_evaluaciones;
