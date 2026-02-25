# ============================================================
#  link-and-deploy.ps1
#  Links C:\Users\Sithu\Documents\fasscript\pnlview to
#  https://github.com/cctestiomio/pnlview and deploys to Vercel
# ============================================================

$ErrorActionPreference = "Stop"
$ProjectDir = "C:\Users\Sithu\Documents\fasscript\pnlview"

function Write-Step($msg) { Write-Host "" ; Write-Host $msg -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "  XX  $msg" -ForegroundColor Red; Read-Host "Press Enter to exit"; exit 1 }

Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Link folder -> GitHub -> Vercel" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray

# ── PREFLIGHT ────────────────────────────────────────────────────
Write-Step "1/4  Checking folder and tools..."

if (-not (Test-Path $ProjectDir)) { Write-Fail "Folder not found: $ProjectDir" }
Write-OK "Folder exists"

foreach ($cmd in @("git","vercel")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Fail "'$cmd' not found. Install from script header instructions."
    }
    Write-OK "$cmd found"
}

# ── GIT SETUP ────────────────────────────────────────────────────
Write-Step "2/4  Linking folder to GitHub repo..."

Push-Location $ProjectDir
try {
    # Init if not already a git repo
    if (-not (Test-Path (Join-Path $ProjectDir ".git"))) {
        git init -b main 2>&1 | Out-Null
        Write-OK "Git repo initialised"
    } else {
        Write-OK "Git repo already initialised"
    }

    # Set/overwrite remote origin
    $remoteExists = git remote 2>&1 | Select-String "origin"
    if ($remoteExists) {
        git remote set-url origin https://github.com/cctestiomio/pnlview.git
        Write-OK "Remote origin updated"
    } else {
        git remote add origin https://github.com/cctestiomio/pnlview.git
        Write-OK "Remote origin added"
    }

    # Write vercel.json if missing
    $vercelJsonPath = Join-Path $ProjectDir "vercel.json"
    if (-not (Test-Path $vercelJsonPath)) {
        $vj = '{"version":2,"builds":[{"src":"index.html","use":"@vercel/static"}],"routes":[{"src":"/(.*)","dest":"/index.html"}]}'
        [System.IO.File]::WriteAllText($vercelJsonPath, $vj)
        Write-OK "Created vercel.json"
    } else {
        Write-OK "vercel.json already exists"
    }

    # Write .gitignore if missing
    $giPath = Join-Path $ProjectDir ".gitignore"
    if (-not (Test-Path $giPath)) {
        [System.IO.File]::WriteAllText($giPath, ".vercel`n*.csv`n")
        Write-OK "Created .gitignore"
    }

    # Stage, commit, push
    git add . 2>&1 | Out-Null

    $status = git status --porcelain 2>&1
    if ($status) {
        git commit -m "Deploy: Polymarket PnL Dashboard" 2>&1 | Out-Null
        Write-OK "Changes committed"
    } else {
        Write-OK "Nothing new to commit"
    }

    Write-Host "  Pushing to https://github.com/cctestiomio/pnlview ..." -ForegroundColor DarkGray
    git push -u origin main --force 2>&1
    if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "Git push failed. Make sure you have write access to cctestiomio/pnlview and are authenticated (run: gh auth login)" }
    Write-OK "Pushed to GitHub"

} finally {
    Pop-Location
}

# ── VERCEL DEPLOY ────────────────────────────────────────────────
Write-Step "3/4  Deploying to Vercel..."

Push-Location $ProjectDir
try {
    # Check Vercel login
    $whoami = vercel whoami 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Not logged in to Vercel. Opening login..."
        vercel login
        if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Fail "Vercel login failed." }
        $whoami = vercel whoami 2>&1
    }
    Write-OK "Vercel authenticated as: $whoami"

    # Link to Vercel project (--yes accepts defaults: use cctestiomio scope, repo name as project name)
    Write-Host "  Linking project to Vercel..." -ForegroundColor DarkGray
    vercel --yes 2>&1 | Out-Null

    Write-Host "  Deploying to production..." -ForegroundColor DarkGray
    $prodOut = vercel --prod --yes 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host ($prodOut | Out-String)
        Pop-Location
        Write-Fail "Vercel production deploy failed."
    }

    # Extract URL
    $prodUrl = ""
    $prodOut | ForEach-Object {
        if ($_ -match "(https://[^\s]+\.vercel\.app[^\s]*)") { $prodUrl = $matches[1] }
    }

} finally {
    Pop-Location
}

# ── DONE ─────────────────────────────────────────────────────────
Write-Step "4/4  Done!"
Write-Host ""
Write-Host "  GitHub  : https://github.com/cctestiomio/pnlview" -ForegroundColor White
if ($prodUrl) {
    Write-Host "  Vercel  : $prodUrl" -ForegroundColor White
} else {
    Write-Host "  Vercel  : run 'vercel ls' to find your URL" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  To push future updates:" -ForegroundColor DarkGray
Write-Host "    cd `"$ProjectDir`"" -ForegroundColor DarkGray
Write-Host "    git add . ; git commit -m `"update`" ; git push" -ForegroundColor DarkGray
Write-Host ""
Read-Host "Press Enter to close"