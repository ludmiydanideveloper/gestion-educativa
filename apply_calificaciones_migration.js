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
    console.log("Reading calificaciones_migration.sql...");
    const sqlPath = path.join(__dirname, 'calificaciones_migration.sql');
    if (!fs.existsSync(sqlPath)) {
      console.error("Migration file not found!");
      process.exit(1);
    }
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log("Connecting to Supabase PostgreSQL database...");
    await client.connect();
    console.log("Connected successfully!");

    console.log("Executing calificaciones migration SQL...");
    await client.query(sql);
    console.log("Migration executed successfully!");

    console.log("\n=== VERIFYING TABLES ===");
    const tablesRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name IN ('aca_categorias_nota', 'aca_actividades', 'aca_calificaciones')
      ORDER BY table_name;
    `);
    console.log("Tables in public schema:");
    tablesRes.rows.forEach(row => {
      console.log(` - ${row.table_name}`);
    });

    console.log("\n=== VERIFYING SEEDED CATEGORIES ===");
    const catRes = await client.query(`
      SELECT id, nombre, peso_porcentaje FROM aca_categorias_nota;
    `);
    catRes.rows.forEach(row => {
      console.log(` - Category: ${row.nombre} | Weight: ${row.peso_porcentaje}% | ID: ${row.id}`);
    });

    await client.end();
  } catch (err) {
    console.error("Migration execution failed:", err);
    try {
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

executeMigration();
