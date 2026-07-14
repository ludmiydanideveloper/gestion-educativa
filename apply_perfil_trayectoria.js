const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const pgConfig = {
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: { rejectUnauthorized: false }
};

async function applyMigration() {
  const client = new Client(pgConfig);
  try {
    console.log("🔌 Conectando a Supabase PostgreSQL...");
    await client.connect();
    console.log("✅ Conectado!");

    const sqlPath = path.join(__dirname, 'perfil_trayectoria_tramites_migration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log("🚀 Ejecutando migración para Perfiles, Trayectoria, Materias Adeudadas y Trámites...");
    await client.query(sql);
    console.log("✅ ¡Migración aplicada correctamente!");

    // Insertar algunos datos iniciales de ejemplo si las tablas están vacías
    const checkTray = await client.query('SELECT COUNT(*) FROM acad_trayectoria_alumno;');
    if (parseInt(checkTray.rows[0].count) === 0) {
      console.log("🌱 Poblando datos de ejemplo de trayectoria escolar y materias adeudadas RITE...");
      const alumnosRes = await client.query('SELECT legajo_id, datos_demograficos FROM usr_legajo_alumno LIMIT 5;');
      
      for (const a of alumnosRes.rows) {
        // Cursos anteriores aprobados
        await client.query(`
          INSERT INTO acad_trayectoria_alumno (legajo_id, curso_nombre, anio_lectivo, condicion, promedio, observaciones)
          VALUES 
            ($1, '1° Año División A', 2024, 'APROBADO', 8.50, 'Excelente desempeño durante el ciclo.'),
            ($1, '2° Año División A', 2025, 'APROBADO', 7.80, 'Promovido satisfactoriamente.'),
            ($1, '3° Año División B (Actual)', 2026, 'EN_CURSO', 8.10, 'Cursando ciclo actual con regularidad.');
        `, [a.legajo_id]);

        // Materia adeudada RITE de ejemplo
        await client.query(`
          INSERT INTO acad_materias_adeudadas (legajo_id, nombre_materia, anio_origen, condicion, estado, observaciones)
          VALUES 
            ($1, 'Matemática I', 2024, 'ADEUDADA_RITE', 'PENDIENTE', 'Pendiente de acreditación en comisión RITE de julio/diciembre.'),
            ($1, 'Física Elemental', 2025, 'ADEUDADA_RITE', 'EN_PROCESO_RITE', 'En curso de intensificación tutorizada.');
        `, [a.legajo_id]);
      }
      console.log("✅ Datos de ejemplo agregados.");
    }

  } catch (err) {
    console.error("❌ Error aplicando migración:", err);
  } finally {
    await client.end();
  }
}

applyMigration();
