#!/bin/bash

echo "--- start_services_unianimate.sh: Script started ---"

# Ensure script exits on error
set -e

echo "Current directory: $(pwd)"
echo "Listing /workspace:"
ls -la /workspace

# Initialize conda if available
if [ -d "/workspace/miniconda3" ]; then
    echo "Initializing conda..."
    source /workspace/miniconda3/etc/profile.d/conda.sh
    
    # Check if unianimate environment exists
    if conda env list | grep -q "unianimate"; then
        echo "Activating unianimate conda environment..."
        conda activate unianimate
        echo "✅ Conda environment activated: $(conda info --envs | grep '*' | awk '{print $1}')"
    else
        echo "⚠️ UniAnimate conda environment not found - will be created during installation"
    fi
else
    echo "⚠️ Conda not found - will be installed during setup"
fi

# Start JupyterLab from /workspace directory
echo "Starting JupyterLab from /workspace directory..."
cd /workspace
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --ServerApp.token='' --ServerApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_remote_access=True &
JUPYTER_PID=$!
echo "JupyterLab PID: $JUPYTER_PID"
echo "JupyterLab started from directory: $(pwd)"

# Start the file manager early
echo "Starting file manager early..."
if [ -f "/workspace/comfy_template/file_manager.py" ]; then
    python /workspace/comfy_template/file_manager.py &
    FILE_MANAGER_PID=$!
    echo "File Manager PID: $FILE_MANAGER_PID"
else
    echo "WARNING: /workspace/comfy_template/file_manager.py not found! File manager service will not be available."
fi

# Start model downloader early
echo "Starting model downloader early..."
if [ -f "/workspace/comfy_template/model_downloader.py" ]; then
    python /workspace/comfy_template/model_downloader.py &
    MODEL_DOWNLOADER_PID=$!
    echo "Model Downloader PID: $MODEL_DOWNLOADER_PID"
else
    echo "WARNING: /workspace/comfy_template/model_downloader.py not found!"
fi

# Start UniAnimate-DiT web interface if available
echo "Starting UniAnimate-DiT web interface..."
if [ -f "/workspace/UniAnimate-DiT/web_interface.py" ]; then
    cd /workspace/UniAnimate-DiT
    
    # Activate conda environment for the web interface
    if [ -d "/workspace/miniconda3" ]; then
        source /workspace/miniconda3/etc/profile.d/conda.sh
        if conda env list | grep -q "unianimate"; then
            conda activate unianimate
        fi
    fi
    
    python web_interface.py &
    UNIANIMATE_WEB_PID=$!
    echo "UniAnimate-DiT Web Interface PID: $UNIANIMATE_WEB_PID"
    echo "UniAnimate-DiT interface will be available on port 8877"
    cd /workspace/comfy_template
else
    echo "INFO: UniAnimate-DiT web interface not found - will be created during installation"
fi

# Run UniAnimate-DiT installation in background
echo "Running UniAnimate-DiT installation in background..."
echo "Checking if unianimate_install.sh exists at /workspace/comfy_template/unianimate_install.sh"
if [ ! -f "/workspace/comfy_template/unianimate_install.sh" ]; then
    echo "ERROR: /workspace/comfy_template/unianimate_install.sh not found!"
    exit 1
else
    echo "Making unianimate_install.sh executable..."
    chmod +x /workspace/comfy_template/unianimate_install.sh
    echo "Running unianimate_install.sh in background..."
    
    # Set default environment variables
    export INSTALL_MODELS=${INSTALL_MODELS:-"true"}
    export INSTALL_SAGEATTENTION=${INSTALL_SAGEATTENTION:-"background"}
    
    # Run installation in background with proper conda initialization
    (
        echo "=== Background UniAnimate-DiT Installation Started ==="
        cd /workspace/comfy_template
        bash ./unianimate_install.sh 2>&1 | tee /workspace/unianimate_install.log
        echo "=== Background UniAnimate-DiT Installation Completed ==="
    ) &
    
    INSTALL_PID=$!
    echo "UniAnimate-DiT Installation PID: $INSTALL_PID"
fi

# Wait a moment for services to start
sleep 3

echo "All services started successfully!"
echo "Service Access URLs:"
echo "- JupyterLab: http://localhost:8888"
echo "- File Manager: http://localhost:8765"
echo "- Model Downloader: http://localhost:8866"
echo "- UniAnimate-DiT Interface: http://localhost:8877 (after installation)"
echo "- Installation Status: http://localhost:8765/installation-status"
echo

