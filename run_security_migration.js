const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const config = {
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: {
    rejectUnauthorized: false
  }
};

async function executeSecurityMigration() {
  const client = new Client(config);
  try {
    console.log("Reading security_migration.sql...");
    const sqlPath = path.join(__dirname, 'security_migration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log("Connecting to Supabase PostgreSQL database...");
    await client.connect();
    console.log("Connected successfully!");

    console.log("Executing security migration SQL...");
    await client.query(sql);
    console.log("Security migration executed successfully!");

    console.log("\n=== VERIFYING RLS ENABLED STATUS ===");
    const rlsRes = await client.query(`
      SELECT schemaname, tablename, rowsecurity 
      FROM pg_tables 
      WHERE schemaname = 'public' 
        AND tablename IN ('asistencia_cabecera', 'asistencia_detalle', 'acad_calificaciones');
    `);
    rlsRes.rows.forEach(row => {
      console.log(`Table: ${row.tablename} | RLS Enabled: ${row.rowsecurity}`);
    });

    console.log("\n=== VERIFYING POLICIES ===");
    const policiesRes = await client.query(`
      SELECT tablename, policyname, roles, cmd, qual
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename IN ('asistencia_cabecera', 'asistencia_detalle', 'acad_calificaciones')
      ORDER BY tablename, policyname;
    `);
    policiesRes.rows.forEach(row => {
      const rolesStr = Array.isArray(row.roles) ? row.roles.join(', ') : String(row.roles);
      console.log(`Table: ${row.tablename} | Policy: ${row.policyname} | Cmd: ${row.cmd}\nRoles: ${rolesStr}\nDefinition: ${row.qual}\n`);
    });

    await client.end();
  } catch (err) {
    console.error("Security migration failed:", err);
    try {
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

executeSecurityMigration();
