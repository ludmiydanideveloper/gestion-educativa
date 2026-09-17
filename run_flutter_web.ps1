# Lanza flutter run -d web-server leyendo SUPABASE_ANON_KEY desde .env,
# para no tener que pegar la clave a mano ni versionarla en .claude/launch.json.

$envPath = Join-Path $PSScriptRoot ".env"
$anonKey = $null

if (Test-Path $envPath) {
    $lines = Get-Content $envPath
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^(?:export\s+)?SUPABASE_ANON_KEY\s*=\s*(.*)$') {
            $anonKey = $matches[1].Trim()
            if ($anonKey.StartsWith('"') -and $anonKey.EndsWith('"')) {
                $anonKey = $anonKey.Substring(1, $anonKey.Length - 2)
            }
            # Por si quedo un placeholder tipo <valor> pegado con los angulares incluidos.
            if ($anonKey.StartsWith('<') -and $anonKey.EndsWith('>')) {
                $anonKey = $anonKey.Substring(1, $anonKey.Length - 2)
            }
        }
    }
}

if (-not $anonKey) {
    # Solo mostramos los NOMBRES de variable presentes en .env (nunca los valores) para diagnosticar.
    $names = @()
    if (Test-Path $envPath) {
        $names = Get-Content $envPath | ForEach-Object {
            if ($_ -match '^\s*(?:export\s+)?([A-Za-z0-9_]+)\s*=') { $matches[1] }
        }
    }
    Write-Error ("No se encontro SUPABASE_ANON_KEY en .env. Variables presentes: " + ($names -join ', '))
    exit 1
}

$defineArg = '--dart-define=SUPABASE_ANON_KEY=' + $anonKey
& "C:\src\fl3810\bin\flutter.bat" run -d web-server --web-port 8080 --web-hostname localhost $defineArg
