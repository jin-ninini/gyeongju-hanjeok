param(
    [string]$RepoPath = "C:\Users\user\Downloads\gyeongju_hanjeok\backend\gyeongju-hanjeok-deploy"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    throw "Git 저장소를 찾을 수 없습니다: $RepoPath"
}

Write-Host "[1/3] RAG 공식정보 fallback 파일 복사" -ForegroundColor Cyan
Copy-Item (Join-Path $PSScriptRoot "app\clients.py") (Join-Path $RepoPath "app\clients.py") -Force
Copy-Item (Join-Path $PSScriptRoot "app\services.py") (Join-Path $RepoPath "app\services.py") -Force
Copy-Item (Join-Path $PSScriptRoot "tests\test_rag_structured.py") (Join-Path $RepoPath "tests\test_rag_structured.py") -Force
Copy-Item (Join-Path $PSScriptRoot "tests\test_gyeongju_official_client.py") (Join-Path $RepoPath "tests\test_gyeongju_official_client.py") -Force

Write-Host "[2/3] Python 문법 검사" -ForegroundColor Cyan
& (Join-Path $RepoPath ".venv\Scripts\python.exe") -m py_compile `
    (Join-Path $RepoPath "app\clients.py") `
    (Join-Path $RepoPath "app\services.py")

Write-Host "[3/3] RAG 테스트" -ForegroundColor Cyan
Push-Location $RepoPath
try {
    & ".\.venv\Scripts\python.exe" -m pytest tests/test_rag_structured.py tests/test_gyeongju_official_client.py -q
    git status
}
finally {
    Pop-Location
}

Write-Host "적용 완료. 테스트가 통과했다면 git add/commit/push를 진행하세요." -ForegroundColor Green
