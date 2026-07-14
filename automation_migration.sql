-- ========================================================
-- 1. CREACIÓN DE LA TABLA DE ALERTAS INSTITUCIONALES
-- ========================================================
CREATE TABLE IF NOT EXISTS acad_alertas (
    alerta_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    tipo_alerta VARCHAR(100) NOT NULL, -- Ej: 'LIMITE_ASISTENCIA'
    gravedad VARCHAR(20) NOT NULL CHECK (gravedad IN ('MEDIA', 'ALTA', 'CRITICA')),
    mensaje TEXT NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'NOTIFICADA', 'RESUELTA')),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE acad_alertas ENABLE ROW LEVEL SECURITY;

-- Limpieza de políticas previas si existiesen
DROP POLICY IF EXISTS directivos_manage_alertas ON acad_alertas;

-- Política de RLS para que directivos y administradores tengan acceso total
CREATE POLICY directivos_manage_alertas ON acad_alertas
FOR ALL
TO authenticated
USING (
    (auth.jwt() -> 'user_metadata' ->> 'rol') IN ('DIRECTIVO', 'ADMINISTRADOR')
);

-- ========================================================
-- 2. FUNCIÓN DE MONITOREO DE INASISTENCIAS EN TIEMPO REAL
-- ========================================================
CREATE OR REPLACE FUNCTION fn_monitorear_limite_faltas()
RETURNS TRIGGER AS $$
DECLARE
    total_faltas NUMERIC(6,2);
    alerta_existente BOOLEAN;
BEGIN
    -- A. Calcular la sumatoria en tiempo real de las faltas de la tabla asistencia_detalle
    SELECT COALESCE(SUM(valor_inasistencia), 0.00) INTO total_faltas
    FROM asistencia_detalle
    WHERE alumno_id = NEW.alumno_id;

    -- B. Si el total acumulado iguala o supera el límite reglamentario de 20 faltas
    IF total_faltas >= 20.00 THEN
        -- C. Verificar si ya existe una alerta activa (PENDIENTE o NOTIFICADA) para este alumno
        SELECT EXISTS (
            SELECT 1 
            FROM acad_alertas 
            WHERE alumno_id = NEW.alumno_id 
              AND tipo_alerta = 'LIMITE_ASISTENCIA' 
              AND estado IN ('PENDIENTE', 'NOTIFICADA')
        ) INTO alerta_existente;

        -- D. Si no hay alerta activa previa, se genera una nueva de gravedad CRÍTICA
        IF NOT alerta_existente THEN
            INSERT INTO acad_alertas (alumno_id, tipo_alerta, gravedad, mensaje, estado)
            VALUES (
                NEW.alumno_id,
                'LIMITE_ASISTENCIA',
                'CRITICA',
                'El alumno ha alcanzado o superado el límite de 20 inasistencias reglamentarias. Total acumulado: ' || total_faltas || ' faltas.',
                'PENDIENTE'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ========================================================
-- 3. CREACIÓN DEL DISPARADOR (TRIGGER)
-- ========================================================
DROP TRIGGER IF EXISTS trg_limite_faltas ON asistencia_detalle;

CREATE TRIGGER trg_limite_faltas
AFTER INSERT OR UPDATE ON asistencia_detalle
FOR EACH ROW
EXECUTE FUNCTION fn_monitorear_limite_faltas();
