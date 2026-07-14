-- ========================================================
-- MÓDULO DE ADMINISTRACIÓN (ABM) Y CONTROL DE ACCESOS
-- ========================================================

-- 1. Habilitar extensión pgcrypto para encriptación de contraseñas si no está activa
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. FUNCIÓN RPC: admin_create_user
CREATE OR REPLACE FUNCTION admin_create_user(
    p_email TEXT,
    p_password TEXT,
    p_rol TEXT, -- 'ADMIN', 'PRECEPTOR', 'DOCENTE', 'ALUMNO', 'PADRE'
    p_nombre TEXT,
    p_apellido TEXT,
    p_dni TEXT,
    p_curso_id UUID DEFAULT NULL
) RETURNS UUID
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_docente_id UUID;
    v_legajo_id UUID;
    v_grupo_id UUID;
    v_grupo_nombre TEXT;
    v_password_hash TEXT;
    v_current_rol TEXT;
BEGIN
    -- Control de Acceso: Solo ADMIN o DIRECTIVO pueden ejecutar esta acción
    v_current_rol := auth.jwt() -> 'user_metadata' ->> 'rol';
    IF NOT (v_current_rol IN ('ADMIN', 'DIRECTIVO')) THEN
        RAISE EXCEPTION 'Acceso denegado: Se requieren privilegios de Administrador o Directivo';
    END IF;

    -- Usar DNI como contraseña temporal si no se provee otra
    IF p_password IS NULL OR p_password = '' THEN
        v_password_hash := crypt(p_dni, gen_salt('bf'));
    ELSE
        v_password_hash := crypt(p_password, gen_salt('bf'));
    END IF;

    -- Crear credencial en auth.users
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        is_super_admin,
        created_at,
        updated_at,
        phone_confirmed_at,
        confirmed_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        p_email,
        v_password_hash,
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        json_build_object('rol', p_rol, 'nombre', p_nombre || ' ' || p_apellido)::jsonb,
        false,
        now(),
        now(),
        now(),
        now()
    ) RETURNING id INTO v_user_id;

    -- Insertar el perfil correspondiente en las tablas públicas
    IF p_rol IN ('ADMIN', 'PRECEPTOR', 'DOCENTE') THEN
        INSERT INTO usr_docentes (auth_id, ddjj_cargos)
        VALUES (
            v_user_id,
            json_build_array(json_build_object('cargo', p_rol, 'jerarquia', CASE WHEN p_rol = 'ADMIN' THEN 1 ELSE 2 END))::jsonb
        ) RETURNING docente_id INTO v_docente_id;
        
    ELSIF p_rol = 'ALUMNO' THEN
        INSERT INTO usr_legajo_alumno (auth_id, datos_demograficos)
        VALUES (
            v_user_id,
            json_build_object(
                'nombre', p_nombre || ' ' || p_apellido,
                'nombre_pila', p_nombre,
                'apellido', p_apellido,
                'dni', p_dni
            )::jsonb
        ) RETURNING legajo_id INTO v_legajo_id;
        
        -- Matricular si se provee curso_id
        IF p_curso_id IS NOT NULL THEN
            INSERT INTO acad_inscripciones (alumno_id, curso_id, estado)
            VALUES (v_legajo_id, p_curso_id, 'ACTIVO');
        END IF;
        
    ELSIF p_rol IN ('PADRE', 'FAMILIA') THEN
        -- Crear grupo familiar
        v_grupo_nombre := 'Familia ' || p_apellido;
        INSERT INTO fin_grupos_familiares (nombre_grupo)
        VALUES (v_grupo_nombre)
        RETURNING grupo_id INTO v_grupo_id;
        
        -- Crear cuenta corriente
        INSERT INTO fin_cuentas_corrientes (grupo_id, documento_fiscal, moneda)
        VALUES (v_grupo_id, p_dni, 'ARS');
        
        INSERT INTO usr_legajo_alumno (auth_id, grupo_id, rol_financiero, datos_demograficos)
        VALUES (
            v_user_id,
            v_grupo_id,
            'RESPONSABLE_PAGO',
            json_build_object(
                'nombre', p_nombre || ' ' || p_apellido,
                'nombre_pila', p_nombre,
                'apellido', p_apellido,
                'dni', p_dni
            )::jsonb
        ) RETURNING legajo_id INTO v_legajo_id;
    END IF;

    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;

