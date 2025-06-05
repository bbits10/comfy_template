#!/bin/bash

echo "--- start_services.sh: Script started ---"

# Ensure script exits on error
set -e

echo "Current directory: $(pwd)"
echo "Listing /workspace:"
ls -la /workspace

# Start JupyterLab from /workspace directory so ComfyUI folder is visible
echo "Starting JupyterLab from /workspace directory..."
cd /workspace
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --ServerApp.token='' --ServerApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_remote_access=True &
JUPYTER_PID=$!
echo "JupyterLab PID: $JUPYTER_PID"
echo "JupyterLab started from directory: $(pwd)"

# Run ComfyUI installation first
echo "Running ComfyUI installation..."
echo "Checking if flux_install.sh exists at /workspace/comfy_template/flux_install.sh"
if [ ! -f "/workspace/comfy_template/flux_install.sh" ]; then
    echo "ERROR: /workspace/comfy_template/flux_install.sh not found!"
    exit 1
else
    echo "Making flux_install.sh executable..."
    chmod +x /workspace/comfy_template/flux_install.sh
    echo "Running flux_install.sh..."
    bash /workspace/comfy_template/flux_install.sh
    echo "ComfyUI installation completed successfully."
fi

# Create symbolic link for ComfyUI visibility in template directory
echo "Creating symbolic link for ComfyUI access..."
if [ -d "/workspace/ComfyUI" ] && [ ! -L "/workspace/comfy_template/ComfyUI" ]; then
    ln -s /workspace/ComfyUI /workspace/comfy_template/ComfyUI
    echo "✓ Created symbolic link: /workspace/comfy_template/ComfyUI -> /workspace/ComfyUI"
elif [ -L "/workspace/comfy_template/ComfyUI" ]; then
    echo "✓ Symbolic link already exists: /workspace/comfy_template/ComfyUI"
else
    echo "⚠️  ComfyUI directory not found, skipping symbolic link creation"
fi

# Create model directories after ComfyUI installation
echo "Creating additional model directories..."
mkdir -p /workspace/ComfyUI/models/{checkpoints,clip,clip_vision,controlnet,diffusers,embeddings,loras,upscale_models,vae,unet,configs}
echo "Model directories created."

# Start the model downloader in the background
echo "Starting model downloader..."
echo "Checking if model_downloader.py exists at /workspace/comfy_template/model_downloader.py"
if [ ! -f "/workspace/comfy_template/model_downloader.py" ]; then
    echo "ERROR: /workspace/comfy_template/model_downloader.py not found!"
    # exit 1 # Decide if this is fatal
else
    python /workspace/comfy_template/model_downloader.py &
    MODEL_DOWNLOADER_PID=$!
    echo "Model Downloader PID: $MODEL_DOWNLOADER_PID"
fi

# Start the file manager in the background
echo "Starting file manager..."
echo "Checking if file_manager.py exists at /workspace/comfy_template/file_manager.py"
if [ ! -f "/workspace/comfy_template/file_manager.py" ]; then
    echo "WARNING: /workspace/comfy_template/file_manager.py not found! File manager service will not be available."
else
    python /workspace/comfy_template/file_manager.py &
    FILE_MANAGER_PID=$!
    echo "File Manager PID: $FILE_MANAGER_PID"
fi

# Start ComfyUI
echo "Preparing to start ComfyUI..."
echo "Checking for ComfyUI directory at /workspace/ComfyUI..."
if [ ! -d "/workspace/ComfyUI" ]; then
    echo "ERROR: /workspace/ComfyUI directory does not exist! flux_install.sh might have failed."
    exit 1
fi
echo "/workspace/ComfyUI directory exists."

echo "Checking for ComfyUI main.py at /workspace/ComfyUI/main.py..."
if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "ERROR: /workspace/ComfyUI/main.py does not exist! ComfyUI installation is incomplete."
    exit 1
fi
echo "/workspace/ComfyUI/main.py exists."

echo "Changing directory to /workspace/ComfyUI"
cd /workspace/ComfyUI
echo "Current directory after cd: $(pwd)"

echo "Starting ComfyUI..."
python main.py --listen --port 8188 --preview-method auto &
COMFYUI_PID=$!
echo "ComfyUI PID: $COMFYUI_PID"

# Ensure the process started
echo "Waiting for ComfyUI to start..."
sleep 5 # Increased sleep time
if ! pgrep -f "python.*main.py.*--port.*8188" > /dev/null; then
    echo "ERROR: Failed to start ComfyUI. Check ComfyUI logs."
    # Consider dumping last few lines of any ComfyUI log if available
    exit 1
else
    echo "ComfyUI process found."
fi

echo "--- start_services.sh: Services launched, waiting for processes to exit ---"
# Wait for all background processes to complete (or be terminated)
# If you want to keep the container running until one of them exits:
# wait -n
# If you want to wait for all of them (e.g. if they are all background services that should run indefinitely until container stops)
if [ -n "$FILE_MANAGER_PID" ]; then
    wait $JUPYTER_PID $MODEL_DOWNLOADER_PID $FILE_MANAGER_PID $COMFYUI_PID
else
    wait $JUPYTER_PID $MODEL_DOWNLOADER_PID $COMFYUI_PID
fi
# If any of the PIDs are not set because a service failed to start, 'wait' might behave unexpectedly.
# A more robust approach for long-running services is to just 'wait' without PIDs,
# or use a supervisor process. For now, this should give more insight.

echo "--- start_services.sh: Script finished ---"
