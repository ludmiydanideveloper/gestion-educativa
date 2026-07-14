-- Crear tabla de calendario
CREATE TABLE IF NOT EXISTS acad_calendario (
    evento_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo VARCHAR(255) NOT NULL,
    descripcion TEXT NOT NULL,
    fecha DATE NOT NULL,
    tipo_evento VARCHAR(50) NOT NULL CHECK (tipo_evento IN ('EVALUACION', 'ACTIVIDAD', 'REUNION')),
    curso_id UUID REFERENCES acad_cursos(curso_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS
ALTER TABLE acad_calendario ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
DROP POLICY IF EXISTS "Permitir lectura de calendario para todos los autenticados" ON acad_calendario;
CREATE POLICY "Permitir lectura de calendario para todos los autenticados"
ON acad_calendario
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Permitir escritura de calendario para personal" ON acad_calendario;
CREATE POLICY "Permitir escritura de calendario para personal"
ON acad_calendario
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM usr_docentes d
        WHERE d.auth_id = auth.uid()
    )
);

-- Función y trigger para enviar notificaciones automáticas en com_mensajes
CREATE OR REPLACE FUNCTION fn_notify_calendar_event()
RETURNS TRIGGER AS $$
DECLARE
    v_mensaje_id UUID;
    v_emisor_id UUID;
BEGIN
    -- Determinar emisor (quien inserta, o primer docente/admin)
    v_emisor_id := auth.uid();
    IF v_emisor_id IS NULL THEN
        SELECT auth_id INTO v_emisor_id FROM usr_docentes LIMIT 1;
    END IF;

    IF v_emisor_id IS NULL THEN
        -- Fallback si no hay docentes
        SELECT id INTO v_emisor_id FROM auth.users LIMIT 1;
    END IF;

    -- 1. Insertar en com_mensajes
    INSERT INTO com_mensajes (emisor_id, asunto, cuerpo, requiere_firma)
    VALUES (
        v_emisor_id,
        'Calendario: ' || NEW.titulo,
        jsonb_build_object('texto', NEW.descripcion || ' - Programado para el: ' || NEW.fecha::text || ' (' || NEW.tipo_evento || ')'),
        false
    ) RETURNING mensaje_id INTO v_mensaje_id;

    -- 2. Insertar destinatarios
    IF NEW.curso_id IS NOT NULL THEN
        -- Alumnos y tutores de ese curso
        INSERT INTO com_destinatarios (mensaje_id, usuario_id, emisor_id, archivado)
        SELECT DISTINCT v_mensaje_id, la.auth_id, v_emisor_id, false
        FROM usr_legajo_alumno la
        WHERE la.auth_id IS NOT NULL AND (
            la.legajo_id IN (
                SELECT alumno_id FROM acad_inscripciones WHERE curso_id = NEW.curso_id
            ) OR la.grupo_id IN (
                SELECT sub_la.grupo_id 
                FROM usr_legajo_alumno sub_la
                JOIN acad_inscripciones ins ON ins.alumno_id = sub_la.legajo_id
                WHERE ins.curso_id = NEW.curso_id
            )
        );
    ELSE
        -- Toda la escuela (alumnos, tutores y docentes)
        INSERT INTO com_destinatarios (mensaje_id, usuario_id, emisor_id, archivado)
        SELECT DISTINCT v_mensaje_id, auth_id, v_emisor_id, false
        FROM usr_legajo_alumno
        WHERE auth_id IS NOT NULL
        UNION
        SELECT DISTINCT v_mensaje_id, auth_id, v_emisor_id, false
        FROM usr_docentes
        WHERE auth_id IS NOT NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_calendar_event ON acad_calendario;
CREATE TRIGGER trg_notify_calendar_event
AFTER INSERT ON acad_calendario
FOR EACH ROW
EXECUTE FUNCTION fn_notify_calendar_event();

-- Seed de eventos iniciales (si no existen)
INSERT INTO acad_calendario (titulo, descripcion, fecha, tipo_evento, curso_id)
SELECT 'Inicio del Período de Exámenes', 'Exámenes trimestrales del primer cuatrimestre.', '2026-07-06', 'ACTIVIDAD', NULL
WHERE NOT EXISTS (SELECT 1 FROM acad_calendario WHERE titulo = 'Inicio del Período de Exámenes');

INSERT INTO acad_calendario (titulo, descripcion, fecha, tipo_evento, curso_id)
SELECT 'Examen Integrador de Matemáticas', 'Evaluación escrita sobre funciones cuadráticas y sistemas de ecuaciones.', '2026-07-08', 'EVALUACION', '953fc2c3-0737-4ce8-983f-445e67b50f10'
WHERE EXISTS (SELECT 1 FROM acad_cursos WHERE curso_id = '953fc2c3-0737-4ce8-983f-445e67b50f10')
  AND NOT EXISTS (SELECT 1 FROM acad_calendario WHERE titulo = 'Examen Integrador de Matemáticas');

INSERT INTO acad_calendario (titulo, descripcion, fecha, tipo_evento, curso_id)
SELECT 'Reunión de Padres Trimestral', 'Entrega de informes cualitativos de seguimiento y convivencia.', '2026-07-15', 'REUNION', NULL
WHERE NOT EXISTS (SELECT 1 FROM acad_calendario WHERE titulo = 'Reunión de Padres Trimestral');
