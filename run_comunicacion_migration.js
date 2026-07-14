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

async function executeMigration() {
  const client = new Client(config);
  try {
    console.log("Reading comunicacion_migration.sql...");
    const sqlPath = path.join(__dirname, 'comunicacion_migration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log("Connecting to Supabase PostgreSQL database...");
    await client.connect();
    console.log("Connected successfully!");

    console.log("Executing communication migration SQL...");
    await client.query(sql);
    console.log("Communication migration executed successfully!");

    console.log("\n=== VERIFYING TABLES ===");
    const tablesRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name IN ('com_mensajes', 'com_destinatarios');
    `);
    tablesRes.rows.forEach(row => {
      console.log(`Table created: ${row.table_name}`);
    });

    console.log("\n=== VERIFYING RLS STATUS ===");
    const rlsRes = await client.query(`
      SELECT tablename, rowsecurity 
      FROM pg_tables 
      WHERE schemaname = 'public' AND tablename IN ('com_mensajes', 'com_destinatarios');
    `);
    rlsRes.rows.forEach(row => {
      console.log(`Table: ${row.tablename} | RLS Enabled: ${row.rowsecurity}`);
    });

    console.log("\n=== VERIFYING POLICIES ===");
    const policiesRes = await client.query(`
      SELECT tablename, policyname, cmd
      FROM pg_policies
      WHERE schemaname = 'public' AND tablename IN ('com_mensajes', 'com_destinatarios')
      ORDER BY tablename, policyname;
    `);
    policiesRes.rows.forEach(row => {
      console.log(`Table: ${row.tablename} | Policy: ${row.policyname} | Cmd: ${row.cmd}`);
    });

    await client.end();
  } catch (err) {
    console.error("Communication migration failed:", err);
    try {
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

executeMigration();
