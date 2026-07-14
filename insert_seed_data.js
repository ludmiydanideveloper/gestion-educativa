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

async function insertSeedData() {
  const client = new Client(config);
  try {
    await client.connect();
    console.log("Connected to Supabase. Truncating old data to avoid duplicate conflicts...");
    
    // Limpiamos tablas para iniciar semilla limpia
    await client.query("TRUNCATE TABLE core_sedes CASCADE;");
    await client.query("TRUNCATE TABLE usr_legajo_alumno CASCADE;");
    await client.query("TRUNCATE TABLE usr_docentes CASCADE;");

    console.log("Inserting Sede...");
    const SedeRes = await client.query("INSERT INTO core_sedes (nombre_sede) VALUES ('Sede Central') RETURNING sede_id;");
    const sedeId = SedeRes.rows[0].sede_id;

    console.log("Inserting Ciclo Lectivo...");
    const cicloRes = await client.query("INSERT INTO core_ciclos_lectivos (anio_calendario, rango_fechas) VALUES (2026, '[2026-03-01, 2026-12-15]') RETURNING ciclo_id;");
    const cicloId = cicloRes.rows[0].cycle_id || cicloRes.rows[0].ciclo_id;

    console.log("Inserting Curso...");
    const cursoRes = await client.query(`INSERT INTO acad_cursos (sede_id, ciclo_id, identificador_division) VALUES ('${sedeId}', '${cicloId}', '1º Año División A') RETURNING curso_id;`);
    const cursoId = cursoRes.rows[0].curso_id;

    console.log("Inserting Docente...");
    const docenteRes = await client.query("INSERT INTO usr_docentes (ddjj_cargos) VALUES ('[]') RETURNING docente_id;");
    const docenteId = docenteRes.rows[0].docente_id;

    console.log("Inserting 10 Alumnos...");
    const nombres = [
      'Sofía Rodríguez', 'Mateo Fernández', 'Valentina Gómez', 'Thiago López', 'Emma Martínez',
      'Benjamín Díaz', 'Isabella Pérez', 'Joaquín Romero', 'Camila Álvarez', 'Lucas Herrera'
    ];
    
    const alumnos = [];
    for (const nombre of nombres) {
      const alumnoRes = await client.query(`INSERT INTO usr_legajo_alumno (datos_demograficos) VALUES ('{"nombre": "${nombre}"}') RETURNING legajo_id;`);
      alumnos.push({
        id: alumnoRes.rows[0].legajo_id,
        nombre: nombre
      });
    }

    console.log("\n=== SEED DATA GENERATED ===");
    console.log("Curso ID:", cursoId);
    console.log("Docente ID:", docenteId);
    console.log("Alumnos (Copy this into fetchAlumnos()):");
    console.log(JSON.stringify(alumnos, null, 2));

    await client.end();
  } catch (err) {
    console.error("Seed failed:", err);
    try {
      await client.end();
    } catch (_) {}
  }
}

insertSeedData();
