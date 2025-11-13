<# 
    auto-pull.ps1
    ----------------
    Uses a GitHub deploy key to clone or update a private repo.

    Requirements:
      - PowerShell 7+
      - git installed and in PATH
      - OpenSSH client available (Windows 10+ usually has this)
      - Deploy key private file on disk

    Usage examples:
      pwsh .\auto-pull.ps1
      pwsh .\auto-pull.ps1 -HardReset
#>

param(
    # SSH URL of your repo
    [string]$RepoUrl       = "git@github.com:nik-liegroup/pytraction_backup.git",

    # Branch to track
    [string]$Branch        = "main",

    # Local folder where the repo should live
    # Windows: [string]$TargetPath    = "C:\Users\ngampl\Desktop\RepoTest",
    # Ubuntu:  [string]$TargetPath    = "/home/user/Documents/git/afm-analysis",
    [string]$TargetPath    = "C:\Users\ngampl\Desktop\RepoTest",

    # Path to the *private* deploy key file
    # Windows: [string]$PrivateKeyPath = "C:\Users\ngampl\.ssh\id_ed25519_afm_analysis",
    # Ubuntu:  [string]$PrivateKeyPath = "/home/user/.ssh/git/id_ed25519_afm_analysis",
    [string]$PrivateKeyPath = "C:\Users\ngampl\.ssh\id_ed25519_afm_analysis",

    # If set, use 'git reset --hard origin/<branch>' instead of a fast-forward merge
    [switch]$HardReset
)

# -------------------------
# Helper: simple error exit
# -------------------------
function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}

Write-Host "Starting auto-pull.ps1..."
Write-Host ""

# -------------------------
# 1) Basic checks
# -------------------------

# Check git presence
try {
    $gitVersion = git --version 2>$null
    if (-not $gitVersion) {
        Fail "git is not available on PATH. Install Git for Windows first."
    }
} catch {
    Fail "git is not available on PATH. Install Git for Windows first."
}

# Check key file
if (-not (Test-Path -LiteralPath $PrivateKeyPath)) {
    Fail "Private key not found at '$PrivateKeyPath'. Update the script or create the key first."
}

# Normalise TargetPath
$TargetPath = [System.IO.Path]::GetFullPath($TargetPath)

# Ensure target directory exists
if (-not (Test-Path -LiteralPath $TargetPath)) {
    Write-Host "Creating target directory: $TargetPath"
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
}

# Does this look like a git repo?
$gitDir = Join-Path $TargetPath ".git"
$IsRepo = Test-Path -LiteralPath $gitDir

# Build SSH command that git should use
$sshCommand = "ssh -i `"$PrivateKeyPath`" -o IdentitiesOnly=yes"

Write-Host "=============================================="
Write-Host " Repo   : $RepoUrl"
Write-Host " Target : $TargetPath"
Write-Host " Branch : $Branch"
Write-Host " SSH key: $PrivateKeyPath"
Write-Host "=============================================="
Write-Host ""

# -------------------------
# 2) Clone if needed
# -------------------------
if (-not $IsRepo) {
    Write-Host "[STEP] No .git folder found. Cloning repository..."

    $cloneArgs = @(
        "-c", "core.sshCommand=$sshCommand",
        "clone",
        "--branch", $Branch,
        "--single-branch",
        $RepoUrl,
        $TargetPath
    )

    $clone = & git @cloneArgs
    if ($LASTEXITCODE -ne 0) {
        Fail "git clone failed. Output:`n$clone"
    }

    Write-Host "[OK] Clone complete."
} else {
    # -------------------------
    # 3) Update existing repo
    # -------------------------
    Write-Host "[STEP] Updating existing repository..."

    # Ensure we are on the correct branch locally
    $checkoutArgs = @(
        "-c", "core.sshCommand=$sshCommand",
        "-C", $TargetPath,
        "checkout", $Branch
    )

    $checkout = & git @checkoutArgs
    if ($LASTEXITCODE -ne 0) {
        Fail "git checkout $Branch failed. Output:`n$checkout"
    }

    # Fetch latest
    $fetchArgs = @(
        "-c", "core.sshCommand=$sshCommand",
        "-C", $TargetPath,
        "fetch", "origin", $Branch
    )

    $fetch = & git @fetchArgs
    if ($LASTEXITCODE -ne 0) {
        Fail "git fetch failed. Output:`n$fetch"
    }

    if ($HardReset) {
        Write-Host "[STEP] Hard resetting to origin/$Branch ..."
        $resetArgs = @(
            "-c", "core.sshCommand=$sshCommand",
            "-C", $TargetPath,
            "reset", "--hard", "origin/$Branch"
        )

        $reset = & git @resetArgs
        if ($LASTEXITCODE -ne 0) {
            Fail "git reset --hard origin/$Branch failed. Output:`n$reset"
        }
        Write-Host "[OK] Repository hard-reset to remote."
    } else {
        Write-Host "[STEP] Fast-forward merging origin/$Branch ..."
        $mergeArgs = @(
            "-c", "core.sshCommand=$sshCommand",
            "-C", $TargetPath,
            "merge", "--ff-only", "origin/$Branch"
        )

        $merge = & git @mergeArgs
        if ($LASTEXITCODE -ne 0) {
            Fail "Fast-forward merge failed (maybe local changes?). Output:`n$merge"
        }
        Write-Host "[OK] Repository is up to date (fast-forward)."
    }
}

Write-Host ""
Write-Host "Done."