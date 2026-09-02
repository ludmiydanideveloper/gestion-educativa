-- =============================================
-- MIGRACIÓN V2: Categorías por materia + Modo de calificación
-- Ejecutar en Supabase SQL Editor
-- =============================================

-- 1. Hacer categorías opcionales por materia.
--    NULL = categoría global/compartida; UUID = propia de esa materia.
ALTER TABLE aca_categorias_nota
  ADD COLUMN IF NOT EXISTS materia_id UUID
    REFERENCES acad_materias(materia_id) ON DELETE CASCADE;

-- 2. Peso individual por actividad (Modo A: porcentaje por nota).
ALTER TABLE aca_actividades
  ADD COLUMN IF NOT EXISTS peso_porcentaje_actividad NUMERIC(5,2);

-- 3. Tabla de configuración de modo de calificación por materia.
--    modo_calificacion: 'GRUPOS' (promedio por grupo/categoría)
--                     | 'PORCENTAJE' (cada actividad tiene su propio %)
CREATE TABLE IF NOT EXISTS aca_config_materia (
    materia_id         UUID PRIMARY KEY REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
    modo_calificacion  VARCHAR(30) NOT NULL DEFAULT 'GRUPOS',
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ DEFAULT NOW()
);

-- RLS para la nueva tabla
ALTER TABLE aca_config_materia ENABLE ROW LEVEL SECURITY;

CREATE POLICY "docentes_config_materia_all" ON aca_config_materia
  FOR ALL TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'rol')
    IN ('ADMIN', 'DIRECTIVO', 'PRECEPTOR', 'DOCENTE')
  );
