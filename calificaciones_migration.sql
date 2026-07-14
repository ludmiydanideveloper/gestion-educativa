-- ========================================================
-- MÓDULO DE CALIFICACIONES Y RITE (CONTRATO PEDAGÓGICO)
-- ========================================================

-- Limpieza previa si existiesen
DROP TABLE IF EXISTS aca_calificaciones CASCADE;
DROP TABLE IF EXISTS aca_actividades CASCADE;
DROP TABLE IF EXISTS aca_categorias_nota CASCADE;

-- 1. Tabla: aca_categorias_nota
CREATE TABLE aca_categorias_nota (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(255) NOT NULL,
    peso_porcentaje NUMERIC(5,2) NOT NULL CHECK (peso_porcentaje >= 0 AND peso_porcentaje <= 100)
);

-- 2. Tabla: aca_actividades
CREATE TABLE aca_actividades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    docente_id UUID NOT NULL REFERENCES usr_docentes(docente_id) ON DELETE CASCADE,
    materia_id UUID NOT NULL REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
    categoria_id UUID NOT NULL REFERENCES aca_categorias_nota(id) ON DELETE CASCADE,
    titulo VARCHAR(255) NOT NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE
);

-- 3. Tabla: aca_calificaciones
CREATE TABLE aca_calificaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actividad_id UUID NOT NULL REFERENCES aca_actividades(id) ON DELETE CASCADE,
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    nota_numerica NUMERIC(5,2) NULL CHECK (nota_numerica BETWEEN 1.0 AND 10.0),
    rubrica_data JSONB NULL,
    CONSTRAINT unique_actividad_alumno UNIQUE (actividad_id, alumno_id)
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE aca_categorias_nota ENABLE ROW LEVEL SECURITY;
ALTER TABLE aca_actividades ENABLE ROW LEVEL SECURITY;
ALTER TABLE aca_calificaciones ENABLE ROW LEVEL SECURITY;

-- Políticas para aca_categorias_nota
CREATE POLICY select_all_categorias ON aca_categorias_nota
    FOR SELECT TO authenticated USING (true);

CREATE POLICY write_categorias ON aca_categorias_nota
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM usr_docentes WHERE auth_id = auth.uid() AND (ddjj_cargos::text ILIKE '%ADMIN%' OR ddjj_cargos::text ILIKE '%PRECEPTOR%')));

-- Políticas para aca_actividades
CREATE POLICY read_actividades ON aca_actividades
    FOR SELECT TO authenticated
    USING (
        docente_id = (SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1)
        OR EXISTS (SELECT 1 FROM usr_docentes WHERE auth_id = auth.uid() AND (ddjj_cargos::text ILIKE '%ADMIN%' OR ddjj_cargos::text ILIKE '%PRECEPTOR%'))
    );

CREATE POLICY write_actividades ON aca_actividades
    FOR ALL TO authenticated
    USING (docente_id = (SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1))
    WITH CHECK (docente_id = (SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1));

-- Políticas para aca_calificaciones
CREATE POLICY read_calificaciones ON aca_calificaciones
    FOR SELECT TO authenticated
    USING (
        actividad_id IN (SELECT id FROM aca_actividades WHERE docente_id = (SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1))
        OR EXISTS (SELECT 1 FROM usr_docentes WHERE auth_id = auth.uid() AND (ddjj_cargos::text ILIKE '%ADMIN%' OR ddjj_cargos::text ILIKE '%PRECEPTOR%'))
    );

CREATE POLICY write_calificaciones ON aca_calificaciones
    FOR ALL TO authenticated
    USING (actividad_id IN (SELECT id FROM aca_actividades WHERE docente_id = (SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1)))
    WITH CHECK (actividad_id IN (SELECT id FROM aca_actividades WHERE docente_id = (SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1)));

-- Seed de Datos
INSERT INTO aca_categorias_nota (nombre, peso_porcentaje) VALUES
('Evidencias', 60.00),
('Desempeño', 30.00),
('Autoevaluación', 10.00);
