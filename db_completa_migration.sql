-- =========================================================================
-- MIGRACIÓN INTEGRAL — deja operativas las secciones que la app usaba
-- contra tablas o columnas inexistentes.
--
-- IMPORTANTE: correr el archivo COMPLETO, de la primera línea a la última.
-- Va todo dentro de una transacción: si algo falla no se aplica nada.
-- Es idempotente, se puede volver a correr sin problema.
--
-- Forma recomendada (no depende de copiar y pegar bien):
--     $env:SUPABASE_DB_PASSWORD = "<password de postgres>"
--     node run_db_completa_migration.js
--
-- Cubre:
--   A. Columnas nuevas en tablas existentes
--   B. Tablas nuevas
--   C. Verificación
--   D. Relaciones entre las tablas nuevas
--   E. Triggers
--   F. Índices
--   G. RLS y permisos
--   H. Funciones (perfil propio y listado de personal)
-- =========================================================================

BEGIN;

-- =========================================================================
-- A. COLUMNAS NUEVAS EN TABLAS QUE YA EXISTEN
-- =========================================================================

-- A.1 Perfil profesional del docente.
--     usr_docentes sólo tenía docente_id, auth_id y ddjj_cargos, por eso
--     "Mi Perfil > Datos Personales" no podía leer ni guardar nada.
ALTER TABLE public.usr_docentes ADD COLUMN IF NOT EXISTS nombre              VARCHAR(120);
ALTER TABLE public.usr_docentes ADD COLUMN IF NOT EXISTS apellido            VARCHAR(120);
ALTER TABLE public.usr_docentes ADD COLUMN IF NOT EXISTS dni                 VARCHAR(20);
ALTER TABLE public.usr_docentes ADD COLUMN IF NOT EXISTS telefono            VARCHAR(50);
ALTER TABLE public.usr_docentes ADD COLUMN IF NOT EXISTS domicilio           VARCHAR(255);
ALTER TABLE public.usr_docentes ADD COLUMN IF NOT EXISTS titulo_profesional  VARCHAR(255);
ALTER TABLE public.usr_docentes ADD COLUMN IF NOT EXISTS especialidad        VARCHAR(255);
ALTER TABLE public.usr_docentes ADD COLUMN IF NOT EXISTS fecha_ingreso       DATE;

-- A.2 Libro de Temas: el CHECK original rechazaba tipo_evento = 'TEMARIO',
--     así que ninguna clase del Libro de Temas llegaba a guardarse.
ALTER TABLE public.acad_calendario
    DROP CONSTRAINT IF EXISTS acad_calendario_tipo_evento_check;
ALTER TABLE public.acad_calendario
    ADD CONSTRAINT acad_calendario_tipo_evento_check
    CHECK (tipo_evento IN ('EVALUACION', 'ACTIVIDAD', 'REUNION', 'TEMARIO'));

ALTER TABLE public.acad_calendario
    ADD COLUMN IF NOT EXISTS materia_id UUID
    REFERENCES public.acad_materias(materia_id) ON DELETE SET NULL;

-- A.3 Materias adeudadas / RITE: la tabla existía sin las columnas que usa la app.
ALTER TABLE public.acad_materias_adeudadas ADD COLUMN IF NOT EXISTS legajo_id           UUID REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE;
ALTER TABLE public.acad_materias_adeudadas ADD COLUMN IF NOT EXISTS nombre_materia      VARCHAR(150);
ALTER TABLE public.acad_materias_adeudadas ADD COLUMN IF NOT EXISTS estado              VARCHAR(50) DEFAULT 'PENDIENTE';
ALTER TABLE public.acad_materias_adeudadas ADD COLUMN IF NOT EXISTS calificacion_final  DECIMAL(4,2);
ALTER TABLE public.acad_materias_adeudadas ADD COLUMN IF NOT EXISTS fecha_examen        TIMESTAMPTZ;
ALTER TABLE public.acad_materias_adeudadas ADD COLUMN IF NOT EXISTS observaciones       TEXT;

-- materia_original_id era NOT NULL, pero la carga manual sólo pide el nombre
ALTER TABLE public.acad_materias_adeudadas ALTER COLUMN materia_original_id DROP NOT NULL;

-- La condición se carga con distinto vocabulario según la pantalla
ALTER TABLE public.acad_materias_adeudadas
    DROP CONSTRAINT IF EXISTS acad_materias_adeudadas_condicion_check;
