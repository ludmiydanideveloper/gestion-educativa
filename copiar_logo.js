const fs = require('fs');
const path = require('path');
const os = require('os');

const projectDir = __dirname;
const assetsDir = path.join(projectDir, 'assets');
const imagesDir = path.join(assetsDir, 'images');

if (!fs.existsSync(assetsDir)) fs.mkdirSync(assetsDir, { recursive: true });
if (!fs.existsSync(imagesDir)) fs.mkdirSync(imagesDir, { recursive: true });

const homeDir = os.homedir();
const downloadsDir = path.join(homeDir, 'Downloads');

// Lista explícita de posibles rutas, priorizando logo.jfif (que es donde se descargó la imagen del niño leyendo)
const posiblesArchivos = [
  path.join(downloadsDir, 'logo.jfif'),
  path.join(downloadsDir, 'Logo.jfif'),
  path.join(downloadsDir, 'logo.png'),
  path.join(downloadsDir, 'Logo.png'),
  path.join(downloadsDir, 'logo.jpg'),
  path.join(downloadsDir, 'Logo.jpg'),
  path.join(downloadsDir, 'logo.jpeg'),
  path.join(homeDir, 'Desktop', 'logo.png'),
  path.join(homeDir, 'Desktop', 'logo.jfif'),
  path.join(homeDir, 'Desktop', 'logo.jpg'),
  'C:\\Users\\Dani\\Downloads\\logo.jfif',
  'C:\\Users\\Dani\\Downloads\\logo.png',
  'C:\\Users\\Dani\\Downloads\\logo.jpg'
];

let foundPath = null;
for (const p of posiblesArchivos) {
  if (fs.existsSync(p)) {
    foundPath = p;
    break;
  }
}

// Si no se encontró por nombre exacto, buscar cualquier archivo en Descargas que contenga 'logo' en el nombre
if (!foundPath && fs.existsSync(downloadsDir)) {
  const archivos = fs.readdirSync(downloadsDir);
  const coincidencia = archivos.find(f => f.toLowerCase().includes('logo') && /\.(png|jpg|jpeg|jfif|webp)$/i.test(f));
  if (coincidencia) {
    foundPath = path.join(downloadsDir, coincidencia);
  }
}

if (foundPath) {
  console.log(`✅ ¡Imagen encontrada en: ${foundPath}!`);
  const targetImage = path.join(imagesDir, 'logo.png');
  const targetAsset = path.join(assetsDir, 'logo.png');
  
  fs.copyFileSync(foundPath, targetImage);
  fs.copyFileSync(foundPath, targetAsset);
  
  console.log(`✅ Imagen copiada perfectamente a:`);
  console.log(`   -> ${targetImage}`);
  console.log(`   -> ${targetAsset}`);
} else {
  console.log(`❌ No se encontró ningún archivo logo en Descargas.`);
}
