# SCRIPT DE SUBIDA AUTOMATICA A GITHUB PARA DESPLIEGUE EN VERCEL

Write-Host "=== 1. Inicializando repositorio Git ===" -ForegroundColor Cyan
git init

Write-Host "=== 2. Agregando todos los archivos del proyecto al seguimiento ===" -ForegroundColor Cyan
git add .

Write-Host "=== 3. Creando commit con la version actual ===" -ForegroundColor Cyan
git commit -m "SGEducativa: Remove obsolete web-renderer flag for Flutter latest SDK"

Write-Host "=== 4. Configurando la rama principal como main ===" -ForegroundColor Cyan
git branch -M main

Write-Host "=== 5. Conectando al repositorio de GitHub: gestion-educativa ===" -ForegroundColor Cyan
git remote remove origin 2>$null
git remote add origin https://github.com/ludmiydanideveloper/gestion-educativa.git

Write-Host "=== 6. Subiendo codigo a GitHub ===" -ForegroundColor Green
git push -u origin main --force

Write-Host ""
Write-Host "=== SUBIDA COMPLETADA CON EXITO! ===" -ForegroundColor Yellow
Write-Host "Ahora ingresa a https://vercel.com e importa tu repositorio gestion-educativa." -ForegroundColor White
