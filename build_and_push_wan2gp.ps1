# PowerShell script to build and push Wan2GP Docker image
# Usage: .\build_and_push_wan2gp.ps1

$dockerHubUser = "beautyinbits"
$imageName = "$dockerHubUser/wan2gp:latest"
$dockerfile = "Dockerfile.wan2gp"

Write-Host "Building Docker image: $imageName"
docker build -f $dockerfile -t $imageName .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed!"
    exit 1
}

Write-Host "Logging in to Docker Hub..."
docker login

Write-Host "Pushing image to Docker Hub: $imageName"
docker push $imageName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Image pushed successfully!"
} else {
    Write-Host "Docker push failed!"
    exit 1
}
