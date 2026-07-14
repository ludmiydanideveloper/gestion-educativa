$headers = @{
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8"
    "Content-Type" = "application/json"
}

$body = @{
    "query" = "SELECT version();"
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/qiwwmlysqidwnywmrwko/database/query" -Method Post -Headers $headers -Body $body
    Write-Host "Success on api.supabase.com!"
    $result | ConvertTo-Json
} catch {
    Write-Host "Error occurred on api.supabase.com:"
    $_
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response details: $responseBody"
    }
}
