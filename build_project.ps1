$ErrorActionPreference = "Stop"

# Ruta absoluta al ejecutable de Flutter
$flutterPath = "C:\src\flutter\bin\flutter.bat"

Write-Host "--- 1. Copiando lib/main.dart a un respaldo temporal ---"
if (Test-Path "lib/main.dart") {
    Copy-Item "lib/main.dart" "main_backup.dart" -Force
    Write-Host "Respaldo temporal creado con éxito."
} else {
    Write-Error "No se encontró lib/main.dart para respaldar."
}

Write-Host "--- 2. Inicializando el proyecto Flutter para plataforma Android ---"
& $flutterPath create . --platforms android --project-name gestion_escolar

Write-Host "--- 3. Restaurando lib/main.dart original ---"
if (Test-Path "main_backup.dart") {
    Copy-Item "main_backup.dart" "lib/main.dart" -Force
    Remove-Item "main_backup.dart" -Force
    Write-Host "Archivo lib/main.dart restaurado y respaldo temporal eliminado."
} else {
    Write-Error "No se encontró el respaldo temporal para restaurar."
}

Write-Host "--- 4. Agregando dependencias (supabase_flutter, google_fonts, intl) ---"
& $flutterPath pub add supabase_flutter google_fonts intl

Write-Host "--- 5. Compilando APK Release ---"
& $flutterPath build apk --release

Write-Host "--- Proceso completado con éxito ---"
