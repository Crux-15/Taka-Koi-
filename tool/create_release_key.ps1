# Creates the Android release signing key and android/key.properties.
#
#   powershell -ExecutionPolicy Bypass -File tool\create_release_key.ps1
#
# You type the password here. It is never shown on screen, and only stored in
# android/key.properties (git-ignored) so release builds can sign the app.
# Also saves the key's SHA-1/SHA-256 fingerprints (not secret) for Firebase.
$ErrorActionPreference = 'Stop'

$project      = Split-Path -Parent $PSScriptRoot
$keystore     = Join-Path $env:USERPROFILE 'taka-koi-release.jks'
$props        = Join-Path $project 'android\key.properties'
$fingerprints = Join-Path $env:USERPROFILE 'taka-koi-release-fingerprints.txt'

$candidates = @()
if ($env:JAVA_HOME) { $candidates += (Join-Path $env:JAVA_HOME 'bin\keytool.exe') }
$found = Get-Command keytool.exe -ErrorAction SilentlyContinue
if ($found) { $candidates += $found.Source }
$candidates += Get-ChildItem 'C:\Program Files\Java\*\bin\keytool.exe' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
$candidates += 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
$keytool = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $keytool) { throw 'keytool was not found. Install a JDK (Java) first.' }

if (Test-Path $keystore) {
  Write-Host "A signing key already exists at $keystore. Not replacing it." -ForegroundColor Yellow
  exit 1
}

function Read-Secret([string]$prompt) {
  $secure = Read-Host $prompt -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

# Java .properties escaping, so any character in the password survives.
function ConvertTo-PropertyValue([string]$value) {
  $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt $value.Length; $i++) {
    $c = $value[$i]
    $code = [int]$c
    if ($c -eq [char]'\') { [void]$sb.Append('\\') }
    elseif ($code -lt 32 -or $code -gt 126) { [void]$sb.Append(('\u{0:x4}' -f $code)) }
    elseif ($i -eq 0 -and $c -eq [char]' ') { [void]$sb.Append('\ ') }
    else { [void]$sb.Append($c) }
  }
  return $sb.ToString()
}

Write-Host ''
Write-Host 'Taka Koi: create the app signing key' -ForegroundColor Cyan
Write-Host 'Choose a password (at least 8 characters). Nothing shows while you type.'
Write-Host 'Write it down somewhere safe: every future app update needs it.'
Write-Host ''
while ($true) {
  $first = Read-Secret 'Password'
  if ($first.Length -lt 8) { Write-Host 'Too short: use at least 8 characters.' -ForegroundColor Yellow; continue }
  $second = Read-Secret 'Type it again'
  if ($first -ceq $second) { break }
  Write-Host 'The two passwords are different. Try again.' -ForegroundColor Yellow
}

$env:TAKA_KOI_KEY_PASS = $first
try {
  & $keytool -genkeypair -keystore $keystore -storetype PKCS12 -alias upload -keyalg RSA -keysize 2048 `
    -validity 10000 -dname 'CN=Taka Koi, O=Taka Koi, C=BD' `
    -storepass:env TAKA_KOI_KEY_PASS -keypass:env TAKA_KOI_KEY_PASS
  if ($LASTEXITCODE -ne 0) { throw 'keytool could not create the key.' }

  $escaped = ConvertTo-PropertyValue $first
  $lines = @(
    '# Release signing key (made by tool/create_release_key.ps1). Never commit or share this file.',
    "storePassword=$escaped",
    "keyPassword=$escaped",
    'keyAlias=upload',
    ('storeFile=' + $keystore.Replace('\', '/'))
  )
  Set-Content -Path $props -Value $lines -Encoding ASCII

  $list = & $keytool -list -v -keystore $keystore -alias upload -storepass:env TAKA_KOI_KEY_PASS
  if ($LASTEXITCODE -ne 0) { throw 'keytool could not read the new key.' }
  $list | Select-String -Pattern '^\s*SHA(1|256):' | ForEach-Object { $_.Line.Trim() } |
    Set-Content -Path $fingerprints -Encoding ASCII
}
finally {
  Remove-Item Env:TAKA_KOI_KEY_PASS -ErrorAction SilentlyContinue
  $first = $null; $second = $null
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Host "  Signing key:  $keystore"
Write-Host "  Settings:     $props"
Write-Host ''
Write-Host 'Back up the key file and your password (for example to Google Drive).' -ForegroundColor Yellow
Write-Host 'Without them you can never publish an update to the app again.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'You can close this tab now and tell Claude it is done.'
