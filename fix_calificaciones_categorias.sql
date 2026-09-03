-- ================================================================
-- MIGRACIÓN: Sistema de calificaciones libre (sin categorías fijas)
-- Ejecutar en Supabase SQL Editor → una sola vez
-- ================================================================

-- 1. Hacer categoria_id opcional en aca_actividades
--    (los docentes pueden crear notas sin asignar categoría)
ALTER TABLE aca_actividades
  ALTER COLUMN categoria_id DROP NOT NULL;

-- 2. Agregar columna tipo_actividad para distinguir tipos sin depender del prefijo del título
ALTER TABLE aca_actividades
  ADD COLUMN IF NOT EXISTS tipo_actividad VARCHAR(20) DEFAULT 'NOTA'
    CHECK (tipo_actividad IN ('NOTA', 'TAREA', 'CLASE', 'INFO', 'CONDUCTA'));

-- 3. Migrar tipos desde el prefijo del título (para datos existentes)
UPDATE aca_actividades SET tipo_actividad = 'TAREA'    WHERE titulo ILIKE '[TAREA]%'    AND tipo_actividad = 'NOTA';
UPDATE aca_actividades SET tipo_actividad = 'INFO'     WHERE titulo ILIKE '[INFO]%'     AND tipo_actividad = 'NOTA';
UPDATE aca_actividades SET tipo_actividad = 'CONDUCTA' WHERE titulo ILIKE '[CONDUCTA]%' AND tipo_actividad = 'NOTA';

-- 4. Eliminar las categorías globales del seed (Evidencias / Desempeño / Autoevaluación)
--    que no tienen materia asignada: ya no las necesitamos como categorías obligatorias.
--    ATENCIÓN: esto solo borra las globales (materia_id IS NULL).
--    Las categorías que los docentes crearon para sus materias se conservan.
DELETE FROM aca_categorias_nota WHERE materia_id IS NULL;

-- 5. Verificación (descomentá para revisar):
-- SELECT tipo_actividad, COUNT(*) FROM aca_actividades GROUP BY tipo_actividad;
-- SELECT COUNT(*) FROM aca_categorias_nota WHERE materia_id IS NULL; -- debe ser 0
