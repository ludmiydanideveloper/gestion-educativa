-- 1. Habilitar extensión para UUID y Btree Gist (Prevención de colisiones)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 2. DOMINIO CORE: Sedes y Ciclos Lectivos
CREATE TABLE core_sedes (
    sede_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre_sede VARCHAR(150) NOT NULL
);

CREATE TABLE core_ciclos_lectivos (
    ciclo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    anio_calendario INTEGER NOT NULL, -- Año calendario (ej. 2026)
    rango_fechas DATERANGE NOT NULL
);

-- 3. DOMINIO INFRAESTRUCTURA: Aulas
CREATE TABLE org_aulas (
    aula_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sede_id UUID NOT NULL REFERENCES core_sedes(sede_id) ON DELETE CASCADE,
    codigo_aula VARCHAR(50) NOT NULL,
    capacidad_maxima INTEGER NOT NULL CHECK (capacidad_maxima > 0)
);

-- 4. DOMINIO ACADÉMICO: Cursos, Grupos Especiales, Materias y Docentes
CREATE TABLE acad_cursos (
    curso_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sede_id UUID NOT NULL REFERENCES core_sedes(sede_id) ON DELETE CASCADE,
    ciclo_id UUID NOT NULL REFERENCES core_ciclos_lectivos(ciclo_id) ON DELETE CASCADE,
    identificador_division VARCHAR(50) NOT NULL,
    CONSTRAINT unique_curso_ciclo UNIQUE (curso_id, ciclo_id)
);

CREATE TABLE acad_grupos_especiales (
    grupo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ciclo_id UUID NOT NULL REFERENCES core_ciclos_lectivos(ciclo_id) ON DELETE CASCADE,
    computa_asistencia BOOLEAN DEFAULT FALSE
);

CREATE TABLE usr_docentes (
    docente_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ddjj_cargos JSONB NULL
);

CREATE TABLE acad_materias (
    materia_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    curso_id UUID NOT NULL REFERENCES acad_cursos(curso_id) ON DELETE CASCADE,
    docente_titular_id UUID REFERENCES usr_docentes(docente_id) ON DELETE SET NULL,
    nombre_asignatura VARCHAR(100) NOT NULL,
    CONSTRAINT unique_materia_curso UNIQUE (materia_id, curso_id)
);

-- 5. DOMINIO CRONOGRAMAS: Bloques Horarios con Exclusiones Complejas (GIST)
CREATE TABLE org_horario_bloques (
    bloque_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    materia_id UUID NOT NULL,
    curso_id UUID NOT NULL,
    aula_id UUID REFERENCES org_aulas(aula_id) ON DELETE SET NULL,
    docente_titular_id UUID REFERENCES usr_docentes(docente_id) ON DELETE SET NULL,
    horario_diario TSRANGE NOT NULL, -- Rango de hora/timestamp diario
    dia_de_semana INTEGER NOT NULL CHECK (dia_de_semana BETWEEN 1 AND 7),
    vigencia_bloque DATERANGE NOT NULL, -- Vigencia del bloque en el año
    
    -- Relación fuerte con materias que garantiza integridad referencial con curso_id
    CONSTRAINT fk_materia_curso FOREIGN KEY (materia_id, curso_id) 
        REFERENCES acad_materias(materia_id, curso_id) ON DELETE CASCADE,
        
    -- EXCLUSIÓN 1: Colisión del Docente (Evitar que un docente tenga 2 clases simultáneas)
    CONSTRAINT prevent_docente_overlap EXCLUDE USING gist (
        docente_titular_id WITH =,
        dia_de_semana WITH =,
        horario_diario WITH &&,
        vigencia_bloque WITH &&
    ),
    
    -- EXCLUSIÓN 2: Colisión Áulica (Evitar que un aula se asigne a 2 clases simultáneas)
    CONSTRAINT prevent_aula_overlap EXCLUDE USING gist (
        aula_id WITH =,
        dia_de_semana WITH =,
        horario_diario WITH &&,
        vigencia_bloque WITH &&
    ),
    
    -- EXCLUSIÓN 3: Colisión de Cursada del Alumnado (Evitar que un curso tenga 2 materias simultáneas)
    CONSTRAINT prevent_curso_overlap EXCLUDE USING gist (
        curso_id WITH =,
        dia_de_semana WITH =,
        horario_diario WITH &&,
        vigencia_bloque WITH &&
    )
);

-- 6. DOMINIO ALUMNOS Y ASISTENCIAS
CREATE TABLE usr_legajo_alumno (
    legajo_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    datos_demograficos JSONB NOT NULL,
    ficha_medica JSONB NULL,
    autorizaciones JSONB NULL
);

CREATE TABLE asistencia_registros (
    registro_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    fecha_operativa DATE NOT NULL,
    estado_general VARCHAR(20) NOT NULL CHECK (estado_general IN ('PRESENTE', 'AUSENTE', 'TARDE', 'RETIRO')),
    hora_llegada TIME NULL,
    hora_retiro TIME NULL,
    
    -- Validación algorítmica para asistencias tardías y retiros en base de datos
    CONSTRAINT check_asistencia_tarde_llegada CHECK (
        (estado_general = 'TARDE' AND hora_llegada IS NOT NULL) OR 
        (estado_general <> 'TARDE')
    ),
    CONSTRAINT check_asistencia_retiro_retiro CHECK (
        (estado_general = 'RETIRO' AND hora_retiro IS NOT NULL) OR 
        (estado_general <> 'RETIRO')
    )
);
