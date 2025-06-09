# Simple UniAnimate-DiT RunPod Template Build Script
# PowerShell script to build simplified template

Write-Host "Building Simple UniAnimate-DiT RunPod Template..." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Set variables
$templateName = "unianimate-dit-simple"
$dockerFile = "Dockerfile.unianimate_simple"
$imageTag = "${templateName}:latest"

Write-Host "Template Name: $templateName" -ForegroundColor Yellow
Write-Host "Docker File: $dockerFile" -ForegroundColor Yellow
Write-Host "Image Tag: $imageTag" -ForegroundColor Yellow
Write-Host ""

# Check if required files exist
$requiredFiles = @(
    "unianimate_install_simple.sh",
    "start_services_unianimate_simple.sh", 
    "Dockerfile.unianimate_simple",
    "installation_logger.sh",
    "file_manager.py",
    "templates"
)

Write-Host "Checking required files..." -ForegroundColor Cyan
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file" -ForegroundColor Green
    } else {
        Write-Host "❌ $file (MISSING)" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Building Docker image..." -ForegroundColor Cyan
Write-Host "Command: docker build -f $dockerFile -t $imageTag ." -ForegroundColor Gray

# Build the Docker image
try {
    docker build -f $dockerFile -t $imageTag .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Build completed successfully!" -ForegroundColor Green
        Write-Host "================================================" -ForegroundColor Green
        Write-Host "Image: $imageTag" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Features included:" -ForegroundColor Cyan
        Write-Host "  🐍 Conda environment management" -ForegroundColor White
        Write-Host "  ⚡ SageAttention (background install)" -ForegroundColor White
        Write-Host "  🤖 UniAnimate-DiT installation" -ForegroundColor White
        Write-Host "  📁 File manager access" -ForegroundColor White
        Write-Host "  🔄 Auto conda activation" -ForegroundColor White
        Write-Host ""
        Write-Host "To test locally:" -ForegroundColor Cyan
        Write-Host "  docker run -p 8077:8077 $imageTag" -ForegroundColor Gray
        Write-Host ""
        Write-Host "File Manager will be available at: http://localhost:8077" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Build failed!" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Build error: $_" -ForegroundColor Red
    exit 1
}
