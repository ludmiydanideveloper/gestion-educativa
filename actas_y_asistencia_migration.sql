-- Migración para Libro de Actas Digital y Separación de Asistencia
-- Ejecutar en Supabase SQL Editor

-- 1. TABLA DE ACTAS DIGITALES (acad_actas)
CREATE TABLE IF NOT EXISTS acad_actas (
    acta_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo VARCHAR(255) NOT NULL,
    categoria VARCHAR(50) NOT NULL CHECK (categoria IN ('ACADEMICAS', 'ACCIDENTES', 'REUNIONES')),
    curso_id UUID REFERENCES acad_cursos(curso_id) ON DELETE SET NULL,
    contenido TEXT NOT NULL,
    participantes TEXT NOT NULL,
    firmas TEXT[] DEFAULT '{}',
    creado_por UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE acad_actas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir lectura de actas al personal" ON acad_actas;
CREATE POLICY "Permitir lectura de actas al personal"
ON acad_actas FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Permitir escritura de actas a administradores y preceptores" ON acad_actas;
CREATE POLICY "Permitir escritura de actas a administradores y preceptores"
ON acad_actas FOR ALL TO authenticated USING (true);

-- 2. SEPARACIÓN DE ASISTENCIA (Por Materia vs. Preceptor Diaria) en asistencia_cabecera
ALTER TABLE asistencia_cabecera
ADD COLUMN IF NOT EXISTS tipo_asistencia VARCHAR(50) DEFAULT 'PRECEPTOR_DIARIA',
ADD COLUMN IF NOT EXISTS materia_id UUID REFERENCES acad_materias(materia_id) ON DELETE SET NULL;

-- Índices recomendados para consultas rápidas
CREATE INDEX IF NOT EXISTS idx_acad_actas_categoria ON acad_actas(categoria);
CREATE INDEX IF NOT EXISTS idx_acad_actas_curso_id ON acad_actas(curso_id);
CREATE INDEX IF NOT EXISTS idx_asistencia_cabecera_tipo ON asistencia_cabecera(tipo_asistencia, curso_id, materia_id, fecha);
