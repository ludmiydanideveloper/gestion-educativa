-- ========================================================
-- MÓDULO DE HORARIOS Y ASIGNACIÓN CONTEXTUAL DE DOCENTES
-- ========================================================

-- 1. Tabla acad_horarios
CREATE TABLE IF NOT EXISTS acad_horarios (
    horario_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    materia_id UUID REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
    curso_id UUID REFERENCES acad_cursos(curso_id) ON DELETE CASCADE,
    dia_semana VARCHAR(50) NOT NULL CHECK (dia_semana IN ('LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO')),
    hora_inicio VARCHAR(50) NOT NULL,
    hora_fin VARCHAR(50) NOT NULL
);

-- 2. Tabla relacional intermedia: acad_docente_materia_curso
CREATE TABLE IF NOT EXISTS acad_docente_materia_curso (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    docente_id UUID REFERENCES usr_docentes(docente_id) ON DELETE CASCADE,
    materia_id UUID REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
    curso_id UUID REFERENCES acad_cursos(curso_id) ON DELETE CASCADE,
    CONSTRAINT unique_docente_materia_curso UNIQUE (docente_id, materia_id, curso_id)
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE acad_horarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE acad_docente_materia_curso ENABLE ROW LEVEL SECURITY;

-- Limpieza previa si existiesen políticas
DROP POLICY IF EXISTS select_horarios ON acad_horarios;
DROP POLICY IF EXISTS write_horarios ON acad_horarios;
DROP POLICY IF EXISTS select_docente_materia_curso ON acad_docente_materia_curso;
DROP POLICY IF EXISTS write_docente_materia_curso ON acad_docente_materia_curso;

-- Políticas para acad_horarios
CREATE POLICY select_horarios ON acad_horarios 
    FOR SELECT TO authenticated USING (true);

CREATE POLICY write_horarios ON acad_horarios 
    FOR ALL TO authenticated 
    USING (EXISTS (SELECT 1 FROM usr_docentes WHERE auth_id = auth.uid() AND (ddjj_cargos::text ILIKE '%ADMIN%' OR ddjj_cargos::text ILIKE '%PRECEPTOR%')));

-- Políticas para acad_docente_materia_curso
CREATE POLICY select_docente_materia_curso ON acad_docente_materia_curso 
    FOR SELECT TO authenticated USING (true);

CREATE POLICY write_docente_materia_curso ON acad_docente_materia_curso 
    FOR ALL TO authenticated 
    USING (EXISTS (SELECT 1 FROM usr_docentes WHERE auth_id = auth.uid() AND (ddjj_cargos::text ILIKE '%ADMIN%' OR ddjj_cargos::text ILIKE '%PRECEPTOR%')));
