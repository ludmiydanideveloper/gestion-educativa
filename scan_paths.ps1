$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8"
    "Content-Type" = "application/json"
}

$paths = @(
    "pg",
    "pg/",
    "pg/tables",
    "pg/query",
    "pg-meta",
    "pg-meta/tables",
    "pg-meta/query",
    "admin",
    "admin/v1",
    "admin/v1/query",
    "db",
    "db/query",
    "postgres",
    "postgres/query"
)

foreach ($path in $paths) {
    $uri = "https://qiwwmlysqidwnywmrwko.supabase.co/$path"
    try {
        $resp = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -TimeoutSec 5
        Write-Host "GET $path : Status $($resp.StatusCode)"
    } catch {
        Write-Host "GET $path : Error $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $body = $reader.ReadToEnd()
            Write-Host "    Body: $body"
        }
    }
}
