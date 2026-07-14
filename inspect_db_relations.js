const { Client } = require('pg');

const config = {
  host: 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: 6543,
  database: 'postgres',
  user: 'postgres',
  password: 'F-8#NvMXp6P+#sU',
  ssl: { rejectUnauthorized: false }
};

async function inspect() {
  const client = new Client(config);
  await client.connect();

  const teachers = await client.query("SELECT d.docente_id, u.email, u.raw_user_meta_data->>'nombre' as nombre, d.ddjj_cargos FROM usr_docentes d LEFT JOIN auth.users u ON d.auth_id = u.id");
  console.log("=== usr_docentes ===");
  console.log(teachers.rows);

  const courses = await client.query("SELECT * FROM acad_cursos");
  console.log("\n=== acad_cursos ===");
  console.log(courses.rows);

  const materias = await client.query("SELECT * FROM acad_materias");
  console.log("\n=== acad_materias ===");
  console.log(materias.rows);

  await client.end();
}

inspect();
