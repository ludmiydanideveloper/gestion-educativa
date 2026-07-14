$ErrorActionPreference = "Stop"

# 1. Modificar android/gradle/wrapper/gradle-wrapper.properties
$wrapperPath = "android/gradle/wrapper/gradle-wrapper.properties"
Write-Host "Actualizando gradle-wrapper.properties..."
$wrapperContent = Get-Content $wrapperPath -Raw
$wrapperContent = $wrapperContent -replace 'distributionUrl=.*', 'distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-all.zip'
Set-Content $wrapperPath $wrapperContent
Write-Host "gradle-wrapper.properties actualizado."

# 2. Modificar android/settings.gradle para actualizar AGP (com.android.application) a 8.3.2 y Kotlin a 1.9.22
$settingsPath = "android/settings.gradle"
Write-Host "Actualizando settings.gradle..."
$settingsContent = Get-Content $settingsPath -Raw
$settingsContent = $settingsContent -replace 'id "com\.android\.application" version ".*?"', 'id "com.android.application" version "8.3.2" apply false'
$settingsContent = $settingsContent -replace 'id "org\.jetbrains\.kotlin\.android" version ".*?"', 'id "org.jetbrains.kotlin.android" version "1.9.22" apply false'
Set-Content $settingsPath $settingsContent
Write-Host "settings.gradle actualizado."

# 3. Modificar android/app/build.gradle para fijar compileSdk a 34
$appGradlePath = "android/app/build.gradle"
Write-Host "Actualizando android/app/build.gradle..."
$appGradleContent = Get-Content $appGradlePath -Raw
$appGradleContent = $appGradleContent -replace 'compileSdk = flutter\.compileSdkVersion', 'compileSdk = 34'
Set-Content $appGradlePath $appGradleContent
Write-Host "android/app/build.gradle actualizado."
