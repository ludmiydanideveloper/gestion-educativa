CREATE TABLE IF NOT EXISTS aca_rubricas_cualitativas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    materia_id UUID NOT NULL REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
    etapa VARCHAR(50) NOT NULL,
    criterio_apropiacion VARCHAR(10),
    criterio_resolucion VARCHAR(10),
    criterio_participacion VARCHAR(10),
    criterio_planteos VARCHAR(10),
    criterio_entrega VARCHAR(10),
    criterio_prolijidad VARCHAR(10),
    criterio_aic VARCHAR(10),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(alumno_id, materia_id, etapa)
);

CREATE TABLE IF NOT EXISTS aca_cierres_etapa (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    materia_id UUID NOT NULL REFERENCES acad_materias(materia_id) ON DELETE CASCADE,
    etapa VARCHAR(50) NOT NULL,
    calificacion_numerica NUMERIC(4,2),
    condicion_trayectoria VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(alumno_id, materia_id, etapa)
);

-- Habilitar RLS si es necesario (asumiendo que las demás tablas lo tienen deshabilitado por ahora o tienen políticas estándar)
