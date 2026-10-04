param(
    [string]$Dart = 'dart',
    [string]$Boltffi = '',
    [switch]$Serve,
    [int]$Port = 8765
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../libs/boltffi')).Path

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed ($LASTEXITCODE)" }
}

Push-Location $PSScriptRoot
try {
    if (!$Boltffi) {
        Invoke-Checked 'cargo' @('build', '--manifest-path', "$repoRoot/Cargo.toml", '-p', 'boltffi_cli')
        $Boltffi = Join-Path $repoRoot 'target/debug/boltffi.exe'
    }
    Push-Location (Join-Path $repoRoot 'runtime/typescript')
    try {
        Invoke-Checked 'npm' @('ci')
        Invoke-Checked 'npm' @('run', 'build')
    } finally { Pop-Location }
    Invoke-Checked 'rustup' @('target', 'add', 'wasm32-unknown-unknown')
    Invoke-Checked 'npm' @('ci')
    Invoke-Checked $Boltffi @('pack', 'dart-web', '--experimental', '--deny-skipped')
    Invoke-Checked $Dart @('pub', 'get')
    Invoke-Checked $Dart @('analyze', 'web/main.dart')
    Invoke-Checked $Dart @('compile', 'js', 'web/main.dart', '-O2', '-o', 'web/main.dart.js')
    Invoke-Checked $Dart @('compile', 'wasm', 'web/main.dart', '-o', 'web/main.dart.wasm')
    if ($Serve) {
        Write-Host "Playground: http://localhost:$Port/"
        Invoke-Checked 'node' @('serve.mjs', "$Port")
    }
} finally { Pop-Location }
