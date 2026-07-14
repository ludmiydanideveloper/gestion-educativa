/**
 * deploy_edge_functions.js
 * Despliega las Edge Functions create-user y delete-user en Supabase
 * usando la Management API REST.
 * 
 * USO: node deploy_edge_functions.js
 * REQUISITO: Necesitas el SUPABASE_ACCESS_TOKEN (Personal Access Token de tu cuenta)
 *            Obtenerlo en: https://app.supabase.com/account/tokens
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

// ==================== CONFIGURACIÓN ====================
const PROJECT_REF = 'qiwwmlysqidwnywmrwko';
// Reemplazar con tu Personal Access Token de https://app.supabase.com/account/tokens
const ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || 'TU_ACCESS_TOKEN_AQUI';
// =======================================================

if (ACCESS_TOKEN === 'TU_ACCESS_TOKEN_AQUI') {
  console.error('\n❌ ERROR: Debes configurar tu SUPABASE_ACCESS_TOKEN.');
  console.error('   Obtenerlo en: https://app.supabase.com/account/tokens');
  console.error('   Luego ejecutar: SET SUPABASE_ACCESS_TOKEN=tu_token && node deploy_edge_functions.js\n');
  process.exit(1);
}

function makeRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const bodyStr = body ? JSON.stringify(body) : '';
    const options = {
      hostname: 'api.supabase.com',
      port: 443,
      path,
      method,
      headers: {
        'Authorization': `Bearer ${ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(bodyStr);
    req.end();
  });
}

async function deployFunction(name, sourceFile) {
  console.log(`\n📦 Desplegando función: ${name}`);
  
  const source = fs.readFileSync(sourceFile, 'utf8');
  
  // Intentar actualizar primero (PUT), luego crear (POST)
  let res = await makeRequest('PUT', `/v1/projects/${PROJECT_REF}/functions/${name}`, {
    slug: name,
    name,
    body: source,
    verify_jwt: true,
    import_map: false,
  });

  if (res.status === 404) {
    // Función no existe, crearla
    res = await makeRequest('POST', `/v1/projects/${PROJECT_REF}/functions`, {
      slug: name,
      name,
      body: source,
      verify_jwt: true,
      import_map: false,
    });
  }

  if (res.status >= 200 && res.status < 300) {
    console.log(`   ✅ ${name} desplegada exitosamente (status ${res.status})`);
  } else {
    console.error(`   ❌ Error desplegando ${name} (status ${res.status}):`, res.body);
    throw new Error(`Failed to deploy ${name}`);
  }
}

async function main() {
  console.log('🚀 Iniciando despliegue de Edge Functions en Supabase...');
  console.log(`   Proyecto: ${PROJECT_REF}`);
  
  const functionsDir = path.join(__dirname, 'supabase', 'functions');
  
  try {
    await deployFunction('create-user', path.join(functionsDir, 'create-user', 'index.ts'));
    await deployFunction('delete-user', path.join(functionsDir, 'delete-user', 'index.ts'));
    
    console.log('\n✅ Todas las Edge Functions fueron desplegadas exitosamente!');
    console.log('   Ahora la creación y eliminación de usuarios funcionará correctamente.');
  } catch (err) {
    console.error('\n❌ Error durante el despliegue:', err.message);
    process.exit(1);
  }
}

main();
