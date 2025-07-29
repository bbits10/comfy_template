# PowerShell script to build Wan2GP RunPod template
# Usage: .\build_wan2gp_template.ps1

Write-Host "Building Wan2GP RunPod Template" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Check if Docker is available
try {
    $dockerVersion = docker --version
    Write-Host "Docker found: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "Docker not found. Please install Docker Desktop." -ForegroundColor Red
    exit 1
}

# Set variables
$templateName = "wan2gp-template"
$templateTag = "latest"
$dockerFile = "Dockerfile.wan2gp"

Write-Host "`nBuild Configuration:" -ForegroundColor Yellow
Write-Host "Template Name: $templateName" -ForegroundColor White
Write-Host "Template Tag: $templateTag" -ForegroundColor White
Write-Host "Dockerfile: $dockerFile" -ForegroundColor White
Write-Host "Build Context: $(Get-Location)" -ForegroundColor White

# Verify required files exist
$requiredFiles = @(
    "Dockerfile.wan2gp",
    "start_services_wan2gp.sh", 
    "wan2gp_install.sh",
    "file_manager.py"
)

Write-Host "`nChecking required files..." -ForegroundColor Yellow
$missingFiles = @()

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "OK $file" -ForegroundColor Green
    } else {
        Write-Host "MISSING $file" -ForegroundColor Red
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "`nMissing required files. Build cannot continue." -ForegroundColor Red
    exit 1
}

Write-Host "`nAll required files found. Proceeding with build..." -ForegroundColor Green

# Start Docker build
Write-Host "`nStarting Docker build..." -ForegroundColor Yellow
Write-Host "Command: docker build -f $dockerFile -t $templateName`:$templateTag ." -ForegroundColor Gray

try {
    $buildStartTime = Get-Date
    
    # Build the Docker image
    docker build -f $dockerFile -t "$templateName`:$templateTag" .
    
    if ($LASTEXITCODE -eq 0) {
        $buildEndTime = Get-Date
        $buildDuration = $buildEndTime - $buildStartTime
        
        Write-Host "`nBuild completed successfully!" -ForegroundColor Green
        Write-Host "Build duration: $($buildDuration.TotalMinutes.ToString('F2')) minutes" -ForegroundColor Green
        Write-Host "Image tagged as: $templateName`:$templateTag" -ForegroundColor Green
        
        # Get image size
        $imageInfo = docker images $templateName`:$templateTag --format "table {{.Size}}" | Select-Object -Skip 1
        Write-Host "Image size: $imageInfo" -ForegroundColor Green
        
        Write-Host "`nNext steps:" -ForegroundColor Yellow
        Write-Host "1. Test the image locally:" -ForegroundColor White
        Write-Host "   docker run -p 8866:8866 -p 8888:8888 $templateName`:$templateTag" -ForegroundColor Gray
        Write-Host "2. Push to your registry:" -ForegroundColor White
        Write-Host "   docker tag $templateName`:$templateTag your-registry/$templateName`:$templateTag" -ForegroundColor Gray
        Write-Host "   docker push your-registry/$templateName`:$templateTag" -ForegroundColor Gray
        Write-Host "3. Use the image URL in RunPod template creation" -ForegroundColor White
        
    } else {
        Write-Host "`nBuild failed!" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "`nBuild failed with error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nBuild script completed!" -ForegroundColor Cyan