-- 3. FUNCIÓN RPC: admin_update_user
CREATE OR REPLACE FUNCTION admin_update_user(
    p_user_id UUID,
    p_email TEXT,
    p_nombre TEXT,
    p_apellido TEXT,
    p_dni TEXT
) RETURNS VOID
SECURITY DEFINER
AS $$
DECLARE
    v_current_rol TEXT;
    v_user_rol TEXT;
BEGIN
    -- Control de Acceso: Solo ADMIN o DIRECTIVO pueden ejecutar esta acción
    v_current_rol := auth.jwt() -> 'user_metadata' ->> 'rol';
    IF NOT (v_current_rol IN ('ADMIN', 'DIRECTIVO')) THEN
        RAISE EXCEPTION 'Acceso denegado: Se requieren privilegios de Administrador o Directivo';
    END IF;

    -- Obtener rol del usuario a actualizar
    SELECT raw_user_meta_data ->> 'rol' INTO v_user_rol FROM auth.users WHERE id = p_user_id;

    -- Actualizar auth.users
    UPDATE auth.users
    SET email = p_email,
        raw_user_meta_data = json_build_object('rol', v_user_rol, 'nombre', p_nombre || ' ' || p_apellido)::jsonb,
        updated_at = now()
    WHERE id = p_user_id;

    -- Actualizar perfil en tablas públicas
    IF v_user_rol IN ('ADMIN', 'PRECEPTOR', 'DOCENTE') THEN
        -- usr_docentes no tiene columnas de nombre porque están en auth.users
        -- Pero podemos agregar algún metadato si es necesario.
    ELSE
        -- Alumnos/Padres están en usr_legajo_alumno
        UPDATE usr_legajo_alumno
        SET datos_demograficos = json_build_object(
            'nombre', p_nombre || ' ' || p_apellido,
            'nombre_pila', p_nombre,
            'apellido', p_apellido,
            'dni', p_dni
        )::jsonb
        WHERE auth_id = p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 4. FUNCIÓN RPC: admin_delete_user
CREATE OR REPLACE FUNCTION admin_delete_user(p_user_id UUID)
RETURNS VOID
SECURITY DEFINER
AS $$
DECLARE
    v_current_rol TEXT;
    v_user_rol TEXT;
    v_legajo_id UUID;
    v_docente_id UUID;
BEGIN
    -- Control de Acceso: Solo ADMIN o DIRECTIVO pueden ejecutar esta acción
    v_current_rol := auth.jwt() -> 'user_metadata' ->> 'rol';
    IF NOT (v_current_rol IN ('ADMIN', 'DIRECTIVO')) THEN
        RAISE EXCEPTION 'Acceso denegado: Se requieren privilegios de Administrador o Directivo';
    END IF;

    -- Obtener rol del usuario a eliminar
    SELECT raw_user_meta_data ->> 'rol' INTO v_user_rol FROM auth.users WHERE id = p_user_id;

    -- Eliminar perfiles en tablas públicas para evitar huérfanos antes de auth.users si es necesario
    -- O simplemente borrar de auth.users y dejar que cascada actúe (las refs son ON DELETE SET NULL)
    -- Si borramos perfil primero, evitamos referencias colgantes
    IF v_user_rol IN ('ADMIN', 'PRECEPTOR', 'DOCENTE') THEN
        DELETE FROM usr_docentes WHERE auth_id = p_user_id;
    ELSE
        DELETE FROM usr_legajo_alumno WHERE auth_id = p_user_id;
    END IF;

    -- Eliminar credencial de auth.users
    DELETE FROM auth.users WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- 5. FUNCIÓN RPC: admin_link_student_to_family
CREATE OR REPLACE FUNCTION admin_link_student_to_family(
    p_student_legajo_id UUID,
    p_family_grupo_id UUID
) RETURNS VOID
SECURITY DEFINER
AS $$
DECLARE
    v_current_rol TEXT;
BEGIN
    -- Control de Acceso: Solo ADMIN o DIRECTIVO pueden ejecutar esta acción
    v_current_rol := auth.jwt() -> 'user_metadata' ->> 'rol';
    IF NOT (v_current_rol IN ('ADMIN', 'DIRECTIVO')) THEN
        RAISE EXCEPTION 'Acceso denegado: Se requieren privilegios de Administrador o Directivo';
    END IF;

    UPDATE usr_legajo_alumno
    SET grupo_id = p_family_grupo_id
    WHERE legajo_id = p_student_legajo_id;
