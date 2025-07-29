#!/bin/bash

echo "--- start_services_wan2gp.sh: Script started ---"

# Ensure script exits on error
set -e

echo "Current directory: $(pwd)"
echo "Listing /workspace:"
ls -la /workspace

# Check if this is a resume scenario
RESUMING_POD=false
if [ -d "/workspace/Wan2GP" ] && [ -f "/workspace/Wan2GP/README.md" ]; then
    RESUMING_POD=true
    echo "=== RESUMING EXISTING POD ==="
    echo "Wan2GP installation detected. This appears to be a pod resume."
    echo "Will update template and start services without full reinstallation."
    echo "============================="
fi

# Always copy the latest template files to workspace for updates
echo "📋 Copying template files to workspace..."
cp -r /opt/comfy_template/* /workspace/ 2>/dev/null || true

# Ensure we're in the workspace directory
cd /workspace

# Initialize conda for bash
echo "🐍 Initializing conda..."
eval "$(conda shell.bash hook)"

# Install Wan2GP if not resuming
if [ "$RESUMING_POD" = false ]; then
    echo "🚀 Starting fresh Wan2GP installation..."
    bash wan2gp_install.sh
else
    echo "⚡ Resuming existing installation..."
    
    # Activate the environment
    conda activate wan2gp
    
    # Update repository if needed
    cd Wan2GP
    echo "🔄 Updating Wan2GP repository..."
    git pull origin main || echo "⚠️ Could not update repository (may be offline or no changes)"
    cd ..
fi

# Start Flask file manager
echo "🌐 Starting Flask file manager..."
python file_manager.py &

# Wait for file manager to start
sleep 3

# Activate conda environment and navigate to Wan2GP
conda activate wan2gp
cd Wan2GP

echo "🎉 Wan2GP services are ready!"
echo "📁 File manager available at: http://localhost:8866"
echo "🔗 Access your pod at the external URL provided by RunPod"
echo ""
echo "💡 To run Wan2GP commands:"
echo "   1. Access the terminal via the file manager interface"
echo "   2. Navigate to /workspace/Wan2GP"
echo "   3. Activate conda environment: conda activate wan2gp"
echo "   4. Run your Wan2GP scripts"
echo ""

# Keep the container running
echo "⏳ Keeping container alive..."
while true; do
    sleep 30
    echo "🔄 Container heartbeat: $(date)"
done
