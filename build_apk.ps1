$ErrorActionPreference = "Stop"

# Configurar variables de entorno de Java JDK (JetBrains Runtime de Android Studio)
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "C:\Program Files\Android\Android Studio\jbr\bin;" + $env:PATH

# Ejecutar compilación
Write-Host "Iniciando compilación del APK en modo Release..."
& "C:\src\flutter\bin\flutter.bat" build apk --release

Write-Host "Proceso de compilación finalizado."
