-- ========================================================
-- 1. VINCULACIÓN CON EL SISTEMA DE AUTENTICACIÓN DE SUPABASE (auth.users)
-- ========================================================
ALTER TABLE usr_docentes 
ADD COLUMN IF NOT EXISTS auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE usr_legajo_alumno 
ADD COLUMN IF NOT EXISTS auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL;

-- ========================================================
-- 2. ACTIVAR ROW LEVEL SECURITY (RLS) EN TABLAS CLAVE
-- ========================================================
ALTER TABLE asistencia_cabecera ENABLE ROW LEVEL SECURITY;
ALTER TABLE asistencia_detalle ENABLE ROW LEVEL SECURITY;
ALTER TABLE acad_calificaciones ENABLE ROW LEVEL SECURITY;

-- Limpieza de políticas previas si existiesen
DROP POLICY IF EXISTS docente_asistencia_cabecera_all ON asistencia_cabecera;
DROP POLICY IF EXISTS docente_asistencia_detalle_all ON asistencia_detalle;
DROP POLICY IF EXISTS alumno_asistencia_detalle_select ON asistencia_detalle;
DROP POLICY IF EXISTS docente_calificaciones_all ON acad_calificaciones;
DROP POLICY IF EXISTS alumno_calificaciones_select ON acad_calificaciones;

-- ========================================================
-- 3. POLÍTICAS PARA LA TABLA: asistencia_cabecera
-- ========================================================
-- Modelo Híbrido: Acceso global para Preceptores y Administradores,
-- y acceso restringido para Docentes asignados a su respectiva materia/curso.
CREATE POLICY docente_asistencia_cabecera_all ON asistencia_cabecera
FOR ALL TO authenticated
USING (
    (
        EXISTS (
            SELECT 1 FROM usr_docentes 
            WHERE auth_id = auth.uid() 
            AND (ddjj_cargos::text ILIKE '%PRECEPTOR%' OR ddjj_cargos::text ILIKE '%ADMIN%')
        )
    ) OR (
        registrado_por_docente_id = (SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1)
        AND curso_id IN (
            SELECT m.curso_id 
            FROM acad_materias m
            JOIN usr_docentes d ON m.docente_titular_id = d.docente_id
            WHERE d.auth_id = auth.uid()
        )
    )
)
WITH CHECK (
    (
        EXISTS (
            SELECT 1 FROM usr_docentes 
            WHERE auth_id = auth.uid() 
            AND (ddjj_cargos::text ILIKE '%PRECEPTOR%' OR ddjj_cargos::text ILIKE '%ADMIN%')
        )
    ) OR (
        registrado_por_docente_id = (SELECT docente_id FROM usr_docentes WHERE auth_id = auth.uid() LIMIT 1)
        AND curso_id IN (
            SELECT m.curso_id 
            FROM acad_materias m
            JOIN usr_docentes d ON m.docente_titular_id = d.docente_id
            WHERE d.auth_id = auth.uid()
        )
    )
);

-- ========================================================
-- 4. POLÍTICAS PARA LA TABLA: asistencia_detalle
-- ========================================================
-- Modelo Híbrido: Acceso global para Preceptores/Admins y acceso restringido para Docentes.
CREATE POLICY docente_asistencia_detalle_all ON asistencia_detalle
FOR ALL TO authenticated
USING (
    (
        EXISTS (
            SELECT 1 FROM usr_docentes 
            WHERE auth_id = auth.uid() 
            AND (ddjj_cargos::text ILIKE '%PRECEPTOR%' OR ddjj_cargos::text ILIKE '%ADMIN%')
        )
    ) OR (
        asistencia_cabecera_id IN (
            SELECT c.asistencia_cabecera_id 
            FROM asistencia_cabecera c
            WHERE c.curso_id IN (
                SELECT m.curso_id 
                FROM acad_materias m
                JOIN usr_docentes d ON m.docente_titular_id = d.docente_id
                WHERE d.auth_id = auth.uid()
            )
        )
    )
)
WITH CHECK (
    (
        EXISTS (
            SELECT 1 FROM usr_docentes 
            WHERE auth_id = auth.uid() 
            AND (ddjj_cargos::text ILIKE '%PRECEPTOR%' OR ddjj_cargos::text ILIKE '%ADMIN%')
        )
    ) OR (
        asistencia_cabecera_id IN (
            SELECT c.asistencia_cabecera_id 
            FROM asistencia_cabecera c
            WHERE c.curso_id IN (
                SELECT m.curso_id 
                FROM acad_materias m
                JOIN usr_docentes d ON m.docente_titular_id = d.docente_id
                WHERE d.auth_id = auth.uid()
            )
        )
    )
);

-- B. Alumnos/Padres: Solo pueden hacer SELECT de sus propios detalles de asistencia
CREATE POLICY alumno_asistencia_detalle_select ON asistencia_detalle
FOR SELECT
TO authenticated
USING (
    alumno_id = (
        SELECT legajo_id 
        FROM usr_legajo_alumno 
        WHERE auth_id = auth.uid()
    )
);

-- ========================================================
-- 5. POLÍTICAS PARA LA TABLA: acad_calificaciones
-- ========================================================
-- A. Docentes: Pueden hacer ALL en calificaciones de las materias que dictan
CREATE POLICY docente_calificaciones_all ON acad_calificaciones
FOR ALL
TO authenticated
USING (
    materia_id IN (
        SELECT m.materia_id 
        FROM acad_materias m
        JOIN usr_docentes d ON m.docente_titular_id = d.docente_id
        WHERE d.auth_id = auth.uid()
    )
);

-- B. Alumnos/Padres: Solo pueden hacer SELECT de sus propias calificaciones
CREATE POLICY alumno_calificaciones_select ON acad_calificaciones
FOR SELECT
TO authenticated
USING (
    alumno_id = (
        SELECT legajo_id 
        FROM usr_legajo_alumno 
        WHERE auth_id = auth.uid()
    )
);

-- ========================================================
-- 6. LIMPIEZA DE POLÍTICAS OBSOLETAS
-- ========================================================
DROP POLICY IF EXISTS preceptor_admin_asistencia_cabecera_all ON asistencia_cabecera;
DROP POLICY IF EXISTS preceptor_admin_asistencia_detalle_all ON asistencia_detalle;
