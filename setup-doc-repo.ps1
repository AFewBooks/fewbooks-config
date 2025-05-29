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

# Create hooks in .git/hooks: batch files on Windows, symlinks on Linux/macOS
$hooksDir = Join-Path $RepoPath ".git/hooks"

# Ensure .git directory exists and is writable
$gitDir = Join-Path $RepoPath ".git"
if (-not (Test-Path $gitDir)) {
    Write-Host "Creating .git directory at: $gitDir"
    mkdir -Force $gitDir | Out-Null
}

# Clean up any nested .git directories
$nestedGitDir = Join-Path $hooksDir ".git"
if (Test-Path $nestedGitDir) {
    Write-Host "Found nested .git directory, removing it..."
    Remove-Item -Path $nestedGitDir -Recurse -Force
}

# Create .git/hooks directory and verify it's writable
Write-Host "Creating .git/hooks directory at: $hooksDir"
mkdir -Force $hooksDir | Out-Null

# Verify the directory exists and is writable
if (-not (Test-Path $hooksDir)) {
    Write-Error "Failed to create .git/hooks directory at: $hooksDir"
    exit 1
}

# Test if we can write to the directory
$testFile = Join-Path $hooksDir "test.tmp"
try {
    New-Item -ItemType File -Path $testFile -Force | Out-Null
    [System.IO.File]::WriteAllText($testFile, "test")
    Remove-Item $testFile -Force
    Write-Host "Verified .git/hooks directory is writable"
} catch {
    Write-Error "Directory exists but is not writable: $hooksDir"
    exit 1
}

$hookFiles = @("pre-commit", "post-commit")

foreach ($hook in $hookFiles) {
    $targetPath = Join-Path $hooksDir $hook
    $sourcePath = Join-Path $RepoPath ".git-hooks" $hook

    Write-Host "Processing hook: $hook"
    Write-Host "Target path: $targetPath"
    Write-Host "Source path: $sourcePath"

    if ($IsWindows) {
        # Create a shell script that Git can execute directly
        $scriptContent = @"
#!/bin/sh
exec "C:/Program Files/Git/bin/bash.exe" "$sourcePath"
"@
        
        Write-Host "Creating shell script at: $targetPath"
        try {
            # Remove existing file if it exists
            if (Test-Path $targetPath) {
                Remove-Item $targetPath -Force
            }

            # Create the file with proper line endings
            [System.IO.File]::WriteAllText($targetPath, $scriptContent, [System.Text.Encoding]::ASCII)
            
            # Verify the file was created and has content
            if (Test-Path $targetPath) {
                $content = Get-Content $targetPath -Raw
                if ($content.Length -gt 0) {
                    Write-Host "Successfully created shell script for $hook in .git/hooks"
                    Write-Host "File size: $($content.Length) bytes"
                    
                    # Make sure the file is not read-only
                    $file = Get-Item $targetPath
                    if ($file.IsReadOnly) {
                        $file.IsReadOnly = $false
                    }
                    
                    # Set file attributes to ensure it's not hidden
                    $file.Attributes = $file.Attributes -band (-bnot [System.IO.FileAttributes]::Hidden)
                    
                    # Verify file permissions
                    $acl = Get-Acl $targetPath
                    Write-Host "File permissions: $($acl.Access)"
                    
                    # Display file details for debugging
                    Write-Host "File details:"
                    Write-Host "  Full path: $($file.FullName)"
                    Write-Host "  Attributes: $($file.Attributes)"
                    Write-Host "  Creation time: $($file.CreationTime)"
                    Write-Host "  Last write time: $($file.LastWriteTime)"
                    Write-Host "  Length: $($file.Length)"
                } else {
                    Write-Error "File was created but is empty"
                    exit 1
                }
            } else {
                Write-Error "Failed to create shell script at: $targetPath"
                exit 1
            }
        } catch {
            Write-Error "Error creating shell script: $_"
            Write-Host "Parent directory exists: $(Test-Path (Split-Path -Parent $targetPath))"
            Write-Host "Parent directory path: $(Split-Path -Parent $targetPath)"
            Write-Host "Current directory: $(Get-Location)"
            Write-Host "Current user: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
            Write-Host "Directory contents: $(Get-ChildItem $parentDir)"
            exit 1
        }
    } else {
        # Create a symlink for Unix-like systems
        Compare-And-Create-Symlink -TargetPath $targetPath -SourcePath $sourcePath
    }
}

# Final verification of hooks
Write-Host "`nVerifying hook files..."
foreach ($hook in $hookFiles) {
    $hookPath = Join-Path $hooksDir $hook
    if (Test-Path $hookPath) {
        $file = Get-Item $hookPath
        Write-Host "Hook $hook exists at: $hookPath"
        Write-Host "Size: $($file.Length) bytes"
        Write-Host "Last write time: $($file.LastWriteTime)"
        Write-Host "Is read-only: $($file.IsReadOnly)"
        Write-Host "Attributes: $($file.Attributes)"
        
        # Display file contents for debugging
        Write-Host "File contents:"
        Get-Content $hookPath | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Error "Hook file $hook was not created successfully"
        exit 1
    }
}

Write-Host "`nRepository setup complete! Please review the .gitignore file and make any necessary adjustments." 