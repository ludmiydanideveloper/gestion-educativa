const { createClient } = require('@supabase/supabase-js');
const { Client } = require('pg');

const SUPABASE_URL = 'https://qiwwmlysqidwnywmrwko.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8';

const pgConfig = {
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: { rejectUnauthorized: false }
};

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function testLoginAndCompare() {
  console.log("=== 1. PROBANDO LOGIN CON ADMIN (admin@colegio.com) ===");
  const resAdmin = await supabase.auth.signInWithPassword({
    email: 'admin@colegio.com',
    password: 'Password123!'
  });
  if (resAdmin.error) {
    console.log("❌ Error login admin@colegio.com:", resAdmin.error.message, resAdmin.error);
  } else {
    console.log("✅ Login OK admin@colegio.com! User ID:", resAdmin.data.user.id);
  }

  console.log("\n=== 2. PROBANDO LOGIN CON DANUU (Danuugomez@hotmail.com) ===");
  const resDanu = await supabase.auth.signInWithPassword({
    email: 'Danuugomez@hotmail.com',
    password: '37768924'
  });
  if (resDanu.error) {
    console.log("❌ Error login Danuugomez@hotmail.com:", resDanu.error.message, resDanu.error);
  } else {
    console.log("✅ Login OK Danuugomez@hotmail.com! User ID:", resDanu.data.user.id);
  }

  console.log("\n=== 3. COMPARANDO TODAS LAS COLUMNAS EN AUTH.USERS ===");
  const pgClient = new Client(pgConfig);
  try {
    await pgClient.connect();
    const uRes = await pgClient.query(`
      SELECT * FROM auth.users WHERE email IN ('admin@colegio.com', 'Danuugomez@hotmail.com');
    `);
    
    const adminUser = uRes.rows.find(r => r.email === 'admin@colegio.com');
    const danuUser = uRes.rows.find(r => r.email === 'Danuugomez@hotmail.com');
    
    if (adminUser && danuUser) {
      for (const col of Object.keys(adminUser)) {
        const valA = adminUser[col];
        const valD = danuUser[col];
        if (JSON.stringify(valA) !== JSON.stringify(valD) && col !== 'id' && col !== 'email' && col !== 'encrypted_password' && col !== 'created_at' && col !== 'updated_at' && col !== 'raw_user_meta_data') {
          console.log(`[DIFERENCIA EN COLUMNA '${col}']:`);
          console.log(`  -> admin@colegio.com:      `, valA);
          console.log(`  -> Danuugomez@hotmail.com: `, valD);
        }
      }
    }

    console.log("\n=== 4. COMPARANDO IDENTIDADES EN AUTH.IDENTITIES ===");
    const iRes = await pgClient.query(`
      SELECT * FROM auth.identities WHERE user_id IN ('${adminUser?.id}', '${danuUser?.id}');
    `);
    const adminIden = iRes.rows.find(r => r.user_id === adminUser?.id);
    const danuIden = iRes.rows.find(r => r.user_id === danuUser?.id);

    if (adminIden && danuIden) {
      for (const col of Object.keys(adminIden)) {
        const valA = adminIden[col];
        const valD = danuIden[col];
        if (JSON.stringify(valA) !== JSON.stringify(valD) && col !== 'id' && col !== 'user_id' && col !== 'provider_id' && col !== 'email' && col !== 'created_at' && col !== 'updated_at') {
          console.log(`[DIFERENCIA EN IDENTIDAD '${col}']:`);
          console.log(`  -> admin@colegio.com:      `, valA);
          console.log(`  -> Danuugomez@hotmail.com: `, valD);
        }
      }
    }
  } catch (err) {
    console.error("Error PG:", err);
  } finally {
    await pgClient.end();
  }
}

testLoginAndCompare();
