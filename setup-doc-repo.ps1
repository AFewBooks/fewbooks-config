# Script to set up a new document repository with Git hooks for Word document versioning
param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$InitializeGit = $true
)

# Self-elevate the script if required
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting administrator privileges..."
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -RepoPath `"$RepoPath`" -InitializeGit:`$($InitializeGit.IsPresent)" -Verb RunAs
    exit
}

# Check if pandoc is installed and working
try {
    $pandocVersion = & pandoc -v 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Pandoc command failed"
    }
} catch {
    Write-Error "Pandoc is not installed or not working properly. Please install it from http://pandoc.org/"
    exit 1
}

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Create directory if it doesn't exist
if (-not (Test-Path $RepoPath)) {
    New-Item -ItemType Directory -Path $RepoPath | Out-Null
    Write-Host "Created directory: $RepoPath"
}

# Change to the repository directory
Set-Location $RepoPath

# Initialize git repository if requested
if ($InitializeGit) {
    git init
    Write-Host "Initialized git repository"
}

# Copy required files
$configFiles = @(
    ".gitattributes",
    ".gitconfig",
    ".gitignore-template"
)

foreach ($file in $configFiles) {
    $sourcePath = Join-Path $scriptDir $file
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination "." -Force
        Write-Host "Copied $file"
    } else {
        Write-Error "Could not find $file in $scriptDir"
        exit 1
    }
}

# Rename .gitignore-template to .gitignore
if (Test-Path ".gitignore-template") {
    Rename-Item -Path ".gitignore-template" -NewName ".gitignore" -Force
    Write-Host "Renamed .gitignore-template to .gitignore"
} else {
    Write-Error "Could not find .gitignore-template"
    exit 1
}

# Copy .git-hooks directory
$hooksSourcePath = Join-Path $scriptDir ".git-hooks"
if (Test-Path $hooksSourcePath) {
    Copy-Item -Path $hooksSourcePath -Destination "." -Recurse -Force
    Write-Host "Copied .git-hooks directory"
} else {
    Write-Error "Could not find .git-hooks directory in $scriptDir"
    exit 1
}

# Create symbolic links in .git/hooks
$hooksDir = ".git/hooks"
$hookFiles = @("pre-commit", "post-commit")

foreach ($hook in $hookFiles) {
    $targetPath = Join-Path $hooksDir $hook
    $sourcePath = Join-Path ".." ".git-hooks" $hook
    
    # Remove existing link/file if it exists
    if (Test-Path $targetPath) {
        Remove-Item $targetPath -Force
    }
    
    # Create symbolic link
    New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath | Out-Null
    Write-Host "Created symbolic link for $hook"
}

Write-Host "`nRepository setup complete! Please review the .gitignore file and make any necessary adjustments." 