-- ========================================================
-- MÓDULO DE CONDUCTA
-- ========================================================

CREATE TABLE IF NOT EXISTS aca_conducta (
    conducta_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alumno_id UUID NOT NULL REFERENCES usr_legajo_alumno(legajo_id) ON DELETE CASCADE,
    docente_id UUID NOT NULL REFERENCES usr_docentes(docente_id) ON DELETE CASCADE,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tipo_incidencia VARCHAR(100) NOT NULL,
    severidad VARCHAR(50) NOT NULL,
    descripcion TEXT NOT NULL,
    estado VARCHAR(50) NOT NULL DEFAULT 'Pendiente',
    accion_tomada TEXT NULL
);

-- Habilitar Row Level Security
ALTER TABLE aca_conducta ENABLE ROW LEVEL SECURITY;

-- Limpieza de políticas previas (por si acaso)
DROP POLICY IF EXISTS docente_conducta_insert ON aca_conducta;
DROP POLICY IF EXISTS docente_conducta_select ON aca_conducta;
DROP POLICY IF EXISTS directivo_conducta_select ON aca_conducta;

-- 1. Los docentes solo pueden INSERTAR registros que estén a su nombre
CREATE POLICY docente_conducta_insert ON aca_conducta
FOR INSERT
TO authenticated
WITH CHECK (
    docente_id = (SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1)
);

-- 2. Los docentes solo pueden VER sus propios registros de incidencia
CREATE POLICY docente_conducta_select ON aca_conducta
FOR SELECT
TO authenticated
USING (
    docente_id = (SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1)
);

-- 3. Los directivos y preceptores pueden VER todas las incidencias.
-- Como todos están en usr_docentes, verificaremos si tienen un rol jerárquico.
-- Validamos si existe en usr_docentes y si su ddjj_cargos no es DOCENTE estricto
CREATE POLICY directivo_conducta_select ON aca_conducta
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM usr_docentes 
        WHERE auth_id = auth.uid() 
        AND (ddjj_cargos::text ILIKE '%PRECEPTOR%' OR ddjj_cargos::text ILIKE '%ADMIN%')
    )
);

-- 4. Los directivos y preceptores pueden ACTUALIZAR (UPDATE) las incidencias (para resolverlas o modificar el estado/accion)
DROP POLICY IF EXISTS preceptor_admin_conducta_update ON aca_conducta;
CREATE POLICY preceptor_admin_conducta_update ON aca_conducta
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM usr_docentes 
        WHERE auth_id = auth.uid() 
        AND (ddjj_cargos::text ILIKE '%PRECEPTOR%' OR ddjj_cargos::text ILIKE '%ADMIN%')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM usr_docentes 
        WHERE auth_id = auth.uid() 
        AND (ddjj_cargos::text ILIKE '%PRECEPTOR%' OR ddjj_cargos::text ILIKE '%ADMIN%')
    )
);
