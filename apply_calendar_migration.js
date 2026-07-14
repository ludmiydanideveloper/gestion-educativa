const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const pgConfig = {
  // Always use the IPv6 address for Supabase in this environment
  host: '2600:1f1e:90b:a701:bad0:3b1e:7eb2:24fc',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: { rejectUnauthorized: false }
};

async function run() {
  const sqlPath = path.join(__dirname, 'calendar_migration.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');

  console.log("Connecting to Supabase PostgreSQL database via IPv6...");
  const client = new Client(pgConfig);
  try {
    await client.connect();
    console.log("Connected. Executing calendar migration SQL...");
    await client.query(sql);
    console.log("Migration executed successfully!");
  } catch (err) {
    console.error("Migration failed:", err);
  } finally {
    await client.end();
  }
}

run();
