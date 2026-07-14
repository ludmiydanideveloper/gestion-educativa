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
    console.log("Reading migration.sql...");
    const sqlPath = path.join(__dirname, 'migration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log("Connecting to Supabase PostgreSQL database...");
    await client.connect();
    console.log("Connected successfully!");

    console.log("Executing migration SQL...");
    await client.query(sql);
    console.log("Migration executed successfully!");

    console.log("\n=== VERIFYING EXTENSIONS ===");
    const extensionRes = await client.query(`
      SELECT extname, extversion FROM pg_extension WHERE extname IN ('btree_gist', 'uuid-ossp');
    `);
    console.log("Extensions status:");
    console.log(JSON.stringify(extensionRes.rows, null, 2));

    console.log("\n=== VERIFYING TABLES ===");
    const tablesRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE'
      ORDER BY table_name;
    `);
    console.log("Tables in public schema:");
    tablesRes.rows.forEach(row => {
      console.log(` - ${row.table_name}`);
    });

    console.log("\n=== VERIFYING EXCLUSION CONSTRAINTS ===");
    const constraintRes = await client.query(`
      SELECT conname, conrelid::regclass::text AS table_name, pg_get_constraintdef(oid) AS constraint_def
      FROM pg_constraint
      WHERE contype = 'x' AND conname LIKE 'prevent_%';
    `);
    console.log("Exclusion constraints:");
    constraintRes.rows.forEach(row => {
      console.log(`Table: ${row.table_name} | Constraint: ${row.conname}\nDefinition: ${row.constraint_def}\n`);
    });

    await client.end();
  } catch (err) {
    console.error("Migration failed:", err);
    try {
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

executeMigration();
