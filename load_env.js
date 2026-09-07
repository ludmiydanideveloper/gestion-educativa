// Carga el archivo .env (no versionado) dentro de process.env, sin dependencias.
// Requerir este módulo al principio de cualquier script:  require('./load_env');
const fs = require('fs');
const path = require('path');

const ruta = path.join(__dirname, '.env');
if (fs.existsSync(ruta)) {
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

module.exports = {};
