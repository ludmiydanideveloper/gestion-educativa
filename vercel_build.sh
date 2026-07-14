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

# 5. Compilar la aplicación web para producción (Release Mode)
echo "=== 🏗️ Compilando aplicación Web para Vercel ==="
flutter build web --release --web-renderer canvaskit

echo "=== ✅ ¡Compilación finalizada con éxito! Archivos generados en build/web ==="
