require('./load_env');
const { createClient } = require('@supabase/supabase-js');
const { Client } = require('pg');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://qiwwmlysqidwnywmrwko.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!SERVICE_ROLE_KEY) {
  console.error('Falta SUPABASE_SERVICE_ROLE_KEY en .env (clave "secret" del dashboard, sb_secret_...).');
  process.exit(1);
}

const pgConfig = {
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
};

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function arreglarYProbar() {
  const pgClient = new Client(pgConfig);
  try {
    await pgClient.connect();
    console.log("=== 1. OBTENiendo ESTRUCTURA EXACTA DE ADMIN ===");
    const uRes = await pgClient.query(`
      SELECT * FROM auth.users WHERE email = 'admin@colegio.com';
    `);
    const adminRow = uRes.rows[0];

    console.log("=== 2. ACTUALIZANDO DANUU PARA COINCIDIR EXACTAMENTE CON ADMIN ===");
    // Actualizamos las columnas que difieren a los valores/tipos exactos que usa GoTrue en admin
    await pgClient.query(`
      UPDATE auth.users SET
        email_change_token_new = '',
        email_change = '',
        email_change_token_current = '',
        phone_change = '',
        phone_change_token = '',
        is_super_admin = NULL,
        phone_confirmed_at = NULL,
        phone = NULL,
        confirmation_token = '',
        recovery_token = '',
        banned_until = NULL,
        reauthentication_token = '',
        is_sso_user = false,
        deleted_at = NULL
      WHERE email ILIKE 'danuugomez@hotmail.com';
    `);

    // También verificamos si la contraseña está bien hasheada o si GoTrue requiere un formato específico de crypt
    // Hagamos una prueba de inicio de sesión
    console.log("\n=== 3. PROBANDO LOGIN DESPUÉS DEL AJUSTE ===");
    let resDanu = await supabase.auth.signInWithPassword({
      email: 'Danuugomez@hotmail.com',
      password: '37768924'
    });

    if (resDanu.error) {
      console.log("❌ Aún da error con hash crypt:", resDanu.error.message);
      console.log("=== 4. RE-HASHEANDO CONTRASEÑA USANDO API OFICIAL DE GOTRUE ===");
      
      // Obtenemos el ID del usuario
      const dRes = await pgClient.query(`SELECT id FROM auth.users WHERE email ILIKE 'danuugomez@hotmail.com'`);
      if (dRes.rows.length > 0) {
        const userId = dRes.rows[0].id;
        const { error: updErr } = await supabase.auth.admin.updateUserById(userId, {
          password: '37768924',
          email_confirm: true
        });
        if (updErr) {
          console.log("❌ Error en updateUserById:", updErr.message);
        } else {
          console.log("✅ Contraseña actualizada vía Admin API.");
          
          resDanu = await supabase.auth.signInWithPassword({
            email: 'Danuugomez@hotmail.com',
            password: '37768924'
          });
          if (resDanu.error) {
            console.log("❌ Error post Admin API:", resDanu.error.message);
          } else {
            console.log("🎉 ¡LOGIN EXITOSO CON DANUU! User ID:", resDanu.data.user.id);
          }
        }
      }
    } else {
      console.log("🎉 ¡LOGIN EXITOSO CON DANUU! User ID:", resDanu.data.user.id);
    }

    // Finalmente, veamos cómo quedó exactamente el usuario
    const finalCheck = await pgClient.query(`SELECT id, email, encrypted_password FROM auth.users WHERE email ILIKE 'danuugomez@hotmail.com'`);
    console.log("\nEstado final del usuario en DB:", finalCheck.rows[0]?.email, "| ID:", finalCheck.rows[0]?.id);

  } catch (err) {
    console.error("Error general:", err);
  } finally {
    await pgClient.end();
  }
}

arreglarYProbar();
