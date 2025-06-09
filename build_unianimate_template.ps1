# PowerShell script to build UniAnimate-DiT RunPod template
# Usage: .\build_unianimate_template.ps1

Write-Host "🚀 Building UniAnimate-DiT RunPod Template" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Check if Docker is available
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker found: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker not found. Please install Docker Desktop." -ForegroundColor Red
    exit 1
}

# Set variables
$templateName = "unianimate-dit-template"
$templateTag = "latest"
$dockerFile = "Dockerfile.unianimate"

Write-Host "`n📋 Build Configuration:" -ForegroundColor Yellow
Write-Host "Template Name: $templateName" -ForegroundColor White
Write-Host "Template Tag: $templateTag" -ForegroundColor White
Write-Host "Dockerfile: $dockerFile" -ForegroundColor White
Write-Host "Build Context: $(Get-Location)" -ForegroundColor White

# Verify required files exist
$requiredFiles = @(
    "Dockerfile.unianimate",
    "start_services_unianimate.sh", 
    "unianimate_install.sh",
    "file_manager.py",
    "templates/unianimate_interface.html"
)

Write-Host "`n🔍 Checking required files..." -ForegroundColor Yellow
$missingFiles = @()

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file" -ForegroundColor Green
    } else {
        Write-Host "❌ $file" -ForegroundColor Red
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "`n❌ Missing required files. Build cannot continue." -ForegroundColor Red
    exit 1
}

# Build the Docker image
Write-Host "`n🏗️ Building Docker image..." -ForegroundColor Yellow
Write-Host "Command: docker build -f $dockerFile -t ${templateName}:${templateTag} ." -ForegroundColor Gray

try {
    $buildResult = docker build -f $dockerFile -t "${templateName}:${templateTag}" . 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker image built successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Docker build failed!" -ForegroundColor Red
        Write-Host $buildResult -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Docker build error: $_" -ForegroundColor Red
    exit 1
}

# Verify the image was created
Write-Host "`n🔍 Verifying image..." -ForegroundColor Yellow
try {
    $imageInfo = docker images "${templateName}:${templateTag}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    Write-Host $imageInfo -ForegroundColor White
} catch {
    Write-Host "⚠️ Could not verify image information" -ForegroundColor Yellow
}

# Test the image (optional)
Write-Host "`n🧪 Testing image (optional)..." -ForegroundColor Yellow
$testChoice = Read-Host "Would you like to test the image locally? (y/N)"

if ($testChoice -eq 'y' -or $testChoice -eq 'Y') {
    Write-Host "🚀 Starting test container..." -ForegroundColor Yellow
    Write-Host "The container will start and you can test the services." -ForegroundColor White
    Write-Host "Services will be available at:" -ForegroundColor White
    Write-Host "  - UniAnimate Interface: http://localhost:8877" -ForegroundColor Cyan
    Write-Host "  - JupyterLab: http://localhost:8888" -ForegroundColor Cyan
    Write-Host "  - File Manager: http://localhost:8765" -ForegroundColor Cyan
    Write-Host "  - Model Downloader: http://localhost:8866" -ForegroundColor Cyan
    Write-Host "`nPress Ctrl+C to stop the test container." -ForegroundColor Yellow
    
    try {
        docker run --rm -it `
            -p 8765:8765 `
            -p 8866:8866 `
            -p 8877:8877 `
            -p 8888:8888 `
            -v "${PWD}/test_workspace:/workspace" `
            "${templateName}:${templateTag}"
    } catch {
        Write-Host "⚠️ Test run interrupted or failed" -ForegroundColor Yellow
    }
}

# Display deployment information
Write-Host "`n🎉 Template Build Complete!" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green

Write-Host "`n📦 Image Information:" -ForegroundColor Cyan
Write-Host "Image Name: ${templateName}:${templateTag}" -ForegroundColor White
Write-Host "Dockerfile: $dockerFile" -ForegroundColor White

Write-Host "`n🚀 RunPod Deployment:" -ForegroundColor Cyan
Write-Host "1. Push image to Docker registry:" -ForegroundColor White
Write-Host "   docker tag ${templateName}:${templateTag} your-registry/${templateName}:${templateTag}" -ForegroundColor Gray
Write-Host "   docker push your-registry/${templateName}:${templateTag}" -ForegroundColor Gray

Write-Host "`n2. Use in RunPod template:" -ForegroundColor White
Write-Host "   Container Image: your-registry/${templateName}:${templateTag}" -ForegroundColor Gray
Write-Host "   Exposed Ports: 8765, 8866, 8877, 8888" -ForegroundColor Gray

Write-Host "`n📋 Template Features:" -ForegroundColor Cyan
Write-Host "✅ UniAnimate-DiT with conda environment" -ForegroundColor Green
Write-Host "✅ Auto-activating conda environment" -ForegroundColor Green
Write-Host "✅ Comprehensive web interface" -ForegroundColor Green
Write-Host "✅ Background installation process" -ForegroundColor Green
Write-Host "✅ Model management tools" -ForegroundColor Green
Write-Host "✅ Video overlap calculator" -ForegroundColor Green
Write-Host "✅ Real-time progress monitoring" -ForegroundColor Green

Write-Host "`n📚 Documentation:" -ForegroundColor Cyan
Write-Host "README: UNIANIMATE_TEMPLATE_README.md" -ForegroundColor White
Write-Host "Setup Guide: Available in container at /workspace/UNIANIMATE_SETUP.md" -ForegroundColor White

Write-Host "`n🎯 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Push the image to your Docker registry" -ForegroundColor White
Write-Host "2. Create a new RunPod template using the image" -ForegroundColor White
Write-Host "3. Deploy and test on RunPod" -ForegroundColor White
Write-Host "4. Share the template with the community!" -ForegroundColor White

Write-Host "`n✨ Happy Video Generation! 🎬" -ForegroundColor Magenta