END;
$$ LANGUAGE plpgsql;

-- 6. FUNCIÓN RPC: get_personal_list
CREATE OR REPLACE FUNCTION get_personal_list()
RETURNS TABLE (
    docente_id UUID,
    auth_id UUID,
    email VARCHAR,
    nombre_completo TEXT,
    ddjj_cargos JSONB
)
SECURITY DEFINER
AS $$
DECLARE
    v_current_rol TEXT;
BEGIN
    v_current_rol := auth.jwt() -> 'user_metadata' ->> 'rol';
    IF NOT (v_current_rol IN ('ADMIN', 'DIRECTIVO', 'PRECEPTOR', 'DOCENTE')) THEN
        RAISE EXCEPTION 'Acceso denegado: Se requiere rol del personal';
    END IF;

    RETURN QUERY
    SELECT 
        d.docente_id,
        d.auth_id,
        u.email,
        COALESCE(u.raw_user_meta_data->>'nombre', 'Sin Nombre'),
        d.ddjj_cargos
    FROM usr_docentes d
    LEFT JOIN auth.users u ON d.auth_id = u.id;
END;
$$ LANGUAGE plpgsql;

-- 7. FUNCIÓN RPC: get_alumnos_list
CREATE OR REPLACE FUNCTION get_alumnos_list()
RETURNS TABLE (
    legajo_id UUID,
    auth_id UUID,
    email VARCHAR,
    nombre_completo TEXT,
    dni TEXT,
    grupo_id UUID,
    rol_financiero VARCHAR,
    curso_nombre VARCHAR,
    curso_id UUID
)
SECURITY DEFINER
AS $$
DECLARE
    v_current_rol TEXT;
BEGIN
    v_current_rol := auth.jwt() -> 'user_metadata' ->> 'rol';
    IF NOT (v_current_rol IN ('ADMIN', 'DIRECTIVO', 'PRECEPTOR', 'DOCENTE')) THEN
        RAISE EXCEPTION 'Acceso denegado: Se requiere rol del personal';
    END IF;

    RETURN QUERY
    SELECT 
        la.legajo_id,
        la.auth_id,
        u.email,
        COALESCE(la.datos_demograficos->>'nombre', 'Sin Nombre'),
        (la.datos_demograficos->>'dni')::TEXT,
        la.grupo_id,
        la.rol_financiero::VARCHAR,
        c.identificador_division::VARCHAR,
        c.curso_id
    FROM usr_legajo_alumno la
    LEFT JOIN auth.users u ON la.auth_id = u.id
    LEFT JOIN acad_inscripciones ins ON ins.alumno_id = la.legajo_id AND ins.estado = 'ACTIVO'
    LEFT JOIN acad_cursos c ON ins.curso_id = c.curso_id
    WHERE la.rol_financiero IS NULL OR la.rol_financiero <> 'RESPONSABLE_PAGO';
END;
$$ LANGUAGE plpgsql;

-- 8. FUNCIÓN RPC: get_tutores_list
CREATE OR REPLACE FUNCTION get_tutores_list()
RETURNS TABLE (
    legajo_id UUID,
    auth_id UUID,
    email VARCHAR,
    nombre_completo TEXT,
    dni TEXT,
    grupo_id UUID,
    rol_financiero VARCHAR,
    grupo_nombre VARCHAR
)
SECURITY DEFINER
AS $$
DECLARE
    v_current_rol TEXT;
BEGIN
    v_current_rol := auth.jwt() -> 'user_metadata' ->> 'rol';
    IF NOT (v_current_rol IN ('ADMIN', 'DIRECTIVO', 'PRECEPTOR', 'DOCENTE')) THEN
        RAISE EXCEPTION 'Acceso denegado: Se requiere rol del personal';
    END IF;

    RETURN QUERY
    SELECT 
        la.legajo_id,
        la.auth_id,
        u.email,
        COALESCE(la.datos_demograficos->>'nombre', 'Sin Nombre'),
        (la.datos_demograficos->>'dni')::TEXT,
        la.grupo_id,
        la.rol_financiero::VARCHAR,
        f.nombre_grupo::VARCHAR
    FROM usr_legajo_alumno la
    LEFT JOIN auth.users u ON la.auth_id = u.id
    LEFT JOIN fin_grupos_familiares f ON la.grupo_id = f.grupo_id
    WHERE la.rol_financiero = 'RESPONSABLE_PAGO';
END;
$$ LANGUAGE plpgsql;
