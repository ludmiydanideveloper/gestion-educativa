-- ==========================================
-- 1. ADAPTACIÓN Y ELIMINACIÓN DE TABLAS VIEJAS
-- ==========================================
DROP TABLE IF EXISTS asistencia_registros CASCADE;

-- ==========================================
-- 2. NUEVA TABLA: Períodos Académicos (academic_periods)
-- ==========================================
CREATE TABLE acad_periodos (
    periodo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sede_id UUID NOT NULL REFERENCES core_sedes(sede_id) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL, -- Ej. 'Primer Trimestre 2026'
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado_cierre VARCHAR(50) NOT NULL CHECK (estado_cierre IN ('ABIERTO', 'CERRADO_PARA_DOCENTES', 'PUBLICADO')),
    CONSTRAINT check_fechas_periodo CHECK (fecha_fin > fecha_inicio)
);

-- Crear índice para acelerar búsquedas de períodos por sede
CREATE INDEX idx_periodos_sede ON acad_periodos(sede_id);

-- ==========================================
-- 3. NUEVA TABLA: Inscripciones de Alumnos (enrollments)
-- ==========================================
CREATE TABLE acad_inscripciones (
    inscripcion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    curso_id UUID NOT NULL REFERENCES acad_cursos(curso_id) ON DELETE CASCADE,
    estado VARCHAR(50) NOT NULL CHECK (estado IN ('ACTIVO', 'SUSPENDIDO', 'TRANSFERIDO', 'BAJA')),
    CONSTRAINT unique_alumno_curso UNIQUE (alumno_id, curso_id)
);

-- Índices B-Tree para acelerar consultas de matrículas
CREATE INDEX idx_inscripciones_alumno ON acad_inscripciones(alumno_id);
CREATE INDEX idx_inscripciones_curso ON acad_inscripciones(curso_id);

-- ==========================================
-- 4. NUEVAS TABLAS: Asistencia (daily_attendances y attendance_records)
-- ==========================================
CREATE TABLE asistencia_cabecera (
    asistencia_cabecera_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    curso_id UUID NOT NULL REFERENCES acad_cursos(curso_id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    estado VARCHAR(50) NOT NULL CHECK (estado IN ('BORRADOR', 'ENVIADO', 'PENDIENTE_APROBACION_AJUSTE', 'APROBADO')),
    registrado_por_docente_id UUID REFERENCES usr_docentes(docente_id) ON DELETE SET NULL,
    CONSTRAINT unique_curso_fecha UNIQUE (curso_id, fecha)
);

CREATE TABLE asistencia_detalle (
    asistencia_detalle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asistencia_cabecera_id UUID NOT NULL REFERENCES asistencia_cabecera(asistencia_cabecera_id) ON DELETE CASCADE,
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    valor_inasistencia NUMERIC(4,2) NOT NULL CHECK (valor_inasistencia BETWEEN 0.00 AND 1.00), -- 1.00 completa, 0.50 media, 0.25 tardanza
    tipo VARCHAR(50) NOT NULL CHECK (tipo IN ('PRESENTE', 'AUSENTE', 'TARDE', 'RETIRO_ANTICIPADO', 'INDEFINIDO')),
    estado_justificacion VARCHAR(50) NOT NULL CHECK (estado_justificacion IN ('NINGUNO', 'PENDIENTE_CERTIFICADO_MEDICO', 'JUSTIFICADO', 'RECHAZADO')),
    url_certificado VARCHAR(512) NULL,
    CONSTRAINT unique_detalle_asistencia UNIQUE (asistencia_cabecera_id, alumno_id)
);

-- Índices obligatorios del documento técnico
CREATE INDEX idx_asistencia_cabecera_curso_fecha ON asistencia_cabecera(curso_id, fecha);
CREATE INDEX idx_asistencia_detalle_alumno ON asistencia_detalle(alumno_id);

-- ==========================================
-- 5. NUEVA TABLA: Calificaciones (grades)
-- ==========================================
CREATE TABLE acad_calificaciones (
    calificacion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    materia_id UUID NOT NULL,
    curso_id UUID NOT NULL, -- Se incluye para control compuesto
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    periodo_id UUID NOT NULL REFERENCES acad_periodos(periodo_id) ON DELETE CASCADE,
    valor_calificacion VARCHAR(10) NOT NULL, -- Tipo mixto ('8.5', 'TEA', 'TEP', 'TED')
    equivalente_numerico NUMERIC(5,2) NULL, -- Equiv. para cálculo de promedio
    ponderacion NUMERIC(4,2) NOT NULL CHECK (ponderacion BETWEEN 0.00 AND 1.00), -- Ponderación (ej: 0.30, 0.70)
    es_nota_cierre BOOLEAN NOT NULL DEFAULT FALSE,
    estado_aprobacion VARCHAR(50) NOT NULL CHECK (estado_aprobacion IN (
        'SIN_CARGAR', 'BORRADOR', 'SUGERENCIA_DIVERGENTE', 'PENDIENTE_APROBACION', 
        'APROBADO_SIN_PUBLICAR', 'RECHAZADO', 'PUBLICADO'
    )),
    
    -- Relación con materias referenciando la clave única compuesta (materia_id, curso_id)
    CONSTRAINT fk_calificaciones_materia_curso FOREIGN KEY (materia_id, curso_id) 
        REFERENCES acad_materias(materia_id, curso_id) ON DELETE CASCADE
);

-- Índice B-Tree Compuesto obligatorio para generación de boletines
CREATE INDEX idx_calificaciones_boletin ON acad_calificaciones(alumno_id, periodo_id, materia_id);

-- ==========================================
-- 6. NUEVA TABLA: Materias Adeudadas/Previas (pending_subjects)
-- ==========================================
CREATE TABLE acad_materias_adeudadas (
    adeudada_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    materia_original_id UUID NOT NULL REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
    anio_origen INTEGER NOT NULL CHECK (anio_origen > 1900), -- Año de la deuda (ej: 2025)
    condicion VARCHAR(50) NOT NULL CHECK (condicion IN ('REGULAR', 'PENDIENTE_ACREDITACION', 'EQUIVALENCIA')),
    CONSTRAINT unique_alumno_materia_adeudada UNIQUE (alumno_id, materia_original_id)
);

-- Índices B-Tree para optimizar consultas de previas
CREATE INDEX idx_adeudadas_alumno ON acad_materias_adeudadas(alumno_id);
