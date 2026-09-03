-- ================================================================
-- CORRECCIONES CRÍTICAS: Asistencia + Categorías de Notas
-- Ejecutar en Supabase SQL Editor → una sola vez
-- ================================================================

-- ----------------------------------------------------------------
-- BUG 1: UNIQUE constraint demasiado restrictivo en asistencia_cabecera
--
-- El constraint original (curso_id, fecha) sólo permite UNA sola
-- asistencia por curso por día. Esto rompe el modelo de "asistencia
-- del preceptor" + "asistencia por materia" en el mismo día, y
-- también impide que el mismo preceptor re-guarde si hubo un error.
-- ----------------------------------------------------------------

-- Paso 1A: Eliminar el constraint original
ALTER TABLE asistencia_cabecera
  DROP CONSTRAINT IF EXISTS unique_curso_fecha;

-- Paso 1B: Asegurar que las columnas de la migración actas_y_asistencia existen
ALTER TABLE asistencia_cabecera
  ADD COLUMN IF NOT EXISTS tipo_asistencia VARCHAR(50) DEFAULT 'PRECEPTOR_DIARIA',
  ADD COLUMN IF NOT EXISTS materia_id UUID REFERENCES acad_materias(materia_id) ON DELETE SET NULL;

-- Paso 1C: Crear índices únicos parciales (reemplazo correcto del constraint)

-- Solo UNA asistencia de preceptor por curso por día
CREATE UNIQUE INDEX IF NOT EXISTS uq_asistencia_preceptor
  ON asistencia_cabecera(curso_id, fecha)
  WHERE tipo_asistencia = 'PRECEPTOR_DIARIA';

-- Solo UNA asistencia por materia (docente) por curso por día
CREATE UNIQUE INDEX IF NOT EXISTS uq_asistencia_por_materia
  ON asistencia_cabecera(curso_id, fecha, materia_id)
  WHERE tipo_asistencia = 'POR_MATERIA' AND materia_id IS NOT NULL;

-- Índice de soporte para consultas del panel mensual
CREATE INDEX IF NOT EXISTS idx_asistencia_cabecera_tipo
  ON asistencia_cabecera(tipo_asistencia, curso_id, materia_id, fecha);


-- ----------------------------------------------------------------
-- BUG 2: Categorías de notas no aparecen para los docentes
--
-- Las categorías globales del seed (Evidencias, Desempeño, Autoevaluación)
-- tienen materia_id = NULL. La consulta del Dart filtraba EXACTAMENTE
-- por materia_id = <uuid>, así que nunca devolvía nada.
--
-- Corrección en el Dart: ya actualizado en supabase_service.dart
-- (usa OR: materia_id = <uuid> OR materia_id IS NULL)
--
-- Corrección aquí: arreglar el RLS de escritura para que los docentes
-- puedan crear sus propias categorías (actualmente solo ADMIN/PRECEPTOR).
-- ----------------------------------------------------------------

-- Eliminar la política restrictiva anterior
DROP POLICY IF EXISTS write_categorias ON aca_categorias_nota;

-- Nueva política: ADMIN y PRECEPTOR pueden todo;
-- los DOCENTES pueden crear/editar/eliminar SOLO las categorías
-- vinculadas a las materias que dictan (materia_id no nulo).
CREATE POLICY write_categorias ON aca_categorias_nota
  FOR ALL TO authenticated
  USING (
    -- Opción A: Es admin o preceptor → acceso total
    EXISTS (
      SELECT 1 FROM usr_docentes
      WHERE auth_id = auth.uid()
        AND (ddjj_cargos::text ILIKE '%ADMIN%' OR ddjj_cargos::text ILIKE '%PRECEPTOR%')
    )
    OR
    -- Opción B: Es docente titular de la materia → acceso a SUS categorías
    (
      materia_id IS NOT NULL
      AND materia_id IN (
        SELECT materia_id FROM acad_materias
        WHERE docente_titular_id = (
          SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1
        )
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM usr_docentes
      WHERE auth_id = auth.uid()
        AND (ddjj_cargos::text ILIKE '%ADMIN%' OR ddjj_cargos::text ILIKE '%PRECEPTOR%')
    )
    OR
    (
      materia_id IS NOT NULL
      AND materia_id IN (
        SELECT materia_id FROM acad_materias
        WHERE docente_titular_id = (
          SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1
        )
      )
    )
  );


-- ----------------------------------------------------------------
-- BUG 3 (preventivo): asistencia_detalle — RLS también debe cubrir
-- el INSERT a través de docentes además de preceptores, para que el
-- guardian check no rechace el insert del detalle luego de que la
-- cabecera ya fue creada correctamente.
-- (Re-crear la política existente para incluir el modelo híbrido)
-- ----------------------------------------------------------------

DROP POLICY IF EXISTS docente_asistencia_detalle_all ON asistencia_detalle;

CREATE POLICY docente_asistencia_detalle_all ON asistencia_detalle
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM usr_docentes
      WHERE auth_id = auth.uid()
        AND (ddjj_cargos::text ILIKE '%PRECEPTOR%' OR ddjj_cargos::text ILIKE '%ADMIN%')
    )
    OR
    asistencia_cabecera_id IN (
      SELECT asistencia_cabecera_id
      FROM asistencia_cabecera
      WHERE registrado_por_docente_id = (
        SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM usr_docentes
      WHERE auth_id = auth.uid()
        AND (ddjj_cargos::text ILIKE '%PRECEPTOR%' OR ddjj_cargos::text ILIKE '%ADMIN%')
    )
    OR
    asistencia_cabecera_id IN (
      SELECT asistencia_cabecera_id
      FROM asistencia_cabecera
      WHERE registrado_por_docente_id = (
        SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1
      )
    )
  );


-- ----------------------------------------------------------------
-- VERIFICACIÓN: ejecutar estos SELECT para confirmar el estado
-- ----------------------------------------------------------------

-- Ver cuántas cabeceras de asistencia hay por tipo:
-- SELECT tipo_asistencia, COUNT(*) FROM asistencia_cabecera GROUP BY tipo_asistencia;

-- Ver categorías globales vs por materia:
-- SELECT nombre, materia_id, peso_porcentaje FROM aca_categorias_nota ORDER BY materia_id NULLS FIRST;
