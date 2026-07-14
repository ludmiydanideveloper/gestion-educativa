-- ========================================================
-- MÓDULO DE COMUNICACIÓN INSTITUCIONAL (CUADERNO DIGITAL)
-- ========================================================

-- Limpieza previa de tablas para evitar inconsistencias de esquema
DROP TABLE IF EXISTS com_destinatarios CASCADE;
DROP TABLE IF EXISTS com_mensajes CASCADE;

-- 1. Tabla com_mensajes (Mensaje Cabecera)
CREATE TABLE com_mensajes (
    mensaje_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    emisor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    asunto VARCHAR(255) NOT NULL,
    cuerpo JSONB NOT NULL, -- Texto enriquecido, enlaces, metadatos, etc.
    requiere_firma BOOLEAN DEFAULT FALSE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Tabla com_destinatarios (Detalle de Distribución / Inbox)
-- Denormalizamos emisor_id para romper recursión infinita en políticas RLS y optimizar consultas.
CREATE TABLE com_destinatarios (
    destinatario_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mensaje_id UUID NOT NULL REFERENCES com_mensajes(mensaje_id) ON DELETE CASCADE,
    emisor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, -- Denormalizado
    usuario_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fecha_lectura TIMESTAMPTZ NULL, -- NULL indica "No Leído"
    archivado BOOLEAN DEFAULT FALSE, -- Oculta visualmente pero mantiene historial
    CONSTRAINT unique_destinatario_mensaje UNIQUE (mensaje_id, usuario_id)
);

-- 3. Índices de Alto Rendimiento
CREATE INDEX IF NOT EXISTS idx_com_mensajes_emisor ON com_mensajes(emisor_id);
CREATE INDEX IF NOT EXISTS idx_com_destinatarios_usuario_archivado ON com_destinatarios(usuario_id, archivado);
CREATE INDEX IF NOT EXISTS idx_com_destinatarios_emisor ON com_destinatarios(emisor_id);
CREATE INDEX IF NOT EXISTS idx_com_destinatarios_mensaje_lectura ON com_destinatarios(mensaje_id, fecha_lectura);

-- ========================================================
-- 4. CONFIGURACIÓN DE SEGURIDAD (ROW LEVEL SECURITY - RLS)
-- ========================================================
ALTER TABLE com_mensajes ENABLE ROW LEVEL SECURITY;
ALTER TABLE com_destinatarios ENABLE ROW LEVEL SECURITY;

-- Políticas para com_mensajes:
-- A. Emisores: Pueden hacer ALL (SELECT, INSERT, UPDATE, DELETE) en sus propios mensajes
CREATE POLICY emisor_com_mensajes_all ON com_mensajes
FOR ALL
TO authenticated
USING (emisor_id = auth.uid())
WITH CHECK (emisor_id = auth.uid());

-- B. Destinatarios: Pueden hacer SELECT de un mensaje únicamente si figuran como destinatarios de este
CREATE POLICY destinatario_com_mensajes_select ON com_mensajes
FOR SELECT
TO authenticated
USING (
    mensaje_id IN (
        SELECT d.mensaje_id 
        FROM com_destinatarios d 
        WHERE d.usuario_id = auth.uid()
    )
);

-- Políticas para com_destinatarios (Sin subconsultas recursivas a com_mensajes):
-- A. Lectura (SELECT): Un usuario puede ver el recibo si es el destinatario (inbox) o el emisor (comunicación saliente / acuse)
CREATE POLICY destinatario_com_destinatarios_select ON com_destinatarios
FOR SELECT
TO authenticated
USING (
    usuario_id = auth.uid()
    OR emisor_id = auth.uid()
);

-- B. Actualización (UPDATE): Solo el destinatario puede modificar su registro de acuse (marcar leído/archivar)
CREATE POLICY destinatario_com_destinatarios_update ON com_destinatarios
FOR UPDATE
TO authenticated
USING (usuario_id = auth.uid())
WITH CHECK (usuario_id = auth.uid());

-- C. Creación (INSERT): Un emisor puede crear recibos de distribución siempre que figure como el emisor de los mismos (emisor_id = auth.uid())
CREATE POLICY emisor_com_destinatarios_insert ON com_destinatarios
FOR INSERT
TO authenticated
WITH CHECK (
    emisor_id = auth.uid()
);
