$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8"
    "Content-Type" = "application/json"
}

$body = @{
    "query" = "SELECT version();"
} | ConvertTo-Json

$body2 = @{
    "sql" = "SELECT version();"
} | ConvertTo-Json

try {
    Write-Host "Trying POST with query parameter..."
    $result = Invoke-RestMethod -Uri "https://qiwwmlysqidwnywmrwko.supabase.co/admin/v1/query" -Method Post -Headers $headers -Body $body
    Write-Host "Success!"
    $result | ConvertTo-Json
} catch {
    Write-Host "POST query failed:"
    $_
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $bodyResp = $reader.ReadToEnd()
        Write-Host "    Body: $bodyResp"
    }
}

try {
    Write-Host "`nTrying POST with sql parameter..."
    $result = Invoke-RestMethod -Uri "https://qiwwmlysqidwnywmrwko.supabase.co/admin/v1/query" -Method Post -Headers $headers -Body $body2
    Write-Host "Success!"
    $result | ConvertTo-Json
} catch {
    Write-Host "POST sql failed:"
    $_
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $bodyResp = $reader.ReadToEnd()
        Write-Host "    Body: $bodyResp"
    }
}
