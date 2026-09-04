$ErrorActionPreference = "Stop"

# Configurar variables de entorno de Java JDK (JetBrains Runtime de Android Studio)
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "C:\Program Files\Android\Android Studio\jbr\bin;" + $env:PATH

# Ejecutar compilación
Write-Host "Iniciando compilación del APK en modo Release..."
# Credenciales de Supabase: se inyectan al compilar, no viven en el codigo.
# SUPABASE_ANON_KEY tiene que ser la clave "anon public" (Settings > API),
# nunca la "service_role".
if (-not $env:SUPABASE_ANON_KEY) {
    Write-Error "Falta la variable de entorno SUPABASE_ANON_KEY con la clave anon public del proyecto Supabase."
}
if (-not $env:SUPABASE_URL) {
    $env:SUPABASE_URL = "https://qiwwmlysqidwnywmrwko.supabase.co"
}

& "C:\src\flutter\bin\flutter.bat" build apk --release `
    --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
    --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY

Write-Host "Proceso de compilación finalizado."
