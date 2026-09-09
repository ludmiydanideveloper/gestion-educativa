// Aplica admin_pedagogico_proyectos_horarios_migration.sql sobre la base de Supabase.
//
// Uso (PowerShell):
//   $env:SUPABASE_DB_PASSWORD = "tu-password-de-postgres"
//   node run_admin_pedagogico_proyectos_horarios_migration.js
//
// La migración es idempotente: se puede volver a correr sin problema.

const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
const { pgConfig } = require('./db_config');

const ARCHIVO = 'admin_pedagogico_proyectos_horarios_migration.sql';

async function main() {
  const sql = fs.readFileSync(path.join(__dirname, ARCHIVO), 'utf8');
  const client = new Client(pgConfig);

  console.log(`Conectando a ${pgConfig.host}...`);
  await client.connect();
  console.log('Conectado.\n');

  // El propio .sql abre y cierra la transacción (BEGIN ... COMMIT).
  try {
    await client.query(sql);
    console.log(`✅ ${ARCHIVO} aplicada correctamente.`);
  } catch (e) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      // ya estaba fuera de transacción
    }
    console.error(`❌ Error aplicando ${ARCHIVO}: ${e.message}`);
    console.error('   No se modificó nada.');
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error('Error de conexión:', e.message);
  process.exit(1);
});
