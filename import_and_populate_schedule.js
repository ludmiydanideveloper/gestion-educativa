const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
const XLSX = require('xlsx');

const config = {
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: { rejectUnauthorized: false }
};

async function run() {
  const client = new Client(config);
  try {
    console.log("Connecting to PostgreSQL...");
    await client.connect();
    console.log("Connected successfully!");

    // 1. Run RITE Horarios migration
    console.log("Reading horario_migration.sql...");
    const sqlPath = path.join(__dirname, 'horario_migration.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    console.log("Executing SQL migration...");
    await client.query(sql);
    console.log("Tables and policies created successfully!");

    // 2. Fetch existing sede_id and ciclo_id to link courses correctly
    const sedeRes = await client.query("SELECT sede_id FROM core_sedes LIMIT 1");
    if (sedeRes.rows.length === 0) throw new Error("No Sede found in core_sedes!");
    const sedeId = sedeRes.rows[0].sede_id;

    const cicloRes = await client.query("SELECT ciclo_id FROM core_ciclos_lectivos LIMIT 1");
    if (cicloRes.rows.length === 0) throw new Error("No Ciclo found in core_ciclos_lectivos!");
    const cicloId = cicloRes.rows[0].ciclo_id;

    console.log(`Using Sede: ${sedeId}, Ciclo: ${cicloId}`);

    // Get docente_id for docente@colegio.com
    const docRes = await client.query(
      "SELECT d.docente_id FROM usr_docentes d JOIN auth.users u ON d.auth_id = u.id WHERE u.email = 'docente@colegio.com'"
    );
    if (docRes.rows.length === 0) throw new Error("Teacher docente@colegio.com not found!");
    const docenteId = docRes.rows[0].docente_id;
    console.log(`Found docente_id: ${docenteId} for docente@colegio.com`);

    // 3. Load Excel and parse schedule blocks
    const file = 'C:\\Users\\Administrador\\Downloads\\Horario Secundario Marzo 2026.xlsx';
    console.log(`Reading Excel file: ${file}`);
    const workbook = XLSX.readFile(file);

    const coursesToInsert = []; // Array of { name, sheetName, subjects: Set, entries: [] }
    const courseMap = {}; // name -> course

    workbook.SheetNames.forEach(sheetName => {
      const sheet = workbook.Sheets[sheetName];
      const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });

      for (let r = 0; r < data.length; r++) {
        const row = data[r];
        if (!row) continue;
        for (let c = 0; c < row.length; c++) {
          const val = row[c];
          if (val && typeof val === 'string' && val.includes('HORARIO')) {
            const match = val.match(/HORARIO\s+([^-\(]+)/i);
            const name = match ? match[1].trim() : val;

            if (!courseMap[name]) {
              courseMap[name] = {
                name: name,
                subjects: new Set(),
                entries: []
              };
              coursesToInsert.push(courseMap[name]);
            }
            const courseObj = courseMap[name];

            let currRow = r + 2;
            while (currRow < data.length) {
              const sRow = data[currRow];
              if (!sRow) break;
              const horaVal = sRow[c];

              if (horaVal && typeof horaVal === 'string' && horaVal.includes('HORARIO')) {
                break;
              }
              
              // If HORA is empty, check if entire block is empty to break
              if (horaVal === undefined || horaVal === null || String(horaVal).trim() === '') {
                let blockEmpty = true;
                for (let offset = 0; offset < 6; offset++) {
                  if (sRow[c + offset] !== undefined && sRow[c + offset] !== null && String(sRow[c + offset]).trim() !== '') {
                    blockEmpty = false;
                  }
                }
                if (blockEmpty) break;
              }

              const horaStr = String(horaVal || '').trim();
              if (horaStr && !horaStr.toLowerCase().includes('recreo')) {
                const days = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES'];
                for (let d = 1; d <= 5; d++) {
                  const subjectVal = sRow[c + d];
                  if (subjectVal && String(subjectVal).trim() !== '') {
                    const subName = String(subjectVal).trim();
                    courseObj.subjects.add(subName);
                    courseObj.entries.push({
                      day: days[d - 1],
                      time: horaStr,
                      subject: subName
                    });
                  }
                }
              }
              currRow++;
            }
          }
        }
      }
    });

    console.log(`Parsed ${coursesToInsert.length} courses from Excel.`);

    // 4. Insert into database
    for (const c of coursesToInsert) {
      console.log(`Processing course: ${c.name}...`);
      
      // A. Create/Retrieve Course
      let courseId;
      const cQuery = await client.query(
        "SELECT curso_id FROM acad_cursos WHERE identificador_division = $1 AND sede_id = $2 AND ciclo_id = $3",
        [c.name, sedeId, cicloId]
      );
      if (cQuery.rows.length > 0) {
        courseId = cQuery.rows[0].curso_id;
        console.log(` - Course ${c.name} already exists with ID: ${courseId}`);
      } else {
        const insertC = await client.query(
          "INSERT INTO acad_cursos (sede_id, ciclo_id, identificador_division) VALUES ($1, $2, $3) RETURNING curso_id",
          [sedeId, cicloId, c.name]
        );
        courseId = insertC.rows[0].curso_id;
        console.log(` - Created course ${c.name} with ID: ${courseId}`);
      }

      // B. Create Subjects and Schedule entries
      for (const entry of c.entries) {
        // Find or create materia
        let materiaId;
        const mQuery = await client.query(
          "SELECT materia_id FROM acad_materias WHERE nombre_asignatura = $1 AND curso_id = $2",
          [entry.subject, courseId]
        );
        if (mQuery.rows.length > 0) {
          materiaId = mQuery.rows[0].materia_id;
        } else {
          // If inserting, check if the subject is taught by our test teacher
          let assignedDocenteId = null;
          const subLower = entry.subject.toLowerCase();
          if (subLower.includes('matemática') || subLower.includes('naturales') || subLower.includes('química') || subLower.includes('física')) {
            assignedDocenteId = docenteId;
          }
          
          const insertM = await client.query(
            "INSERT INTO acad_materias (curso_id, nombre_asignatura, docente_titular_id) VALUES ($1, $2, $3) RETURNING materia_id",
            [courseId, entry.subject, assignedDocenteId]
          );
          materiaId = insertM.rows[0].materia_id;
        }

        // Insert Schedule entry
        // Split time (e.g. "7:00- 7:40" or "7:40 - 8:40" or "Matemática 12:40")
        let horaInicio = '08:00';
        let horaFin = '09:00';
        const parts = entry.time.split('-');
        if (parts.length === 2) {
          horaInicio = parts[0].trim();
          horaFin = parts[1].trim();
        }

        // Check if schedule entry already exists
        const hQuery = await client.query(
          "SELECT horario_id FROM acad_horarios WHERE materia_id = $1 AND curso_id = $2 AND dia_semana = $3 AND hora_inicio = $4 AND hora_fin = $5",
          [materiaId, courseId, entry.day, horaInicio, horaFin]
        );
        if (hQuery.rows.length === 0) {
          await client.query(
            "INSERT INTO acad_horarios (materia_id, curso_id, dia_semana, hora_inicio, hora_fin) VALUES ($1, $2, $3, $4, $5)",
            [materiaId, courseId, entry.day, horaInicio, horaFin]
          );
        }

        // C. Crucial: Associate docente in acad_docente_materia_curso if matched
        const subLower = entry.subject.toLowerCase();
        if (subLower.includes('matemática') || subLower.includes('naturales') || subLower.includes('química') || subLower.includes('física')) {
          const assocQuery = await client.query(
            "SELECT id FROM acad_docente_materia_curso WHERE docente_id = $1 AND materia_id = $2 AND curso_id = $3",
            [docenteId, materiaId, courseId]
          );
          if (assocQuery.rows.length === 0) {
            await client.query(
              "INSERT INTO acad_docente_materia_curso (docente_id, materia_id, curso_id) VALUES ($1, $2, $3)",
              [docenteId, materiaId, courseId]
            );
            console.log(`   * Associated ${entry.subject} in ${c.name} to teacher.`);
          }
        }
      }
    }

    console.log("\n=== VERIFYING TEACHER SUBJECTS IN DB ===");
    const associations = await client.query(`
      SELECT 
        c.identificador_division AS curso,
        m.nombre_asignatura AS materia,
        u.email AS docente
      FROM acad_docente_materia_curso r
      JOIN acad_cursos c ON r.curso_id = c.curso_id
      JOIN acad_materias m ON r.materia_id = m.materia_id
      JOIN usr_docentes d ON r.docente_id = d.docente_id
      JOIN auth.users u ON d.auth_id = u.id
      ORDER BY c.identificador_division, m.nombre_asignatura;
    `);
    console.table(associations.rows);

    await client.end();
    console.log("Database import completed successfully.");
  } catch (err) {
    console.error("Import process failed:", err);
    try {
      await client.end();
    } catch (_) {}
    process.exit(1);
  }
}

run();
