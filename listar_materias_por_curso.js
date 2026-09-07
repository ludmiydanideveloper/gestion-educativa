// Lista las materias agrupadas por curso, con el docente asignado si lo hay.
// Solo lee, no modifica nada.
//
// Uso (PowerShell, con .env o la variable ya seteada):
//   node listar_materias_por_curso.js

const { Client } = require('pg');
const { pgConfig } = require('./db_config');

async function main() {
  const client = new Client(pgConfig);
  await client.connect();

  const { rows } = await client.query(`
    SELECT
      c.curso_id,
      c.identificador_division                         AS curso,
      m.materia_id,
      m.nombre_asignatura                              AS materia,
      dt.apellido || ', ' || dt.nombre                 AS titular,
      dt.nombre                                        AS titular_nombre,
      dt.apellido                                      AS titular_apellido,
      (
        SELECT string_agg(DISTINCT d2.apellido || ', ' || d2.nombre, ' | ')
        FROM acad_docente_materia_curso dmc
        JOIN usr_docentes d2 ON d2.docente_id = dmc.docente_id
        WHERE dmc.materia_id = m.materia_id AND dmc.curso_id = c.curso_id
      )                                                AS vinculados
    FROM acad_cursos c
    JOIN acad_materias m ON m.curso_id = c.curso_id
    LEFT JOIN usr_docentes dt ON dt.docente_id = m.docente_titular_id
    ORDER BY c.identificador_division, m.nombre_asignatura
  `);

  await client.end();

  let cursoActual = null;
  for (const r of rows) {
    if (r.curso !== cursoActual) {
      cursoActual = r.curso;
      console.log(`\n=== ${r.curso}  (curso_id: ${r.curso_id}) ===`);
    }
    const asignado =
      (r.titular_nombre || r.titular_apellido)
        ? `  [titular: ${r.titular}]`
        : (r.vinculados ? `  [vinculado: ${r.vinculados}]` : '  [SIN DOCENTE]');
    console.log(`  - ${r.materia}${asignado}   (materia_id: ${r.materia_id})`);
  }
  console.log(`\nTotal: ${rows.length} materias.`);
}

main().catch((e) => {
  console.error('Error:', e.message);
  process.exit(1);
});
