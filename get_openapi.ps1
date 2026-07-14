$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFpd3dtbHlzcWlkd255d21yd2tvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTI5NTc3NiwiZXhwIjoyMDk2ODcxNzc2fQ.q2yxNRrJF-Bgcn2uZ_Eiu8fXqTqsYyZVCL7mA3509w8"
}

try {
    $result = Invoke-RestMethod -Uri "https://qiwwmlysqidwnywmrwko.supabase.co/rest/v1/" -Method Get -Headers $headers
    $result | ConvertTo-Json -Depth 5 | Write-Host
} catch {
    Write-Host "Error:"
    $_
}
