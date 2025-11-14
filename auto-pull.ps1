<# 
    auto-pull.ps1
    ----------------
    Uses a GitHub deploy key to clone or update a private repo.

    Multi-user friendly:
      - git and PowerShell 7 installed system-wide
      - Script + key live in /opt/afm-auto-pull (read-only for most users)
      - Each user gets their own clone in $HOME/afm-analysis by default

    Usage examples:
      pwsh /opt/afm-auto-pull/auto-pull.ps1
      pwsh /opt/afm-auto-pull/auto-pull.ps1 -HardReset
      pwsh /opt/afm-auto-pull/auto-pull.ps1 -TargetPath "/some/custom/folder"
#>

param(
    # SSH URL of your repo
    [string]$RepoUrl       = "git@github.com:JuliaMBecker/afm.git",

    # Branch to track
    [string]$Branch        = "main",

    # Local folder where the repo should live (per user)
    # If empty, defaults to $HOME/afm-analysis
    [string]$TargetPath    = "",

    # Path to the *private* deploy key file (shared)
    [string]$PrivateKeyPath = "/opt/afm-auto-pull/id_ed25519_afm_analysis",

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

$user = $env:USER
if (-not $user) {
    $user = $env:USERNAME
}
Write-Host "Starting auto-pull.ps1 for user $user..."
Write-Host ""
Write-Host ""

# -------------------------
# Derive user-specific target if not given
# -------------------------
if ([string]::IsNullOrWhiteSpace($TargetPath)) {
    if (-not $Home) {
        $Home = $env:USERPROFILE  # Windows fallback
    }
    if (-not $Home) {
        Fail "Neither HOME nor USERPROFILE are set. Cannot determine user-specific path."
    }
    $TargetPath = Join-Path $Home "afm-analysis"
}

# -------------------------
# 1) Basic checks
# -------------------------

# Check git presence
try {
    $gitVersion = git --version 2>$null
    if (-not $gitVersion) {
        Fail "git is not available on PATH. Please install git."
    }
} catch {
    Fail "git is not available on PATH. Please install git."
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