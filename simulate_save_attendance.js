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

async function simulate() {
  const client = new Client(config);
  try {
    await client.connect();
    console.log("Connected to Supabase. Starting transaction...");
    
    await client.query("BEGIN;");
    
    console.log("Simulating insert into asistencia_cabecera...");
    const cabeceraRes = await client.query(`
      INSERT INTO asistencia_cabecera (curso_id, fecha, estado, registrado_por_docente_id)
      VALUES (
        '953fc2c3-0737-4ce8-983f-445e67b50f10', 
        '2026-06-12', 
        'APROBADO', 
        'b21dde9b-9afe-4c33-8833-ff3b0df8a6d9'
      )
      RETURNING asistencia_cabecera_id;
    `);
    const cabeceraId = cabeceraRes.rows[0].asistencia_cabecera_id;
    console.log("Cabecera inserted, ID:", cabeceraId);

    const alumnos = [
      { id: "9273567a-d719-4932-9021-fa64b4dcd179", valor: 0.00, tipo: 'PRESENTE' },
      { id: "65e22a20-4c06-4a8f-a99b-2f1fcfa436ea", valor: 1.00, tipo: 'AUSENTE' },
      { id: "a2fe7aad-c31f-4486-b1d5-9f17e7fc9dec", valor: 0.25, tipo: 'TARDE' },
      { id: "1fcd91aa-9595-4f05-a796-48787bddafd6", valor: 0.50, tipo: 'RETIRO_ANTICIPADO' },
      { id: "b08154df-47b6-4f1d-b0c8-90002f0a50cc", valor: 0.00, tipo: 'PRESENTE' },
      { id: "b10789e6-d781-45e9-8b24-66f0e2b36440", valor: 0.00, tipo: 'PRESENTE' },
      { id: "7bdc2abc-fa84-4bd0-b714-c731e46897d2", valor: 0.00, tipo: 'PRESENTE' },
      { id: "10733537-a556-45ef-b73e-df4d3ac2bb9e", valor: 0.00, tipo: 'PRESENTE' },
      { id: "e5564ee9-cff3-4493-b661-67f1d3fb9430", valor: 0.00, tipo: 'PRESENTE' },
      { id: "1298f10a-c50e-4d7d-8a18-dbce05435eda", valor: 0.00, tipo: 'PRESENTE' }
    ];

    console.log("Simulating bulk insert into asistencia_detalle...");
    for (const alumno of alumnos) {
      await client.query(`
        INSERT INTO asistencia_detalle (asistencia_cabecera_id, alumno_id, valor_inasistencia, tipo, estado_justificacion)
        VALUES (
          '${cabeceraId}',
          '${alumno.id}',
          ${alumno.valor},
          '${alumno.tipo}',
          'NINGUNO'
        );
      `);
    }

    console.log("All details inserted successfully! Committing transaction...");
    await client.query("COMMIT;");
    console.log("Transaction committed successfully. Simulation complete and data persisted!");

    await client.end();
  } catch (err) {
    console.error("Simulation failed, rolling back:", err);
    try {
      await client.query("ROLLBACK;");
      await client.end();
    } catch (_) {}
  }
}

simulate();
