# ═══════════════════════════════════════════════════════════════════
# أول تفعيل حقيقي بحياة المشروع — آلي بالكامل (لا نسخ يدوي للتوكن)
# يشغل: powershell -ExecutionPolicy Bypass -File tool\first_activation.ps1
# ═══════════════════════════════════════════════════════════════════
$anon = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhka2RnZXRtenRhcHVtY3hmbG9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkyMzI5MDAsImV4cCI6MjEwNDgwODkwMH0.5FUZhGgtIDQrVomevvCfDV3scuIu-xUGGoqGjS0ZISI"
$base = "https://xdkdgetmztapumcxflop.supabase.co"
$code = "P53QN-H80Q0-W4EKQ"

Write-Host "== 1) takhdh token majhool..." -ForegroundColor Cyan
try {
    $r = Invoke-RestMethod -Uri "$base/auth/v1/signup" -Method Post `
        -ContentType "application/json" -Headers @{ apikey = $anon } `
        -Body '{"email":"","password":""}'
} catch {
    Write-Host "FAIL signup:" $_.ErrorDetails.Message -ForegroundColor Red
    exit 1
}
$t = $r.access_token
if (-not $t) { Write-Host "FAIL: no access_token" -ForegroundColor Red; exit 1 }
Write-Host "   token OK" -ForegroundColor Green

Write-Host "== 2) taf'il al-code $code ..." -ForegroundColor Cyan
try {
    $resp = Invoke-RestMethod -Uri "$base/functions/v1/license_activate" `
        -Method Post -ContentType "application/json" `
        -Headers @{ Authorization = "Bearer $t" } `
        -Body '{"code":"P53QN-H80Q0-W4EKQ","device_pubkey_b64":"AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA=","device_fp":"smoketest12345"}'
} catch {
    Write-Host "FAIL activate:" $_.ErrorDetails.Message -ForegroundColor Red
    exit 1
}

Write-Host "══════════ الرد الكامل — الصقه في الشات ══════════" -ForegroundColor Green
$resp | ConvertTo-Json -Depth 5
