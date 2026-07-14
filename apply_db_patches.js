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

async function executePatches() {
  const client = new Client(config);
  try {
    console.log("Connecting to Supabase PostgreSQL database...");
    await client.connect();
    console.log("Connected successfully!\n");

    const sqlFiles = [
      'ledger_migration.sql',
      'security_migration.sql',
      'conducta_migration.sql'
    ];

    for (const file of sqlFiles) {
      console.log(`-----------------------------------------------`);
      console.log(`Executing patches in: ${file}...`);
      const sqlPath = path.join(__dirname, file);
      
      if (!fs.existsSync(sqlPath)) {
        console.warn(`File ${file} does not exist at ${sqlPath}. Skipping.`);
        continue;
      }
      
      const sql = fs.readFileSync(sqlPath, 'utf8');
      
      // We run the migration. To drop old policies and apply new ones, we run the entire file.
      await client.query(sql);
      console.log(`Successfully completed migration for: ${file}`);
    }

    console.log(`-----------------------------------------------`);
    console.log(`\n=== VERIFYING NEW POLICIES ===`);
    
    const tablesToCheck = [
      'fin_grupos_familiares', 
      'fin_cuentas_corrientes', 
      'fin_transacciones', 
      'fin_movimientos',
      'asistencia_cabecera',
      'asistencia_detalle',
      'aca_conducta'
    ];

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
    console.log("Database patch process completed successfully.");
  } catch (err) {
    console.error("Database patching failed:", err);
    try {
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

executePatches();
