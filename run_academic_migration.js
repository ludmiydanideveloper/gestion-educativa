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

async function executeAcademicMigration() {
  const client = new Client(config);
  try {
    console.log("Reading academic_migration.sql...");
    const sqlPath = path.join(__dirname, 'academic_migration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log("Connecting to Supabase PostgreSQL database...");
    await client.connect();
    console.log("Connected successfully!");

    console.log("Executing academic migration SQL...");
    await client.query(sql);
    console.log("Academic migration executed successfully!");

    console.log("\n=== VERIFYING TABLES ===");
    const tablesRes = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name IN (
          'acad_periodos', 'acad_inscripciones', 
          'asistencia_cabecera', 'asistencia_detalle', 
          'acad_calificaciones', 'acad_materias_adeudadas'
        )
      ORDER BY table_name;
    `);
    console.log("New tables in public schema:");
    tablesRes.rows.forEach(row => {
      console.log(` - ${row.table_name}`);
    });

    console.log("\n=== VERIFYING FOREIGN KEYS ===");
    const fksRes = await client.query(`
      SELECT
          tc.table_name, 
          kcu.column_name, 
          ccu.table_name AS foreign_table_name,
          ccu.column_name AS foreign_column_name 
      FROM 
          information_schema.table_constraints AS tc 
          JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
          JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
      WHERE tc.constraint_type = 'FOREIGN KEY' 
        AND tc.table_schema = 'public'
        AND tc.table_name IN (
          'acad_periodos', 'acad_inscripciones', 
          'asistencia_cabecera', 'asistencia_detalle', 
          'acad_calificaciones', 'acad_materias_adeudadas'
        )
      ORDER BY tc.table_name;
    `);
    console.log("Foreign keys of the new tables:");
    fksRes.rows.forEach(row => {
      console.log(` - Table: ${row.table_name}.${row.column_name} -> References: ${row.foreign_table_name}.${row.foreign_column_name}`);
    });

    console.log("\n=== VERIFYING INDEXES ===");
    const indexesRes = await client.query(`
      SELECT
          tablename,
          indexname,
          indexdef
      FROM
          pg_indexes
      WHERE
          schemaname = 'public'
          AND tablename IN (
            'acad_periodos', 'acad_inscripciones', 
            'asistencia_cabecera', 'asistencia_detalle', 
            'acad_calificaciones', 'acad_materias_adeudadas'
          )
      ORDER BY tablename, indexname;
    `);
    console.log("Indexes on the new tables:");
    indexesRes.rows.forEach(row => {
      console.log(` - Table: ${row.tablename} | Index: ${row.indexname}\n   Definition: ${row.indexdef}`);
    });

    await client.end();
  } catch (err) {
    console.error("Academic migration failed:", err);
    try {
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

executeAcademicMigration();
