#!/bin/bash
# Manual SageAttention installation script for RunPod

echo "=== Manual SageAttention Installation ==="
echo "$(date): Starting SageAttention installation..."

cd /workspace/ComfyUI

# Clone SageAttention if not exists
if [ ! -d "SageAttention" ]; then
    echo "Cloning SageAttention repository..."
    git clone https://github.com/thu-ml/SageAttention.git
else
    echo "SageAttention directory exists, updating..."
    cd SageAttention && git pull && cd ..
fi

cd SageAttention

# Set compilation optimization flags
export EXT_PARALLEL=4 
export NVCC_APPEND_FLAGS="--threads 8" 
export MAX_JOBS=32

echo "Installing SageAttention with optimization flags..."
echo "This will run in background. You can use model downloader now!"

# Install in background
nohup python setup.py install > /workspace/sageattention_install.log 2>&1 &

# Get the process ID
SAGE_PID=$!
echo "SageAttention installation started with PID: $SAGE_PID"
echo "Monitor progress: tail -f /workspace/sageattention_install.log"
echo "Check if running: ps aux | grep $SAGE_PID"

# Create completion marker when done
(
    wait $SAGE_PID
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S')" > /workspace/.install_markers/sageattention.done
        echo "$(date): SageAttention installation completed successfully!" >> /workspace/sageattention_install.log
    else
        echo "$(date): SageAttention installation failed!" >> /workspace/sageattention_install.log
    fi
) &

echo "=== You can now use the model downloader while SageAttention compiles! ==="