echo "Installation is running in the background. Check the status at:"
echo "http://localhost:8765/installation-status"
echo
echo "Installation log is being written to: /workspace/unianimate_install.log"
echo "You can monitor progress with: tail -f /workspace/unianimate_install.log"

# Create environment setup reminder
cat > /workspace/UNIANIMATE_SETUP.md << 'EOF'
# UniAnimate-DiT Setup Instructions

## Environment Activation
The UniAnimate-DiT conda environment should activate automatically when you open a new terminal.

To manually activate:
```bash
source /workspace/activate_unianimate.sh
```

Or manually:
```bash
source /workspace/miniconda3/etc/profile.d/conda.sh
conda activate unianimate
```

## Testing Installation
```bash
cd /workspace/UniAnimate-DiT
python test_installation.py
```

## Web Interfaces
- **UniAnimate-DiT Interface**: http://localhost:8877
- **JupyterLab**: http://localhost:8888  
- **File Manager**: http://localhost:8765
- **Model Downloader**: http://localhost:8866

## Model Download
Models need to be downloaded manually. Use the Model Downloader interface or:

### Wan2.1-I2V-14B-720P Model
```bash
huggingface-cli download Ali-Vilab/Wan2.1-I2V-14B-720P --local-dir /workspace/UniAnimate-DiT/models/wan2.1
```

### UniAnimate-DiT Checkpoints
Download from the official repository and place in:
```
/workspace/UniAnimate-DiT/models/checkpoints/
```

## Directory Structure
```
/workspace/
├── miniconda3/                 # Conda installation
├── UniAnimate-DiT/            # Main UniAnimate-DiT repository
│   ├── models/                # Model storage
│   ├── test_installation.py   # Installation test script
│   └── web_interface.py       # Web interface
├── activate_unianimate.sh     # Environment activation script
└── unianimate_install.log     # Installation log
```

## Troubleshooting
- Check installation log: `tail -f /workspace/unianimate_install.log`
- Test environment: `python /workspace/UniAnimate-DiT/test_installation.py`
- Check conda environments: `conda env list`
- Verify CUDA: `python -c "import torch; print(torch.cuda.is_available())"`
EOF

echo "Setup instructions created at: /workspace/UNIANIMATE_SETUP.md"

# Store process IDs for monitoring
cat > /workspace/service_pids.txt << EOF
JUPYTER_PID=$JUPYTER_PID
FILE_MANAGER_PID=$FILE_MANAGER_PID
MODEL_DOWNLOADER_PID=$MODEL_DOWNLOADER_PID
UNIANIMATE_WEB_PID=${UNIANIMATE_WEB_PID:-"not_started"}
INSTALL_PID=$INSTALL_PID
EOF

echo "Process IDs stored in: /workspace/service_pids.txt"

# Keep the script running to maintain the services
echo "Services are running. Press Ctrl+C to stop."
echo "Monitoring installation progress..."

# Monitor installation in background
(
    while kill -0 $INSTALL_PID 2>/dev/null; do
        sleep 30
        echo "Installation still running... (PID: $INSTALL_PID)"
    done
    echo "✅ UniAnimate-DiT installation completed!"
    
    # Start UniAnimate web interface after installation if it wasn't started before
    if [ "$UNIANIMATE_WEB_PID" = "not_started" ] && [ -f "/workspace/UniAnimate-DiT/web_interface.py" ]; then
        echo "Starting UniAnimate-DiT web interface after installation..."
        cd /workspace/UniAnimate-DiT
        
        # Ensure conda environment is activated
        if [ -d "/workspace/miniconda3" ]; then
            source /workspace/miniconda3/etc/profile.d/conda.sh
            conda activate unianimate 2>/dev/null || true
        fi
        
        python web_interface.py &
        UNIANIMATE_WEB_PID=$!
        echo "UniAnimate-DiT Web Interface started with PID: $UNIANIMATE_WEB_PID"
        echo "UniAnimate-DiT interface is now available on port 8877"
        
        # Update PID file
        sed -i "s/UNIANIMATE_WEB_PID=not_started/UNIANIMATE_WEB_PID=$UNIANIMATE_WEB_PID/" /workspace/service_pids.txt
    fi
) &

# Wait for any service to exit
wait
