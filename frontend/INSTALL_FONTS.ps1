$ErrorActionPreference = "Stop"
$frontend = Split-Path -Parent $MyInvocation.MyCommand.Path
$fontDir = Join-Path $frontend "assets\fonts"
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
$downloads = Join-Path $env:USERPROFILE "Downloads"
$wantedZip = Get-ChildItem $downloads -Filter "WantedSans-1.0.3.zip" -File -Recurse | Select-Object -First 1
$odaesan = Get-ChildItem $downloads -Filter "KNPSOdaesan*.otf" -File -Recurse | Select-Object -First 1
if (-not $wantedZip) { throw "WantedSans-1.0.3.zip을 Downloads에서 찾지 못했습니다." }
if (-not $odaesan) { throw "KNPSOdaesan.otf를 Downloads에서 찾지 못했습니다." }
$temp = Join-Path $env:TEMP "gyeongju_hanjeok_wanted_font"
Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -Path $wantedZip.FullName -DestinationPath $temp -Force
foreach ($name in @("Regular","Medium","SemiBold","Bold")) {
  Copy-Item (Join-Path $temp "ttf\WantedSans-$name.ttf") (Join-Path $fontDir "WantedSans-$name.ttf") -Force
}
Copy-Item $odaesan.FullName (Join-Path $fontDir "KNPSOdaesan.otf") -Force
Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "폰트 설치 완료: $fontDir"
