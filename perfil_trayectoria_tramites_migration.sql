-- =========================================================================
-- MIGRACIÓN PARA: MI PERFIL (DDJJ / CV), TRAYECTORIA ALUMNO, MATERIAS ADEUDADAS RITE Y TRÁMITES (PADRES)
-- =========================================================================

-- 1. TABLA PARA ARCHIVOS DEL PERSONAL (DDJJ y CV)
CREATE TABLE IF NOT EXISTS public.usr_archivos_personal (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    docente_id UUID REFERENCES public.usr_docentes(docente_id) ON DELETE CASCADE,
    tipo_archivo VARCHAR(50) NOT NULL, -- 'DDJJ' o 'CV'
    nombre_archivo VARCHAR(255) NOT NULL,
    formato VARCHAR(20) DEFAULT 'PDF', -- 'PDF' o 'WORD'
    datos_base64 TEXT,
    fecha_subida TIMESTAMP WITH TIME ZONE DEFAULT now(),
    observaciones TEXT
);

-- Habilitar RLS e insertar políticas públicas para simplificar acceso autenticado
ALTER TABLE public.usr_archivos_personal ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS archivos_personal_all ON public.usr_archivos_personal;
CREATE POLICY archivos_personal_all ON public.usr_archivos_personal FOR ALL TO authenticated USING (true) WITH CHECK (true);
GRANT ALL ON public.usr_archivos_personal TO anon, authenticated, service_role;

-- 2. TABLA DE TRAYECTORIA ACADÉMICA DEL ALUMNO (HISTÓRICO Y ACTUAL)
CREATE TABLE IF NOT EXISTS public.acad_trayectoria_alumno (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legajo_id UUID REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    curso_nombre VARCHAR(100) NOT NULL,
    anio_lectivo INTEGER NOT NULL,
    condicion VARCHAR(50) DEFAULT 'APROBADO', -- 'APROBADO', 'EN_CURSO', 'RITE'
    promedio DECIMAL(4,2) DEFAULT 0.0,
    observaciones TEXT,
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE public.acad_trayectoria_alumno ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS trayectoria_alumno_all ON public.acad_trayectoria_alumno;
CREATE POLICY trayectoria_alumno_all ON public.acad_trayectoria_alumno FOR ALL TO authenticated USING (true) WITH CHECK (true);
GRANT ALL ON public.acad_trayectoria_alumno TO anon, authenticated, service_role;

-- 3. TABLA DE MATERIAS ADEUDADAS / PREVIAS / RITE
CREATE TABLE IF NOT EXISTS public.acad_materias_adeudadas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legajo_id UUID REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    nombre_materia VARCHAR(150) NOT NULL,
    anio_origen INTEGER NOT NULL,
    condicion VARCHAR(50) DEFAULT 'ADEUDADA_RITE', -- 'ADEUDADA_RITE', 'PREVIA_LIBRE', 'EQUIVALENCIA'
    calificacion_final DECIMAL(4,2),
    estado VARCHAR(50) DEFAULT 'PENDIENTE', -- 'PENDIENTE', 'EN_PROCESO_RITE', 'APROBADA'
    fecha_examen TIMESTAMP WITH TIME ZONE,
    observaciones TEXT
);

ALTER TABLE public.acad_materias_adeudadas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS materias_adeudadas_all ON public.acad_materias_adeudadas;
CREATE POLICY materias_adeudadas_all ON public.acad_materias_adeudadas FOR ALL TO authenticated USING (true) WITH CHECK (true);
GRANT ALL ON public.acad_materias_adeudadas TO anon, authenticated, service_role;

-- 4. TABLA DE TRÁMITES Y SOLICITUDES DE CONSTANCIAS (PADRE / ALUMNO <-> ADMIN/PRECEPTOR)
CREATE TABLE IF NOT EXISTS public.tramites_solicitudes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legajo_id UUID REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    padre_auth_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    tipo_tramite VARCHAR(100) DEFAULT 'CONSTANCIA_ALUMNO_REGULAR',
    estado VARCHAR(50) DEFAULT 'PENDIENTE', -- 'PENDIENTE', 'EMITIDO', 'RECHAZADO'
    fecha_solicitud TIMESTAMP WITH TIME ZONE DEFAULT now(),
    fecha_resolucion TIMESTAMP WITH TIME ZONE,
    codigo_verificacion VARCHAR(50),
    observaciones TEXT
);

ALTER TABLE public.tramites_solicitudes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tramites_solicitudes_all ON public.tramites_solicitudes;
CREATE POLICY tramites_solicitudes_all ON public.tramites_solicitudes FOR ALL TO authenticated USING (true) WITH CHECK (true);
GRANT ALL ON public.tramites_solicitudes TO anon, authenticated, service_role;
