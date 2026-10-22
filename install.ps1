# Installs svc1c dependencies into .\oscript_modules and patches irac.
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1 [-OneScriptHome "C:\Program Files\OneScript"]
param(
    [string]$OneScriptHome = "C:\Program Files\OneScript"
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$oscript = Join-Path $OneScriptHome "bin\oscript.exe"
$opm     = Join-Path $OneScriptHome "bin\opm.bat"
if (-not (Test-Path $oscript)) { throw "OneScript not found: $oscript (install OneScript 2.x or pass -OneScriptHome)" }
# opm.bat calls "oscript" from PATH
$env:PATH = (Join-Path $OneScriptHome "bin") + ";" + $env:PATH

Write-Host "== OneScript: $(& $oscript -version)"
Write-Host "== opm install -l (packagedef)"
& $opm install -l
if ($LASTEXITCODE -ne 0) { throw "opm install failed: $LASTEXITCODE" }

# irac 1.4.0 + 1commands 1.5.0 on OneScript 2.x: trailing empty line in rac output
# becomes an empty record. See etc\irac-1.4.0-empty-record.patch.
$file = Join-Path $PSScriptRoot "oscript_modules\irac\src\Модули\Служебный.os"
$old  = "Если й = 1 Тогда"
$new  = "Если й = 1 ИЛИ НЕ ЗначениеЗаполнено(Описание) Тогда"
$bytes  = [IO.File]::ReadAllBytes($file)
$hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
$text   = [IO.File]::ReadAllText($file)
if ($text.Contains($new)) {
    Write-Host "== irac patch: already applied"
} elseif ($text.Contains($old)) {
    [IO.File]::WriteAllText($file, $text.Replace($old, $new), (New-Object Text.UTF8Encoding($hasBom)))
    Write-Host "== irac patch: applied"
} else {
    throw "irac patch: pattern not found in $file (irac version changed? check the patch)"
}

Write-Host "== syntax check"
& $oscript -check svc1c.os
if ($LASTEXITCODE -ne 0) { throw "oscript -check failed" }
Write-Host "== done"
