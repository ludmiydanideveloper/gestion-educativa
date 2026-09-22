-- =========================================================================
-- FIX: get_alumnos_list() no devolvía datos_demograficos
--
-- fetchAlumnosList() (usada por la Ficha de Alumnos del preceptor/admin) lee
-- adecuacion_curricular / tipo_adecuacion / detalles_adecuacion desde
-- al['datos_demograficos'], pero el RPC get_alumnos_list() nunca devolvía esa
-- columna: la app siempre veía "Sin Adecuación Curricular" aunque se hubiera
-- cargado la ficha EOE (que sí escribe el flag en datos_demograficos como
-- compatibilidad con estos paneles).
--
-- Hay que recrear la función: Postgres no permite cambiar las columnas de
-- retorno de una función con CREATE OR REPLACE, hace falta DROP + CREATE.
--
-- Correr COMPLETO. Idempotente.
--   node run_get_alumnos_list_adecuacion_migration.js
-- =========================================================================

BEGIN;

DROP FUNCTION IF EXISTS public.get_alumnos_list();

CREATE FUNCTION public.get_alumnos_list()
RETURNS TABLE(
    legajo_id UUID,
    auth_id UUID,
    email VARCHAR,
    nombre_completo TEXT,
    dni TEXT,
    grupo_id UUID,
    rol_financiero VARCHAR,
    curso_nombre VARCHAR,
    curso_id UUID,
    datos_demograficos JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$ BEGIN
    RETURN QUERY SELECT la.legajo_id, la.auth_id, u.email,
        COALESCE(la.datos_demograficos->>'nombre', 'Sin Nombre')::TEXT,
        (la.datos_demograficos->>'dni')::TEXT,
        la.grupo_id, la.rol_financiero::VARCHAR, c.identificador_division::VARCHAR, c.curso_id,
        la.datos_demograficos
    FROM public.usr_legajo_alumno la
    LEFT JOIN auth.users u ON la.auth_id = u.id
    LEFT JOIN public.acad_inscripciones ins ON ins.alumno_id = la.legajo_id AND ins.estado = 'ACTIVO'
    LEFT JOIN public.acad_cursos c ON ins.curso_id = c.curso_id
    WHERE la.rol_financiero IS NULL OR la.rol_financiero <> 'RESPONSABLE_PAGO';
END; $function$;

GRANT EXECUTE ON FUNCTION public.get_alumnos_list() TO authenticated;

COMMIT;