ALTER TABLE public.acad_materias_adeudadas
    ADD CONSTRAINT acad_materias_adeudadas_condicion_check
    CHECK (condicion IN ('REGULAR', 'PENDIENTE_ACREDITACION', 'EQUIVALENCIA',
                         'ADEUDADA_RITE', 'PREVIA_LIBRE'));

-- =========================================================================
-- B. TABLAS NUEVAS
--    Ninguna referencia a otra tabla creada en este mismo archivo: esas
--    relaciones se agregan en la parte D, ya con todo creado.
-- =========================================================================

-- B.1 Archivos del legajo personal (DDJJ / CV / CERTIFICADO)
CREATE TABLE IF NOT EXISTS public.usr_archivos_personal (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id        UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    docente_id     UUID REFERENCES public.usr_docentes(docente_id) ON DELETE CASCADE,
    tipo_archivo   VARCHAR(50) NOT NULL,          -- 'DDJJ' | 'CV' | 'CERTIFICADO'
    nombre_archivo VARCHAR(255) NOT NULL,
    formato        VARCHAR(20) DEFAULT 'PDF',     -- 'PDF' | 'WORD'
    datos_base64   TEXT,
    fecha_subida   TIMESTAMPTZ DEFAULT now(),
    observaciones  TEXT
);

-- B.2 Faltas y licencias del docente.
--     Los contadores del perfil estaban escritos a mano en el código porque
--     no existía dónde guardarlos.
CREATE TABLE IF NOT EXISTS public.usr_docente_inasistencias (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    docente_id    UUID REFERENCES public.usr_docentes(docente_id) ON DELETE CASCADE,
    auth_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    tipo          VARCHAR(30) NOT NULL DEFAULT 'INJUSTIFICADA',
    fecha_desde   DATE NOT NULL,
    fecha_hasta   DATE NOT NULL,
    motivo        VARCHAR(255),
    observaciones TEXT,
    archivo_id    UUID,   -- certificado respaldatorio (FK en la parte D)
    creado_en     TIMESTAMPTZ DEFAULT now()
);

-- B.3 Observaciones áulicas / devoluciones del equipo directivo
CREATE TABLE IF NOT EXISTS public.usr_observaciones_aulicas (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    docente_auth_id   UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    docente_id        UUID REFERENCES public.usr_docentes(docente_id) ON DELETE CASCADE,
    curso_id          UUID REFERENCES public.acad_cursos(curso_id) ON DELETE SET NULL,
    materia_id        UUID REFERENCES public.acad_materias(materia_id) ON DELETE SET NULL,
    curso_texto       VARCHAR(150),   -- ej. "3° B - Matemática"
    fecha_visita      DATE NOT NULL DEFAULT CURRENT_DATE,
    modulo            VARCHAR(50),
    foco              VARCHAR(255),
    observacion       TEXT,
    acuerdos          TEXT,
    archivo_id        UUID,   -- acta adjunta (FK en la parte D)
    subido_por        VARCHAR(150),
    subido_por_auth   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    leido             BOOLEAN DEFAULT false,
    fecha_lectura     TIMESTAMPTZ,
    creado_en         TIMESTAMPTZ DEFAULT now()
);

-- B.4 Trayectoria académica del alumno
CREATE TABLE IF NOT EXISTS public.acad_trayectoria_alumno (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id      UUID REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    legajo_id      UUID REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    curso_nombre   VARCHAR(100) NOT NULL,
    anio_lectivo   INTEGER NOT NULL,
    condicion      VARCHAR(50) DEFAULT 'APROBADO',
    promedio       DECIMAL(4,2) DEFAULT 0.0,
    observaciones  TEXT,
    fecha_registro TIMESTAMPTZ DEFAULT now()
);

-- B.5 Libro de actas institucional
CREATE TABLE IF NOT EXISTS public.acad_actas (
    acta_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo        VARCHAR(255) NOT NULL,
    categoria     VARCHAR(80) NOT NULL,
    curso_id      UUID REFERENCES public.acad_cursos(curso_id) ON DELETE SET NULL,
    contenido     TEXT NOT NULL,
    participantes TEXT,
    firmas        JSONB DEFAULT '[]'::jsonb,
    creado_por    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at    TIMESTAMPTZ DEFAULT now()
);

