const { Client } = require('pg');
const client = new Client({
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: { rejectUnauthorized: false }
});

async function run() {
  await client.connect();
  // 1. Get the docente_id of the test teacher
  const res = await client.query("SELECT d.docente_id FROM usr_docentes d JOIN auth.users u ON d.auth_id = u.id WHERE u.email = 'docente@colegio.com'");
  if (res.rows.length > 0) {
    const testDocenteId = res.rows[0].docente_id;
    console.log("Test teacher ID:", testDocenteId);
    // 2. Assign them to the 'Matemáticas' subject
    await client.query("UPDATE acad_materias SET docente_titular_id = $1 WHERE nombre_asignatura = 'Matemáticas'", [testDocenteId]);
    console.log("Successfully assigned test teacher to Matemáticas.");
  } else {
    console.log("Teacher not found.");
  }
  await client.end();
}
run();
