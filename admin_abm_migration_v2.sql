-- ============================================================
-- CORRECCIÓN DE FUNCIONES ADMIN (v2 - sin JWT check, columnas correctas)
-- Ejecutar en: https://app.supabase.com/project/qiwwmlysqidwnywmrwko/sql/new
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. admin_create_user: crea usuario en auth + perfil en tabla pública
CREATE OR REPLACE FUNCTION admin_create_user(
    p_email TEXT,
    p_password TEXT,
    p_rol TEXT,
    p_nombre TEXT,
    p_apellido TEXT,
    p_dni TEXT,
    p_curso_id UUID DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id UUID;
    v_legajo_id UUID;
    v_grupo_id UUID;
    v_password_hash TEXT;
BEGIN
    v_password_hash := crypt(p_password, gen_salt('bf'));

    INSERT INTO auth.users (
        instance_id, id, aud, role, email,
        encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data,
        is_super_admin, created_at, updated_at,
        confirmation_token, recovery_token,
        phone_confirmed_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(), 'authenticated', 'authenticated',
        p_email, v_password_hash, now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        json_build_object('rol', p_rol, 'nombre', p_nombre || ' ' || p_apellido)::jsonb,
        false, now(), now(), '', '', now()
    ) RETURNING id INTO v_user_id;

    IF p_rol IN ('ADMIN', 'PRECEPTOR', 'DOCENTE') THEN
        -- usr_docentes solo tiene auth_id y ddjj_cargos (sin datos_demograficos)
        INSERT INTO public.usr_docentes (auth_id, ddjj_cargos)
        VALUES (
            v_user_id,
            json_build_array(json_build_object(
                'cargo', p_rol,
                'jerarquia', CASE WHEN p_rol = 'ADMIN' THEN 1 ELSE 2 END
            ))::jsonb
        );

    ELSIF p_rol = 'ALUMNO' THEN
        INSERT INTO public.usr_legajo_alumno (auth_id, datos_demograficos)
        VALUES (
            v_user_id,
            json_build_object(
                'nombre', p_nombre || ' ' || p_apellido,
                'nombre_pila', p_nombre,
                'apellido', p_apellido,
                'dni', p_dni
            )::jsonb
        ) RETURNING legajo_id INTO v_legajo_id;

        IF p_curso_id IS NOT NULL THEN
            INSERT INTO public.acad_inscripciones (alumno_id, curso_id, estado)
            VALUES (v_legajo_id, p_curso_id, 'ACTIVO');
        END IF;

    ELSIF p_rol IN ('PADRE', 'FAMILIA') THEN
        INSERT INTO public.fin_grupos_familiares (nombre_grupo)
        VALUES ('Familia ' || p_apellido)
        RETURNING grupo_id INTO v_grupo_id;

        INSERT INTO public.fin_cuentas_corrientes (grupo_id, documento_fiscal, moneda)
        VALUES (v_grupo_id, p_dni, 'ARS');

        INSERT INTO public.usr_legajo_alumno (auth_id, grupo_id, rol_financiero, datos_demograficos)
        VALUES (
            v_user_id, v_grupo_id, 'RESPONSABLE_PAGO',
            json_build_object(
                'nombre', p_nombre || ' ' || p_apellido,
                'nombre_pila', p_nombre, 'apellido', p_apellido, 'dni', p_dni
            )::jsonb
        );
    END IF;

    RETURN v_user_id;
END;
$$;
GRANT EXECUTE ON FUNCTION admin_create_user TO anon, authenticated;

-- 2. admin_delete_user
CREATE OR REPLACE FUNCTION admin_delete_user(p_user_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    DELETE FROM public.usr_docentes WHERE auth_id = p_user_id;
    DELETE FROM public.usr_legajo_alumno WHERE auth_id = p_user_id;
    DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;
GRANT EXECUTE ON FUNCTION admin_delete_user TO anon, authenticated;

-- 3. admin_update_user
CREATE OR REPLACE FUNCTION admin_update_user(
    p_user_id UUID, p_email TEXT, p_nombre TEXT, p_apellido TEXT, p_dni TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE v_user_rol TEXT;
BEGIN
    SELECT raw_user_meta_data->>'rol' INTO v_user_rol FROM auth.users WHERE id = p_user_id;
    UPDATE auth.users
    SET email = p_email,
        raw_user_meta_data = json_build_object('rol', v_user_rol, 'nombre', p_nombre || ' ' || p_apellido)::jsonb,
        updated_at = now()
    WHERE id = p_user_id;
    -- Para alumnos/padres actualizar datos_demograficos
    IF v_user_rol NOT IN ('ADMIN', 'PRECEPTOR', 'DOCENTE') THEN
        UPDATE public.usr_legajo_alumno
        SET datos_demograficos = json_build_object(
            'nombre', p_nombre || ' ' || p_apellido,
            'nombre_pila', p_nombre, 'apellido', p_apellido, 'dni', p_dni
        )::jsonb
        WHERE auth_id = p_user_id;
    END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION admin_update_user TO anon, authenticated;

-- 4. get_personal_list: lee nombre desde auth.users.raw_user_meta_data
CREATE OR REPLACE FUNCTION get_personal_list()
RETURNS TABLE (
    docente_id UUID, auth_id UUID, email VARCHAR,
    nombre_completo TEXT, ddjj_cargos JSONB
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.docente_id,
        d.auth_id,
        u.email,
        COALESCE(u.raw_user_meta_data->>'nombre', 'Sin Nombre')::TEXT,
        d.ddjj_cargos
    FROM public.usr_docentes d
    LEFT JOIN auth.users u ON d.auth_id = u.id;
END;
$$;
GRANT EXECUTE ON FUNCTION get_personal_list TO anon, authenticated;

-- 5. get_alumnos_list
CREATE OR REPLACE FUNCTION get_alumnos_list()
RETURNS TABLE (
    legajo_id UUID, auth_id UUID, email VARCHAR,
    nombre_completo TEXT, dni TEXT, grupo_id UUID,
    rol_financiero VARCHAR, curso_nombre VARCHAR, curso_id UUID
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    RETURN QUERY
    SELECT
        la.legajo_id, la.auth_id, u.email,
        COALESCE(la.datos_demograficos->>'nombre', 'Sin Nombre')::TEXT,
        (la.datos_demograficos->>'dni')::TEXT,
        la.grupo_id, la.rol_financiero::VARCHAR,
        c.identificador_division::VARCHAR, c.curso_id
    FROM public.usr_legajo_alumno la
    LEFT JOIN auth.users u ON la.auth_id = u.id
    LEFT JOIN public.acad_inscripciones ins ON ins.alumno_id = la.legajo_id AND ins.estado = 'ACTIVO'
    LEFT JOIN public.acad_cursos c ON ins.curso_id = c.curso_id
    WHERE la.rol_financiero IS NULL OR la.rol_financiero <> 'RESPONSABLE_PAGO';
END;
$$;
GRANT EXECUTE ON FUNCTION get_alumnos_list TO anon, authenticated;

-- 6. get_tutores_list
CREATE OR REPLACE FUNCTION get_tutores_list()
RETURNS TABLE (
    legajo_id UUID, auth_id UUID, email VARCHAR,
    nombre_completo TEXT, dni TEXT, grupo_id UUID,
    rol_financiero VARCHAR, grupo_nombre VARCHAR
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    RETURN QUERY
    SELECT
        la.legajo_id, la.auth_id, u.email,
        COALESCE(la.datos_demograficos->>'nombre', 'Sin Nombre')::TEXT,
        (la.datos_demograficos->>'dni')::TEXT,
        la.grupo_id, la.rol_financiero::VARCHAR,
        f.nombre_grupo::VARCHAR
    FROM public.usr_legajo_alumno la
    LEFT JOIN auth.users u ON la.auth_id = u.id
    LEFT JOIN public.fin_grupos_familiares f ON la.grupo_id = f.grupo_id
    WHERE la.rol_financiero = 'RESPONSABLE_PAGO';
END;
$$;
GRANT EXECUTE ON FUNCTION get_tutores_list TO anon, authenticated;

-- 7. admin_link_student_to_family
CREATE OR REPLACE FUNCTION admin_link_student_to_family(
    p_student_legajo_id UUID, p_family_grupo_id UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.usr_legajo_alumno
    SET grupo_id = p_family_grupo_id
    WHERE legajo_id = p_student_legajo_id;
END;
$$;
GRANT EXECUTE ON FUNCTION admin_link_student_to_family TO anon, authenticated;
