# Export the web build and publish it to the gh-pages branch (GitHub Pages).
#
# Usage (from the project folder):
#   powershell -File tools\deploy_web.ps1 -Godot "C:\path\to\Godot_v4.x_console.exe"
#
# -Godot defaults to "godot" on PATH. The gh-pages branch is force-pushed as a
# single commit every time, so the large engine file does not pile up in history.

param(
    [string]$Godot = "godot",
    [string]$Preset = "Web",
    [string]$Branch = "gh-pages"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root "build\web"

Write-Host "Exporting '$Preset' to $out ..."
New-Item -ItemType Directory -Force $out | Out-Null
$gdignore = Join-Path $root "build\.gdignore"
if (-not (Test-Path $gdignore)) { New-Item -ItemType File $gdignore | Out-Null }
& $Godot --headless --path $root --export-release $Preset (Join-Path $out "index.html") | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Godot export failed (exit code $LASTEXITCODE)." }
if (-not (Test-Path (Join-Path $out "index.wasm"))) { throw "Export produced no index.wasm." }

$remote = git -C $root remote get-url origin
if (-not $remote) { throw "No 'origin' remote configured." }
$name = git -C $root config user.name
$email = git -C $root config user.email
$revision = git -C $root rev-parse --short HEAD

# Use the GitHub CLI token for the push when gh is installed, without touching git config.
# The empty first value clears any other credential helper for this one command.
$auth = @()
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $auth = @("-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential")
}

$staging = Join-Path ([IO.Path]::GetTempPath()) ("pages-" + [guid]::NewGuid().ToString("N"))
Copy-Item $out $staging -Recurse
try {
    # .nojekyll: serve the files as-is instead of running them through Jekyll.
    New-Item -ItemType File (Join-Path $staging ".nojekyll") | Out-Null
    git -C $staging init -q -b $Branch
    git -C $staging add -A
    git -C $staging -c "user.name=$name" -c "user.email=$email" commit -q -m "Deploy $revision"
    Write-Host "Pushing to $Branch ..."
    git -C $staging @auth push -q -f $remote "${Branch}:${Branch}"
    if ($LASTEXITCODE -ne 0) { throw "Push to $Branch failed." }
}
finally {
    Remove-Item $staging -Recurse -Force
}
Write-Host "Deployed $revision to $Branch."
