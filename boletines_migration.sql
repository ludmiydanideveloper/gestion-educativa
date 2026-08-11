-- ========================================================
-- MÓDULO DE BOLETINES (INFORME DE TRAYECTORIA)
-- ========================================================

-- Modificar tabla existente de calificaciones para soportar cierres de etapa
ALTER TABLE aca_calificaciones ADD COLUMN IF NOT EXISTS etapa_periodo INTEGER DEFAULT 1 CHECK (etapa_periodo IN (1, 2));
ALTER TABLE aca_calificaciones ADD COLUMN IF NOT EXISTS incluir_en_promedio BOOLEAN DEFAULT true;

-- 1. Tabla: aca_boletines (Cabecera)
CREATE TABLE aca_boletines (
    boletin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    curso_id UUID NOT NULL REFERENCES acad_cursos(curso_id) ON DELETE CASCADE,
    anio_lectivo INTEGER NOT NULL,
    total_inasistencias_diarias NUMERIC(5,1) DEFAULT 0,
    observaciones_preceptoria TEXT,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_alumno_curso_anio UNIQUE (alumno_id, curso_id, anio_lectivo)
);

-- 2. Tabla: aca_boletin_detalle (Criterios y notas por materia)
CREATE TABLE aca_boletin_detalle (
    detalle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boletin_id UUID NOT NULL REFERENCES aca_boletines(boletin_id) ON DELETE CASCADE,
    materia_id UUID NOT NULL REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
    
    -- Criterios Cualitativos
    apropiacion_contenidos VARCHAR(5),
    resolucion_actividades VARCHAR(5),
    participacion_clases VARCHAR(5),
    planteos_dudas VARCHAR(5),
    entrega_actividades VARCHAR(5),
    prolijidad_carpeta VARCHAR(5),
    cumplimiento_aic VARCHAR(5),
    
    -- Inasistencias de la materia
    total_inasistencias INTEGER DEFAULT 0,
    
    -- Promedios numéricos y conceptuales
    promedio_1_etapa NUMERIC(5,2),
    resumen_1_etapa VARCHAR(5), -- Auto-calculado (TEA, TEP, TED)
    
    promedio_2_etapa NUMERIC(5,2),
    resumen_2_etapa VARCHAR(5), -- Auto-calculado
    
    intensificacion_dic VARCHAR(5),
    intensificacion_feb VARCHAR(5),
    calificacion_final NUMERIC(5,2),
    
    CONSTRAINT unique_boletin_materia UNIQUE (boletin_id, materia_id)
);

-- Habilitar RLS
ALTER TABLE aca_boletines ENABLE ROW LEVEL SECURITY;
ALTER TABLE aca_boletin_detalle ENABLE ROW LEVEL SECURITY;

-- Políticas para aca_boletines
CREATE POLICY read_boletines ON aca_boletines
    FOR SELECT TO authenticated USING (true);

CREATE POLICY write_boletines ON aca_boletines
    FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM usr_docentes WHERE auth_id = auth.uid() AND (ddjj_cargos::text ILIKE '%ADMIN%' OR ddjj_cargos::text ILIKE '%PRECEPTOR%')));

-- Políticas para aca_boletin_detalle
CREATE POLICY read_boletin_detalle ON aca_boletin_detalle
    FOR SELECT TO authenticated USING (true);

-- Para simplificar la demo, permitimos escritura a autenticados (Idealmente, validar que el docente dicte la materia o sea admin/preceptor)
CREATE POLICY write_boletin_detalle ON aca_boletin_detalle
    FOR ALL TO authenticated USING (true);

