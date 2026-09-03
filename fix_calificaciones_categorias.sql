-- ================================================================
-- MIGRACIÓN: Sistema de calificaciones libre (sin categorías fijas)
-- Ejecutar en Supabase SQL Editor → una sola vez
--
-- ⚠ VERSIÓN CORREGIDA. La versión anterior de este archivo terminaba con
--   DELETE FROM aca_categorias_nota WHERE materia_id IS NULL;
--   Eso era DESTRUCTIVO: aca_actividades.categoria_id referencia a
--   aca_categorias_nota ON DELETE CASCADE, y aca_calificaciones.actividad_id
--   referencia a aca_actividades ON DELETE CASCADE. Borrar las categorías
--   globales arrastraba en cascada las actividades que las usaban y TODAS
--   las notas cargadas en ellas.
--   Ahora primero se desvinculan las actividades y recién después se borran
--   las categorías, sin perder ni una nota.
-- ================================================================


-- ----------------------------------------------------------------
-- PASO 0 — DIAGNÓSTICO (opcional pero recomendado)
-- Corré esto SOLO (seleccionándolo) antes de ejecutar el resto, para ver
-- cuántas actividades y notas están colgando de las categorías globales.
-- ----------------------------------------------------------------
-- SELECT
--   (SELECT COUNT(*) FROM aca_categorias_nota WHERE materia_id IS NULL)  AS categorias_globales,
--   (SELECT COUNT(*) FROM aca_actividades a
--      JOIN aca_categorias_nota c ON c.id = a.categoria_id
--     WHERE c.materia_id IS NULL)                                        AS actividades_afectadas,
--   (SELECT COUNT(*) FROM aca_calificaciones cal
--      JOIN aca_actividades a ON a.id = cal.actividad_id
--      JOIN aca_categorias_nota c ON c.id = a.categoria_id
--     WHERE c.materia_id IS NULL)                                        AS notas_en_riesgo;


-- ----------------------------------------------------------------
-- PASO 1 — Hacer categoria_id opcional en aca_actividades
-- (los docentes pueden crear notas sin asignar categoría)
-- Tiene que ir primero: el PASO 4 depende de que acepte NULL.
-- ----------------------------------------------------------------
ALTER TABLE aca_actividades
  ALTER COLUMN categoria_id DROP NOT NULL;


-- ----------------------------------------------------------------
-- PASO 2 — Columna tipo_actividad, para no depender del prefijo del título
-- ----------------------------------------------------------------
ALTER TABLE aca_actividades
  ADD COLUMN IF NOT EXISTS tipo_actividad VARCHAR(20) DEFAULT 'NOTA'
    CHECK (tipo_actividad IN ('NOTA', 'TAREA', 'CLASE', 'INFO', 'CONDUCTA'));


-- ----------------------------------------------------------------
-- PASO 3 — Migrar tipos desde el prefijo del título (datos existentes)
-- ----------------------------------------------------------------
UPDATE aca_actividades SET tipo_actividad = 'TAREA'    WHERE titulo ILIKE '[TAREA]%'    AND tipo_actividad = 'NOTA';
UPDATE aca_actividades SET tipo_actividad = 'CLASE'    WHERE titulo ILIKE '[CLASE]%'    AND tipo_actividad = 'NOTA';
UPDATE aca_actividades SET tipo_actividad = 'INFO'     WHERE titulo ILIKE '[INFO]%'     AND tipo_actividad = 'NOTA';
UPDATE aca_actividades SET tipo_actividad = 'CONDUCTA' WHERE titulo ILIKE '[CONDUCTA]%' AND tipo_actividad = 'NOTA';


-- ----------------------------------------------------------------
-- PASO 4 — Desvincular las actividades de las categorías globales
-- ANTES de borrarlas. Esto es lo que evita el borrado en cascada:
-- las actividades y sus notas quedan intactas, solo sin categoría.
-- ----------------------------------------------------------------
UPDATE aca_actividades a
   SET categoria_id = NULL
  FROM aca_categorias_nota c
 WHERE c.id = a.categoria_id
   AND c.materia_id IS NULL;


-- ----------------------------------------------------------------
-- PASO 5 — Ahora sí, borrar las categorías globales del seed
-- (Evidencias / Desempeño / Autoevaluación). En este punto ya no
-- las referencia ninguna actividad, así que el CASCADE no arrastra nada.
-- Las categorías que los docentes crearon para sus materias se conservan.
-- ----------------------------------------------------------------
DELETE FROM aca_categorias_nota WHERE materia_id IS NULL;


-- ----------------------------------------------------------------
-- PASO 6 — VERIFICACIÓN (descomentá y corré después)
-- ----------------------------------------------------------------
-- -- Distribución de tipos de actividad:
-- SELECT tipo_actividad, COUNT(*) FROM aca_actividades GROUP BY tipo_actividad;
--
-- -- Debe dar 0:
-- SELECT COUNT(*) FROM aca_categorias_nota WHERE materia_id IS NULL;
--
-- -- Debe seguir dando el MISMO número que antes de la migración:
-- SELECT COUNT(*) AS total_notas FROM aca_calificaciones;
