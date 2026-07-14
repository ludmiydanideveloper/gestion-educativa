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

async function testTrigger() {
  const client = new Client(config);
  try {
    await client.connect();
    console.log("Connected to Supabase. Starting Trigger Integration Test...");
    
    // Usamos una transacción con ROLLBACK para asegurar que no queden datos de prueba sucios
    await client.query("BEGIN;");

    // 1. Insertar alumno de prueba
    const alumnoRes = await client.query(`
      INSERT INTO usr_legajo_alumno (datos_demograficos) 
      VALUES ('{"nombre": "Alumno Prueba Automatizacion"}') 
      RETURNING legajo_id;
    `);
    const alumnoId = alumnoRes.rows[0].legajo_id;
    console.log("Test student inserted, ID:", alumnoId);

    // 2. Crear 21 cabeceras en días consecutivos de Julio 2026 para evitar colisión UNIQUE (curso_id, fecha)
    console.log("Creating 21 attendance cabeceras for July 2026...");
    const cabeceras = [];
    for (let i = 0; i < 21; i++) {
      const dia = String(i + 1).padStart(2, '0');
      const fecha = `2026-07-${dia}`;
      const cabRes = await client.query(`
        INSERT INTO asistencia_cabecera (curso_id, fecha, estado, registrado_por_docente_id)
        VALUES ('953fc2c3-0737-4ce8-983f-445e67b50f10', '${fecha}', 'APROBADO', 'b21dde9b-9afe-4c33-8833-ff3b0df8a6d9')
        RETURNING asistencia_cabecera_id;
      `);
      cabeceras.push(cabRes.rows[0].asistencia_cabecera_id);
    }
    console.log("Cabeceras created successfully.");

    // 3. Insertar las primeras 19 inasistencias (Ausentes: valor_inasistencia = 1.00)
    console.log("Inserting first 19 absence records (total: 19.00)...");
    for (let i = 0; i < 19; i++) {
      await client.query(`
        INSERT INTO asistencia_detalle (asistencia_cabecera_id, alumno_id, valor_inasistencia, tipo, estado_justificacion)
        VALUES ('${cabeceras[i]}', '${alumnoId}', 1.00, 'AUSENTE', 'NINGUNO');
      `);
    }

    // 4. Verificar que NO se haya generado ninguna alerta todavía
    const check1 = await client.query(`SELECT COUNT(*) FROM acad_alertas WHERE alumno_id = '${alumnoId}';`);
    const count1 = parseInt(check1.rows[0].count);
    console.log(`Verification 1 (19.00 absences) - Alerts generated: ${count1} (Expected: 0)`);
    if (count1 !== 0) throw new Error("Fallo: Se generó una alerta antes del límite de 20 faltas.");

    // 5. Insertar la falta número 20 (total: 20.00)
    console.log("Inserting the 20th absence record (total: 20.00)...");
    await client.query(`
      INSERT INTO asistencia_detalle (asistencia_cabecera_id, alumno_id, valor_inasistencia, tipo, estado_justificacion)
      VALUES ('${cabeceras[19]}', '${alumnoId}', 1.00, 'AUSENTE', 'NINGUNO');
    `);

    // 6. Verificar que la alerta crítica se haya generado automáticamente
    const check2 = await client.query(`SELECT * FROM acad_alertas WHERE alumno_id = '${alumnoId}';`);
    const count2 = check2.rows.length;
    console.log(`Verification 2 (20.00 absences) - Alerts generated: ${count2} (Expected: 1)`);
    if (count2 !== 1) throw new Error("Fallo: No se generó la alerta crítica al alcanzar las 20 faltas.");
    
    const alerta = check2.rows[0];
    console.log(` -> Alert Details:\n    ID: ${alerta.alerta_id}\n    Tipo: ${alerta.tipo_alerta}\n    Gravedad: ${alerta.gravedad}\n    Mensaje: ${alerta.mensaje}`);
    if (alerta.gravedad !== 'CRITICA') throw new Error("Fallo: La gravedad de la alerta debe ser CRITICA.");

    // 7. Insertar la falta número 21 (total: 21.00) para comprobar prevención de duplicación
    console.log("Inserting the 21st absence record (total: 21.00) to test duplicate avoidance...");
    await client.query(`
      INSERT INTO asistencia_detalle (asistencia_cabecera_id, alumno_id, valor_inasistencia, tipo, estado_justificacion)
      VALUES ('${cabeceras[20]}', '${alumnoId}', 1.00, 'AUSENTE', 'NINGUNO');
    `);

    // 8. Verificar que no se hayan generado alertas adicionales
    const check3 = await client.query(`SELECT COUNT(*) FROM acad_alertas WHERE alumno_id = '${alumnoId}';`);
    const count3 = parseInt(check3.rows[0].count);
    console.log(`Verification 3 (21.00 absences) - Alerts generated: ${count3} (Expected: 1)`);
    if (count3 !== 1) throw new Error("Fallo: Se generó una alerta duplicada al superar las 20 faltas.");

    console.log("\n=================================");
    console.log("   TRIGGER INTEGRATION TEST SUCCESS   ");
    console.log("=================================");

    // Hacemos rollback para no dejar basura en la base de datos de producción
    await client.query("ROLLBACK;");
    console.log("Rollback completed. Database is clean.");
    await client.end();
  } catch (err) {
    console.error("Test failed, rolling back:", err.message);
    try {
      await client.query("ROLLBACK;");
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

testTrigger();
