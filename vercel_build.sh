#!/bin/bash
set -e

echo "=== 🚀 [Vercel Build] Iniciando configuración automática para Flutter Web ==="

# 1. Instalar Flutter SDK en el entorno de build de Vercel si no está presente
if [ ! -d "flutter" ]; then
  echo "📥 Clonando Flutter SDK (rama stable)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter
fi

# 2. Agregar Flutter al PATH temporal de Vercel
export PATH="$PATH:`pwd`/flutter/bin"

echo "=== 🛠️ Versión de Flutter instalada ==="
flutter --version

# 3. Habilitar soporte para Web (por si no estuviera habilitado en el contenedor)
flutter config --enable-web

# 4. Obtener dependencias del proyecto (`flutter pub get`)
echo "=== 📦 Descargando paquetes del proyecto ==="
rm -f pubspec.lock
flutter pub get

# 5. Asegurar que el logo personalizado de la app sea el favicon e icono web
echo "=== 🖼️ Aplicando logo personalizado a favicon e iconos web ==="
if [ -f "assets/images/logo.png" ]; then
  cp -f assets/images/logo.png web/favicon.png
  cp -f assets/images/logo.png web/icons/Icon-192.png
  cp -f assets/images/logo.png web/icons/Icon-512.png
  cp -f assets/images/logo.png web/icons/Icon-maskable-192.png
  cp -f assets/images/logo.png web/icons/Icon-maskable-512.png
  echo "✅ Favicon e iconos actualizados con assets/images/logo.png"
fi

# 6. Compilar la aplicación web para producción (Release Mode)
echo "=== 🏗️ Compilando aplicación Web para Vercel ==="
flutter build web --release

echo "=== ✅ ¡Compilación finalizada con éxito! Archivos generados en build/web ==="
