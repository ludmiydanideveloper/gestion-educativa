#!/bin/bash
set -e

echo "=== 🚀 [Vercel Build] Iniciando configuración automática para Flutter Web ==="

# 1. Instalar Flutter SDK en el entorno de build de Vercel si no está presente
#
# ⚠ VERSIÓN FIJA A PROPÓSITO. Antes decía "-b stable", que clona el stable del
#   momento: cada deploy compilaba con un Flutter distinto y una release nueva
#   podía romper producción sin que nadie tocara una línea de código.
#   Para subir de versión, cambiá el número de acá y probá el deploy.
FLUTTER_VERSION="3.38.10"

if [ ! -d "flutter" ]; then
  echo "📥 Clonando Flutter SDK $FLUTTER_VERSION..."
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 flutter
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
#
# Las credenciales de Supabase se inyectan como variables de entorno del
# proyecto en Vercel (Settings > Environment Variables), no van en el código.
# SUPABASE_ANON_KEY debe ser la clave "anon public", nunca la "service_role".
if [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "❌ Falta la variable de entorno SUPABASE_ANON_KEY."
  echo "   Cargala en Vercel > Settings > Environment Variables con la clave"
  echo "   'anon public' del proyecto Supabase (Settings > API)."
  exit 1
fi

SUPABASE_URL="${SUPABASE_URL:-https://qiwwmlysqidwnywmrwko.supabase.co}"

echo "=== 🏗️ Compilando aplicación Web para Vercel ==="
flutter build web --release   --dart-define=SUPABASE_URL="$SUPABASE_URL"   --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo "=== ✅ ¡Compilación finalizada con éxito! Archivos generados en build/web ==="
