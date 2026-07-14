const { Client } = require('pg');

const client = new Client({
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543, // Transaction pooler port (standard for Supabase)
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: {
    rejectUnauthorized: false
  }
});

async function main() {
  try {
    console.log("Connecting to PostgreSQL...");
    await client.connect();
    console.log("Connected successfully!");
    const res = await client.query("SELECT version();");
    console.log("Database version:", res.rows[0].version);
    await client.end();
  } catch (err) {
    console.error("Connection failed:", err.message);
    process.exit(1);
  }
}

main();