-- B.6 Trámites y constancias
CREATE TABLE IF NOT EXISTS public.tramites_solicitudes (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legajo_id            UUID REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    alumno_id            UUID REFERENCES public.usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    alumno_nombre        VARCHAR(200),
    dni                  VARCHAR(20),
    curso_nombre         VARCHAR(100),
    padre_auth_id        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    tutor_email          VARCHAR(200),
    tipo_tramite         VARCHAR(120) DEFAULT 'CONSTANCIA_ALUMNO_REGULAR',
    estado               VARCHAR(50) DEFAULT 'PENDIENTE',
    fecha_solicitud      TIMESTAMPTZ DEFAULT now(),
    fecha_resolucion     TIMESTAMPTZ,
    codigo_verificacion  VARCHAR(50),
    observaciones        TEXT
);

-- B.7 Notificaciones de administración
CREATE TABLE IF NOT EXISTS public.adm_notificaciones (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo     VARCHAR(255) NOT NULL,
    mensaje    TEXT,
    tipo       VARCHAR(60) DEFAULT 'GENERAL',
    leido      BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- =========================================================================
-- C. VERIFICACIÓN
--    Si el archivo se ejecutó por partes, acá corta con un mensaje claro en
--    vez de tirar un "la relación no existe" varias secciones más abajo.
-- =========================================================================
DO $verificacion$
DECLARE
    faltantes TEXT;
BEGIN
    SELECT string_agg(t, ', ')
      INTO faltantes
      FROM unnest(ARRAY[
        'usr_archivos_personal',
        'usr_docente_inasistencias',
        'usr_observaciones_aulicas',
        'acad_trayectoria_alumno',
        'acad_actas',
        'tramites_solicitudes',
        'adm_notificaciones'
      ]) AS t
     WHERE to_regclass('public.' || t) IS NULL;

    IF faltantes IS NOT NULL THEN
        RAISE EXCEPTION
            'Faltan tablas (%). Ejecutá el archivo db_completa_migration.sql COMPLETO, desde la primera línea.',
            faltantes;
    END IF;
END
$verificacion$;

-- =========================================================================
-- D. RELACIONES ENTRE LAS TABLAS NUEVAS
-- =========================================================================
ALTER TABLE public.usr_docente_inasistencias
    DROP CONSTRAINT IF EXISTS usr_docente_inasistencias_archivo_fk;
ALTER TABLE public.usr_docente_inasistencias
    ADD CONSTRAINT usr_docente_inasistencias_archivo_fk
    FOREIGN KEY (archivo_id) REFERENCES public.usr_archivos_personal(id) ON DELETE SET NULL;

ALTER TABLE public.usr_observaciones_aulicas
    DROP CONSTRAINT IF EXISTS usr_observaciones_aulicas_archivo_fk;
ALTER TABLE public.usr_observaciones_aulicas
    ADD CONSTRAINT usr_observaciones_aulicas_archivo_fk
    FOREIGN KEY (archivo_id) REFERENCES public.usr_archivos_personal(id) ON DELETE SET NULL;

-- Validaciones de las faltas
ALTER TABLE public.usr_docente_inasistencias
    DROP CONSTRAINT IF EXISTS usr_docente_inasistencias_tipo_check;
ALTER TABLE public.usr_docente_inasistencias
    ADD CONSTRAINT usr_docente_inasistencias_tipo_check
    CHECK (tipo IN ('INJUSTIFICADA', 'JUSTIFICADA', 'LICENCIA'));

ALTER TABLE public.usr_docente_inasistencias
    DROP CONSTRAINT IF EXISTS usr_docente_inasistencias_rango_check;
ALTER TABLE public.usr_docente_inasistencias
    ADD CONSTRAINT usr_docente_inasistencias_rango_check
    CHECK (fecha_hasta >= fecha_desde);

-- =========================================================================
-- E. TRIGGERS
--    alumno_id y legajo_id apuntan al mismo legajo: se mantienen
--    sincronizados porque distintas pantallas consultan por uno u otro.
-- =========================================================================
CREATE OR REPLACE FUNCTION public.sync_alumno_legajo_ids()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $sync$
BEGIN
    NEW.alumno_id := COALESCE(NEW.alumno_id, NEW.legajo_id);
    NEW.legajo_id := COALESCE(NEW.legajo_id, NEW.alumno_id);
    RETURN NEW;
END;
$sync$;

DROP TRIGGER IF EXISTS trg_sync_trayectoria_ids ON public.acad_trayectoria_alumno;
CREATE TRIGGER trg_sync_trayectoria_ids
    BEFORE INSERT OR UPDATE ON public.acad_trayectoria_alumno
    FOR EACH ROW EXECUTE FUNCTION public.sync_alumno_legajo_ids();

DROP TRIGGER IF EXISTS trg_sync_adeudadas_ids ON public.acad_materias_adeudadas;
CREATE TRIGGER trg_sync_adeudadas_ids
    BEFORE INSERT OR UPDATE ON public.acad_materias_adeudadas
    FOR EACH ROW EXECUTE FUNCTION public.sync_alumno_legajo_ids();

DROP TRIGGER IF EXISTS trg_sync_tramite_ids ON public.tramites_solicitudes;
CREATE TRIGGER trg_sync_tramite_ids
    BEFORE INSERT OR UPDATE ON public.tramites_solicitudes
    FOR EACH ROW EXECUTE FUNCTION public.sync_alumno_legajo_ids();

-- Completar datos ya cargados
UPDATE public.acad_materias_adeudadas SET legajo_id = alumno_id WHERE legajo_id IS NULL;

UPDATE public.usr_docentes d
SET nombre   = COALESCE(d.nombre,   u.raw_user_meta_data->>'nombre',   u.raw_user_meta_data->>'first_name'),
    apellido = COALESCE(d.apellido, u.raw_user_meta_data->>'apellido', u.raw_user_meta_data->>'last_name')
FROM auth.users u
WHERE u.id = d.auth_id
  AND (d.nombre IS NULL OR d.apellido IS NULL);

-- =========================================================================
-- F. ÍNDICES
-- =========================================================================
CREATE INDEX IF NOT EXISTS idx_archivos_personal_auth
    ON public.usr_archivos_personal (auth_id, tipo_archivo);

CREATE INDEX IF NOT EXISTS idx_docente_inasistencias_auth
    ON public.usr_docente_inasistencias (auth_id, fecha_desde);

CREATE INDEX IF NOT EXISTS idx_observaciones_aulicas_docente
    ON public.usr_observaciones_aulicas (docente_auth_id, fecha_visita DESC);

CREATE INDEX IF NOT EXISTS idx_trayectoria_alumno
    ON public.acad_trayectoria_alumno (alumno_id, anio_lectivo);

CREATE INDEX IF NOT EXISTS idx_actas_categoria
    ON public.acad_actas (categoria, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tramites_estado
    ON public.tramites_solicitudes (estado, fecha_solicitud DESC);

CREATE INDEX IF NOT EXISTS idx_acad_calendario_temario
    ON public.acad_calendario (curso_id, materia_id, fecha)
    WHERE tipo_evento = 'TEMARIO';

CREATE UNIQUE INDEX IF NOT EXISTS uq_acad_calendario_temario_dia
    ON public.acad_calendario (curso_id, materia_id, fecha)
    WHERE tipo_evento = 'TEMARIO' AND materia_id IS NOT NULL;

-- =========================================================================
-- G. RLS Y PERMISOS
--    Criterio del resto del proyecto: acceso para usuarios autenticados.
--    El legajo docente se restringe al dueño de la fila, salvo dirección.
-- =========================================================================

-- ¿El usuario actual es administración / dirección / preceptoría?
CREATE OR REPLACE FUNCTION public.es_personal_directivo()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $espd$
    SELECT EXISTS (
        SELECT 1 FROM public.usr_docentes
        WHERE auth_id = auth.uid()
          AND (ddjj_cargos::text ILIKE '%ADMIN%'
            OR ddjj_cargos::text ILIKE '%DIRECT%'
            OR ddjj_cargos::text ILIKE '%PRECEPTOR%')
    );
$espd$;

-- Archivos personales: cada uno los suyos; dirección ve todos
ALTER TABLE public.usr_archivos_personal ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS archivos_personal_all    ON public.usr_archivos_personal;
DROP POLICY IF EXISTS archivos_personal_propio ON public.usr_archivos_personal;
CREATE POLICY archivos_personal_propio ON public.usr_archivos_personal
    FOR ALL TO authenticated
    USING (auth_id = auth.uid() OR public.es_personal_directivo())
    WITH CHECK (auth_id = auth.uid() OR public.es_personal_directivo());

-- Faltas y licencias: idem
ALTER TABLE public.usr_docente_inasistencias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS docente_inasistencias_propio ON public.usr_docente_inasistencias;
CREATE POLICY docente_inasistencias_propio ON public.usr_docente_inasistencias
    FOR ALL TO authenticated
    USING (auth_id = auth.uid() OR public.es_personal_directivo())
    WITH CHECK (auth_id = auth.uid() OR public.es_personal_directivo());

-- Observaciones áulicas: el docente lee las suyas y puede marcarlas leídas;
-- sólo dirección las crea.
ALTER TABLE public.usr_observaciones_aulicas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS observaciones_aulicas_lectura   ON public.usr_observaciones_aulicas;
DROP POLICY IF EXISTS observaciones_aulicas_escritura ON public.usr_observaciones_aulicas;
DROP POLICY IF EXISTS observaciones_aulicas_update    ON public.usr_observaciones_aulicas;
CREATE POLICY observaciones_aulicas_lectura ON public.usr_observaciones_aulicas
    FOR SELECT TO authenticated
    USING (docente_auth_id = auth.uid() OR public.es_personal_directivo());
CREATE POLICY observaciones_aulicas_escritura ON public.usr_observaciones_aulicas
    FOR INSERT TO authenticated
    WITH CHECK (public.es_personal_directivo());
CREATE POLICY observaciones_aulicas_update ON public.usr_observaciones_aulicas
    FOR UPDATE TO authenticated
    USING (docente_auth_id = auth.uid() OR public.es_personal_directivo())
    WITH CHECK (docente_auth_id = auth.uid() OR public.es_personal_directivo());

-- Resto de tablas nuevas: acceso autenticado
ALTER TABLE public.acad_trayectoria_alumno ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS trayectoria_alumno_all ON public.acad_trayectoria_alumno;
CREATE POLICY trayectoria_alumno_all ON public.acad_trayectoria_alumno
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.acad_actas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS actas_all ON public.acad_actas;
CREATE POLICY actas_all ON public.acad_actas
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.tramites_solicitudes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tramites_solicitudes_all ON public.tramites_solicitudes;
CREATE POLICY tramites_solicitudes_all ON public.tramites_solicitudes
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.adm_notificaciones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS adm_notificaciones_all ON public.adm_notificaciones;
CREATE POLICY adm_notificaciones_all ON public.adm_notificaciones
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON
    public.usr_archivos_personal,
    public.usr_docente_inasistencias,
    public.usr_observaciones_aulicas,
    public.acad_trayectoria_alumno,
    public.acad_actas,
    public.tramites_solicitudes,
    public.adm_notificaciones
TO authenticated;

GRANT EXECUTE ON FUNCTION public.es_personal_directivo() TO authenticated;

-- =========================================================================
-- H. FUNCIONES
-- =========================================================================

-- H.1 Guardado del propio perfil.
--     La política de usr_docentes sólo permite UPDATE a ADMIN/DIRECTIVO. En
--     vez de abrir la tabla entera (ddjj_cargos define privilegios y un
--     docente podría auto-asignarse ADMIN), se expone una función que
--     actualiza únicamente los campos de contacto de la propia fila.
CREATE OR REPLACE FUNCTION public.actualizar_mi_perfil_docente(
    p_telefono           VARCHAR DEFAULT NULL,
    p_domicilio          VARCHAR DEFAULT NULL,
    p_titulo_profesional VARCHAR DEFAULT NULL,
    p_especialidad       VARCHAR DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $perfil$
BEGIN
    UPDATE public.usr_docentes
    SET telefono           = COALESCE(p_telefono, telefono),
        domicilio          = COALESCE(p_domicilio, domicilio),
        titulo_profesional = COALESCE(p_titulo_profesional, titulo_profesional),
        especialidad       = COALESCE(p_especialidad, especialidad)
    WHERE auth_id = auth.uid();
END;
$perfil$;

GRANT EXECUTE ON FUNCTION public.actualizar_mi_perfil_docente(VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO authenticated;

-- H.2 Listado de personal.
--     Tomaba el nombre sólo de raw_user_meta_data, por eso el perfil mostraba
--     el mail. Ahora prioriza las columnas de usr_docentes.
CREATE OR REPLACE FUNCTION public.get_personal_list()
RETURNS TABLE (
    docente_id UUID, auth_id UUID, email VARCHAR,
    nombre_completo TEXT, ddjj_cargos JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $personal$
BEGIN
    RETURN QUERY
    SELECT
        d.docente_id,
        d.auth_id,
        u.email,
        COALESCE(
            NULLIF(TRIM(CONCAT_WS(' ', d.nombre, d.apellido)), ''),
            u.raw_user_meta_data->>'nombre',
            u.raw_user_meta_data->>'first_name',
            u.email,
            'Sin Nombre'
        )::TEXT,
        d.ddjj_cargos
    FROM public.usr_docentes d
    LEFT JOIN auth.users u ON d.auth_id = u.id;
END;
$personal$;

GRANT EXECUTE ON FUNCTION public.get_personal_list() TO anon, authenticated;

COMMIT;
