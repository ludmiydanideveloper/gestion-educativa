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

async function verifyDB() {
  const client = new Client(config);
  try {
    await client.connect();
    
    const cabeceras = await client.query("SELECT * FROM asistencia_cabecera;");
    console.log(`Number of cabeceras: ${cabeceras.rows.length}`);
    if (cabeceras.rows.length > 0) {
      console.log(cabeceras.rows);
    }

    const detalles = await client.query("SELECT * FROM asistencia_detalle;");
    console.log(`Number of detalles: ${detalles.rows.length}`);
    if (detalles.rows.length > 0) {
      console.log(detalles.rows);
    }

    await client.end();
  } catch (err) {
    console.error("Verification failed:", err);
    try {
      await client.end();
    } catch (_) {}
  }
}

verifyDB();
