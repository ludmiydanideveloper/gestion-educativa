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

async function executeHybridPatches() {
  const client = new Client(config);
  try {
    console.log("Connecting to Supabase PostgreSQL database...");
    await client.connect();
    console.log("Connected successfully!\n");

    console.log("Executing security_migration.sql (hybrid RLS policy update)...");
    const sqlPath = path.join(__dirname, 'security_migration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    await client.query(sql);
    console.log("Successfully completed hybrid RLS policy migration for assistance tables.");

    console.log("\n=== VERIFYING HYBRID POLICIES ===");
    const tablesToCheck = ['asistencia_cabecera', 'asistencia_detalle'];

    const policiesRes = await client.query(`
      SELECT tablename, policyname, roles, cmd, qual, with_check
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = ANY($1)
      ORDER BY tablename, policyname;
    `, [tablesToCheck]);

    policiesRes.rows.forEach(row => {
      const rolesStr = Array.isArray(row.roles) ? row.roles.join(', ') : String(row.roles);
      console.log(`Table: ${row.tablename} | Policy: ${row.policyname} | Cmd: ${row.cmd}`);
      console.log(`  Roles: ${rolesStr}`);
      console.log(`  USING definition: ${row.qual}`);
      if (row.with_check) {
        console.log(`  WITH CHECK definition: ${row.with_check}`);
      }
      console.log();
    });

    await client.end();
    console.log("Database hybrid patch process completed successfully.");
  } catch (err) {
    console.error("Database hybrid patching failed:", err);
    try {
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

executeHybridPatches();
