const { Client } = require('pg');

const pgConfig = {
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: { rejectUnauthorized: false }
};

async function reparar() {
  const client = new Client(pgConfig);
  try {
    await client.connect();
    console.log("=== INSPECCIONANDO ESQUEMA DE AUTH.IDENTITIES ===");
    const cols = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_schema = 'auth' AND table_name = 'identities';
    `);
    console.log("Columnas en auth.identities:");
    cols.rows.forEach(r => console.log(` - ${r.column_name}: ${r.data_type}`));
    
    // Veamos un ejemplo real de auth.identities si existe alguno
    const sample = await client.query(`SELECT * FROM auth.identities LIMIT 2;`);
    console.log("\nEjemplo real en auth.identities:", sample.rows);
    
    // Verifiquemos si los usuarios creados manualmente en auth.users tienen identidad en auth.identities
    const missingIdentities = await client.query(`
      SELECT u.id, u.email 
      FROM auth.users u 
      LEFT JOIN auth.identities i ON u.id = i.user_id 
      WHERE i.id IS NULL;
    `);
    
    console.log(`\nUsuarios en auth.users SIN identidad en auth.identities (${missingIdentities.rows.length}):`);
    for (const u of missingIdentities.rows) {
      console.log(` -> ${u.email} (ID: ${u.id}) - CREANDO IDENTIDAD...`);
      // Insertamos la identidad faltante en auth.identities
      await client.query(`
        INSERT INTO auth.identities (
          id,
          user_id,
          identity_data,
          provider,
          provider_id,
          last_sign_in_at,
          created_at,
          updated_at
        )
        VALUES (
          gen_random_uuid(),
          $1::uuid,
          json_build_object('sub', $1::text, 'email', $2::text, 'email_verified', false, 'phone_verified', false)::jsonb,
          'email',
          $1::text,
          now(),
          now(),
          now()
        )
        ON CONFLICT DO NOTHING;
      `, [u.id, u.email]);
    }
    
    console.log("\n✅ ¡Todas las identidades faltantes han sido creadas!");
    
  } catch (err) {
    console.error("Error:", err);
  } finally {
    await client.end();
  }
}

reparar();
