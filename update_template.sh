#!/bin/bash

# Script to update the template repository to the latest version
# This can be run manually in RunPod JupyterLab terminal if needed

echo "=== Template Repository Update Script ==="
echo "This script updates your comfy_template to the latest GitHub version"
echo

cd /workspace

# Check if we're in a RunPod environment
if [ ! -d "/workspace" ]; then
    echo "ERROR: This script is designed for RunPod environment (/workspace not found)"
    exit 1
fi

TEMPLATE_REPO_URL="https://github.com/bbits10/comfy_template.git"

if [ -d "/workspace/comfy_template/.git" ]; then
    echo "✓ Found existing git repository at /workspace/comfy_template"
    cd /workspace/comfy_template
    
    echo "Fetching latest changes..."
    git fetch origin
    
    echo "Current branch/commit:"
    git log --oneline -1
    
    echo "Latest remote commit:"
    git log --oneline -1 origin/main
    
    echo "Updating to latest version..."
    git reset --hard origin/main
    
    echo "✓ Repository updated successfully!"
    
else
    echo "No git repository found at /workspace/comfy_template"
    
    if [ -d "/workspace/comfy_template" ]; then
        echo "Backing up existing directory..."
        mv /workspace/comfy_template /workspace/comfy_template_backup_$(date +%s)
    fi
    
    echo "Cloning fresh repository..."
    git clone "$TEMPLATE_REPO_URL" /workspace/comfy_template
    echo "✓ Repository cloned successfully!"
fi

# Make scripts executable
echo "Making scripts executable..."
chmod +x /workspace/comfy_template/*.sh

echo
echo "=== Update Complete ==="
echo "Your template repository is now up to date!"
echo "New model configs will be available after restarting the model downloader service."
echo
echo "To restart model downloader:"
echo "1. Find the model downloader process: ps aux | grep model_downloader"
echo "2. Kill it: kill <PID>"
echo "3. Restart it: cd /workspace/comfy_template && python model_downloader.py &"
echo
