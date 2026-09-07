// Configuración de conexión a la base, tomada de variables de entorno.
//
// Antes cada script traía el host y la contraseña escritos adentro, así que la
// credencial de postgres quedaba versionada en el repositorio.
//
// Uso (PowerShell):
//   $env:SUPABASE_DB_PASSWORD = "..."
//   node run_migration.js
//
// O dejando un archivo .env local (no versionado) con:
//   SUPABASE_DB_HOST=db.xxxx.supabase.co
//   SUPABASE_DB_PASSWORD=...

require('./load_env');

// Opción A (recomendada): pegar la connection string completa del dashboard
// de Supabase (botón "Connect" > Session pooler) en .env como:
//   SUPABASE_DB_URL=postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres
const connectionString =
  process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;

let pgConfig;

if (connectionString) {
  pgConfig = { connectionString, ssl: { rejectUnauthorized: false } };
} else {
  // Opción B: host/usuario/password por separado.
  const password = process.env.SUPABASE_DB_PASSWORD;
  if (!password) {
    console.error(
      'Falta la configuración de la base.\n' +
      'En un archivo .env (no versionado) poné UNA de estas opciones:\n' +
      '  SUPABASE_DB_URL=postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres\n' +
      '  (la copiás del dashboard: botón "Connect" > Session pooler)\n' +
      'o bien:\n' +
      '  SUPABASE_DB_PASSWORD=tu-password-de-postgres'
    );
    process.exit(1);
  }

  pgConfig = {
    host: process.env.SUPABASE_DB_HOST || 'db.qiwwmlysqidwnywmrwko.supabase.co',
    port: Number(process.env.SUPABASE_DB_PORT || 6543),
    database: process.env.SUPABASE_DB_NAME || 'postgres',
    user: process.env.SUPABASE_DB_USER || 'postgres',
    password,
    ssl: { rejectUnauthorized: false },
  };
}

module.exports = { pgConfig, config: pgConfig };
