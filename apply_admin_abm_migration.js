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
    console.log("Reading admin_abm_migration.sql...");
    const sqlPath = path.join(__dirname, 'admin_abm_migration.sql');
    if (!fs.existsSync(sqlPath)) {
      console.error("Migration file not found!");
      process.exit(1);
    }
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log("Connecting to Supabase PostgreSQL database...");
    await client.connect();
    console.log("Connected successfully!");

    console.log("Executing admin ABM migration SQL...");
    await client.query(sql);
    console.log("Migration executed successfully!");

    console.log("\n=== VERIFYING FUNCTIONS ===");
    const funcsRes = await client.query(`
      SELECT routine_name 
      FROM information_schema.routines 
      WHERE routine_schema = 'public' 
        AND routine_name IN (
          'admin_create_user', 'admin_update_user', 'admin_delete_user', 
          'admin_link_student_to_family', 'get_personal_list', 'get_alumnos_list', 'get_tutores_list'
        )
      ORDER BY routine_name;
    `);
    console.log("Created functions in public schema:");
    funcsRes.rows.forEach(row => {
      console.log(` - ${row.routine_name}`);
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
