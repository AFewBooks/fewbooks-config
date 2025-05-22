# Script to set up a new document repository with Git hooks for Word document versioning
param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$InitializeGit = $true
)

# Function to compare files and handle overwrite decisions
function Compare-And-Copy-File {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )
    
    if (Test-Path $DestinationPath) {
        Write-Host "`nFile already exists: $DestinationPath"
        $sourceContent = Get-Content $SourcePath -Raw
        $destContent = Get-Content $DestinationPath -Raw
        
        if ($sourceContent -eq $destContent) {
            Write-Host "Files are identical. Skipping..."
            return
        }
        
        Write-Host "`nDifferences found:"
        Write-Host "----------------"
        $diff = Compare-Object -ReferenceObject ($sourceContent -split "`n") -DifferenceObject ($destContent -split "`n")
        $diff | ForEach-Object {
            if ($_.SideIndicator -eq "<=") {
                Write-Host ("+ " + $_.InputObject) -ForegroundColor Green
            } else {
                Write-Host ("- " + $_.InputObject) -ForegroundColor Red
            }
        }
        Write-Host "----------------"
        
        $response = Read-Host "Do you want to overwrite this file? (y/n)"
        if ($response -eq "y") {
            Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
            Write-Host "File overwritten: $DestinationPath"
        } else {
            Write-Host "Skipping file: $DestinationPath"
        }
    } else {
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        Write-Host "Copied new file: $DestinationPath"
    }
}

# Function to compare symbolic links and handle creation decisions
function Compare-And-Create-Symlink {
    param(
        [string]$TargetPath,
        [string]$SourcePath
    )
    
    if (Test-Path $TargetPath) {
        Write-Host "`nSymbolic link already exists: $TargetPath"
        
        # Get the current target of the symbolic link
        $currentTarget = (Get-Item $TargetPath).Target
        
        # Get the directory of the target path to resolve relative paths correctly
        $targetDir = Split-Path -Parent $TargetPath
        $newTarget = Join-Path $targetDir $SourcePath
        
        if ($currentTarget -eq $SourcePath) {
            Write-Host "Symbolic link already points to the correct location. Skipping..."
            return
        }
        
        Write-Host "`nCurrent symbolic link target: $currentTarget"
        Write-Host "New symbolic link target: $SourcePath"
        
        $response = Read-Host "Do you want to update this symbolic link? (y/n)"
        if ($response -eq "y") {
            Remove-Item $TargetPath -Force
            New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourcePath | Out-Null
            Write-Host "Symbolic link updated: $TargetPath"
        } else {
            Write-Host "Skipping symbolic link update: $TargetPath"
        }
    } else {
        New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourcePath | Out-Null
        Write-Host "Created new symbolic link: $TargetPath"
    }
}

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
        $destPath = Join-Path $RepoPath $file
        Compare-And-Copy-File -SourcePath $sourcePath -DestinationPath $destPath
    } else {
        Write-Error "Could not find $file in $scriptDir"
        exit 1
    }
}

# Handle .gitignore-template to .gitignore conversion
$gitignoreTemplatePath = Join-Path $scriptDir ".gitignore-template"
$gitignorePath = Join-Path $RepoPath ".gitignore"
if (Test-Path $gitignoreTemplatePath) {
    Compare-And-Copy-File -SourcePath $gitignoreTemplatePath -DestinationPath $gitignorePath
} else {
    Write-Error "Could not find .gitignore-template"
    exit 1
}

# Copy .git-hooks directory
$hooksSourcePath = Join-Path $scriptDir ".git-hooks"
if (Test-Path $hooksSourcePath) {
    # Create .git-hooks directory if it doesn't exist
    $hooksDestPath = Join-Path $RepoPath ".git-hooks"
    if (-not (Test-Path $hooksDestPath)) {
        New-Item -ItemType Directory -Path $hooksDestPath | Out-Null
    }
    
    # Copy each hook file individually
    Get-ChildItem $hooksSourcePath -File | ForEach-Object {
        $hookDestPath = Join-Path $hooksDestPath $_.Name
        Compare-And-Copy-File -SourcePath $_.FullName -DestinationPath $hookDestPath
    }
    Write-Host "Processed .git-hooks directory"
} else {
    Write-Error "Could not find .git-hooks directory in $scriptDir"
    exit 1
}

# Create symbolic links in .git/hooks
$hooksDir = Join-Path $RepoPath ".git/hooks"
$hookFiles = @("pre-commit", "post-commit")

foreach ($hook in $hookFiles) {
    $targetPath = Join-Path $hooksDir $hook
    $sourcePath = Join-Path ".." ".git-hooks" $hook
    
    Compare-And-Create-Symlink -TargetPath $targetPath -SourcePath $sourcePath
}

Write-Host "`nRepository setup complete! Please review the .gitignore file and make any necessary adjustments." 