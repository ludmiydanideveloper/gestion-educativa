const { Client } = require('pg');

const pgConfig = {
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: { rejectUnauthorized: false }
};

async function checkAuth() {
  const client = new Client(pgConfig);
  try {
    await client.connect();
    console.log("=== DIAGNÓSTICO DE AUTH.USERS Y AUTH.IDENTITIES ===");
    
    const usersRes = await client.query(`
      SELECT id, email, aud, role, is_sso_user, confirmation_token, raw_app_meta_data, raw_user_meta_data 
      FROM auth.users 
      WHERE email IN ('admin@colegio.com', 'Danuugomez@hotmail.com', 'danuugomez@hotmail.com');
    `);
    
    console.log("\n1. USUARIOS EN AUTH.USERS:");
    for (const row of usersRes.rows) {
      console.log(`- ID: ${row.id} | Email: ${row.email} | Aud: ${row.aud} | Role: ${row.role}`);
      console.log(`  Meta: ${JSON.stringify(row.raw_user_meta_data)}`);
    }
    
    const ids = usersRes.rows.map(r => `'${r.id}'`).join(',');
    if (ids.length > 0) {
      const identRes = await client.query(`
        SELECT id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at 
        FROM auth.identities 
        WHERE user_id IN (${ids});
      `);
      console.log("\n2. IDENTIDADES EN AUTH.IDENTITIES:");
      for (const row of identRes.rows) {
        console.log(`- UserID: ${row.user_id} | Provider: ${row.provider} | ID: ${row.id}`);
        console.log(`  Data: ${JSON.stringify(row.identity_data)}`);
      }
    }
    
  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

checkAuth();
