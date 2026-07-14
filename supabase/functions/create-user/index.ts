import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Inicializar cliente con service role para poder crear usuarios
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    const { email, password, rol, nombre, apellido, dni, cursoId } = await req.json()

    if (!email || !password || !rol || !nombre || !apellido || !dni) {
      return new Response(
        JSON.stringify({ error: 'Faltan campos requeridos: email, password, rol, nombre, apellido, dni' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 1. Crear usuario en auth.users via Admin API
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        rol,
        nombre: `${nombre} ${apellido}`,
      },
    })

    if (authError) {
      console.error('Error creating auth user:', authError)
      return new Response(
        JSON.stringify({ error: authError.message }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const userId = authData.user.id
    console.log(`Auth user created: ${userId} with rol=${rol}`)

    // 2. Crear perfil en las tablas públicas según el rol
    if (rol === 'ADMIN' || rol === 'PRECEPTOR' || rol === 'DOCENTE') {
      const cargo = [{ cargo: rol, jerarquia: rol === 'ADMIN' ? 1 : 2 }]
      const { error: docenteError } = await supabaseAdmin
        .from('usr_docentes')
        .insert({
          auth_id: userId,
          datos_demograficos: { nombre, apellido, nombre_pila: nombre, dni },
          ddjj_cargos: cargo,
        })
      if (docenteError) {
        console.error('Error inserting docente profile:', docenteError)
        // No falla fatalmente, el usuario auth ya existe
      }
    } else if (rol === 'ALUMNO') {
      const { data: legajoData, error: legajoError } = await supabaseAdmin
        .from('usr_legajo_alumno')
        .insert({
          auth_id: userId,
          datos_demograficos: {
            nombre: `${nombre} ${apellido}`,
            nombre_pila: nombre,
            apellido,
            dni,
          },
        })
        .select('legajo_id')
        .single()

      if (legajoError) {
        console.error('Error inserting alumno profile:', legajoError)
      } else if (cursoId && legajoData?.legajo_id) {
        // Matricular en el curso
        await supabaseAdmin.from('acad_inscripciones').insert({
          alumno_id: legajoData.legajo_id,
          curso_id: cursoId,
          estado: 'ACTIVO',
        })
      }
    } else if (rol === 'PADRE' || rol === 'FAMILIA') {
      // Crear grupo familiar
      const { data: grupoData, error: grupoError } = await supabaseAdmin
        .from('fin_grupos_familiares')
        .insert({ nombre_grupo: `Familia ${apellido}` })
        .select('grupo_id')
        .single()

      if (!grupoError && grupoData?.grupo_id) {
        const grupoId = grupoData.grupo_id

        // Crear cuenta corriente del grupo
        await supabaseAdmin.from('fin_cuentas_corrientes').insert({
          grupo_id: grupoId,
          documento_fiscal: dni,
          moneda: 'ARS',
        })

        // Insertar tutor/padre como responsable de pago
        await supabaseAdmin.from('usr_legajo_alumno').insert({
          auth_id: userId,
          grupo_id: grupoId,
          rol_financiero: 'RESPONSABLE_PAGO',
          datos_demograficos: {
            nombre: `${nombre} ${apellido}`,
            nombre_pila: nombre,
            apellido,
            dni,
          },
        })
      }
    }

    return new Response(
      JSON.stringify({ user_id: userId, message: 'Usuario creado exitosamente' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('Unexpected error:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
