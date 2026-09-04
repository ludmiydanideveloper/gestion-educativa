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

const fs = require('fs');
const path = require('path');

// Carga simple de .env sin dependencias extra
function cargarDotEnv() {
  const ruta = path.join(__dirname, '.env');
  if (!fs.existsSync(ruta)) return;
  for (const linea of fs.readFileSync(ruta, 'utf8').split('\n')) {
    const limpia = linea.trim();
    if (!limpia || limpia.startsWith('#')) continue;
    const sep = limpia.indexOf('=');
    if (sep < 0) continue;
    const clave = limpia.slice(0, sep).trim();
    const valor = limpia.slice(sep + 1).trim().replace(/^["']|["']$/g, '');
    if (!(clave in process.env)) process.env[clave] = valor;
  }
}

cargarDotEnv();

const password = process.env.SUPABASE_DB_PASSWORD;
if (!password) {
  console.error(
    'Falta SUPABASE_DB_PASSWORD.\n' +
    'Definila como variable de entorno o en un archivo .env (no versionado):\n' +
    '  SUPABASE_DB_PASSWORD=tu-password-de-postgres'
  );
  process.exit(1);
}

const pgConfig = {
  host: process.env.SUPABASE_DB_HOST || 'db.qiwwmlysqidwnywmrwko.supabase.co',
  port: Number(process.env.SUPABASE_DB_PORT || 6543),
  database: process.env.SUPABASE_DB_NAME || 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres',
  password,
  ssl: { rejectUnauthorized: false },
};

module.exports = { pgConfig, config: pgConfig };
