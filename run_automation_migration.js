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

async function executeAutomationMigration() {
  const client = new Client(config);
  try {
    console.log("Reading automation_migration.sql...");
    const sqlPath = path.join(__dirname, 'automation_migration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log("Connecting to Supabase PostgreSQL database...");
    await client.connect();
    console.log("Connected successfully!");

    console.log("Executing automation migration SQL...");
    await client.query(sql);
    console.log("Automation migration executed successfully!");

    console.log("\n=== VERIFYING NEW TABLES ===");
    const tablesRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = 'acad_alertas';
    `);
    console.log("Tables found:", tablesRes.rows.map(r => r.table_name));

    console.log("\n=== VERIFYING TRIGGERS ===");
    const triggersRes = await client.query(`
      SELECT trigger_name, event_manipulation, event_object_table, action_statement
      FROM information_schema.triggers
      WHERE trigger_name = 'trg_limite_faltas'
        AND event_object_schema = 'public';
    `);
    triggersRes.rows.forEach(row => {
      console.log(`Trigger: ${row.trigger_name} | Table: ${row.event_object_table} | Event: ${row.event_manipulation}\nStatement: ${row.action_statement}\n`);
    });

    console.log("\n=== VERIFYING FUNCTIONS ===");
    const functionsRes = await client.query(`
      SELECT routine_name, routine_type
      FROM information_schema.routines
      WHERE routine_schema = 'public' AND routine_name = 'fn_monitorear_limite_faltas';
    `);
    functionsRes.rows.forEach(row => {
      console.log(`Function: ${row.routine_name} | Type: ${row.routine_type}`);
    });

    await client.end();
  } catch (err) {
    console.error("Automation migration failed:", err);
    try {
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

executeAutomationMigration();
