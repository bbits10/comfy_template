#!/bin/bash

# Check installation status
# This script shows what components are installed and what might need attention

echo "=== ComfyUI Installation Status Checker ==="
echo

MARKERS_DIR="/workspace/.install_markers"
COMFYUI_DIR="/workspace/ComfyUI"

# Function to check if component is installed
check_component() {
    local component="$1"
    local description="$2"
    
    if [ -f "$MARKERS_DIR/$component.done" ]; then
        local install_date=$(cat "$MARKERS_DIR/$component.done")
        echo "✓ $description (installed: $install_date)"
        return 0
    else
        echo "✗ $description (not installed)"
        return 1
    fi
}

# Function to check directory existence
check_directory() {
    local dir="$1"
    local description="$2"
    
    if [ -d "$dir" ]; then
        echo "✓ $description exists at $dir"
        return 0
    else
        echo "✗ $description missing at $dir"
        return 1
    fi
}

# Function to check file existence  
check_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        echo "✓ $description exists at $file"
        return 0
    else
        echo "✗ $description missing at $file"
        return 1
    fi
}

echo "INSTALLATION MARKERS:"
echo "--------------------"
check_component "comfyui_core" "ComfyUI Core"
check_component "dependencies_main" "Main Dependencies"
check_component "dependencies_additional" "Additional Dependencies"
check_component "manager_prerequisites" "Manager Prerequisites"
check_component "comfyui_manager" "ComfyUI Manager"
check_component "custom_nodes" "Custom Nodes"
check_component "ffmpeg_source" "FFmpeg Source"
check_component "gguf_node" "GGUF Node"
check_component "sageattention" "SageAttention"
check_component "overall_installation" "Overall Installation"

echo
echo "DIRECTORY CHECKS:"
echo "----------------"
check_directory "$COMFYUI_DIR" "ComfyUI Directory"
check_directory "$COMFYUI_DIR/custom_nodes" "Custom Nodes Directory"
check_directory "$COMFYUI_DIR/models" "Models Directory"
check_directory "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager" "ComfyUI Manager"

echo
echo "CRITICAL FILES:"
echo "--------------"
check_file "$COMFYUI_DIR/main.py" "ComfyUI Main Script"
check_file "$COMFYUI_DIR/requirements.txt" "ComfyUI Requirements"

echo
echo "BACKGROUND PROCESSES:"
echo "-------------------"
if pgrep -f "python.*main.py.*--port.*8188" > /dev/null; then
    echo "✓ ComfyUI is running (port 8188)"
else
    echo "✗ ComfyUI is not running"
fi

if pgrep -f "python.*model_downloader.py" > /dev/null; then
    echo "✓ Model Downloader is running"
else
    echo "✗ Model Downloader is not running"
fi

if pgrep -f "python.*file_manager.py" > /dev/null; then
    echo "✓ File Manager is running"
else
    echo "✗ File Manager is not running"
fi

if pgrep -f "jupyter.*lab" > /dev/null; then
    echo "✓ JupyterLab is running"
else
    echo "✗ JupyterLab is not running"
fi

echo
echo "LOG FILES:"
echo "---------"
if [ -f "/workspace/installation_progress.log" ]; then
    echo "✓ Installation log exists (/workspace/installation_progress.log)"
    echo "  Last 3 entries:"
    tail -n 3 /workspace/installation_progress.log | sed 's/^/    /'
else
    echo "✗ No installation log found"
fi

if [ -f "/workspace/sageattention_install.log" ]; then
    echo "✓ SageAttention log exists (/workspace/sageattention_install.log)"
    echo "  Last entry:"
    tail -n 1 /workspace/sageattention_install.log | sed 's/^/    /'
else
    echo "✗ No SageAttention log found"
fi

echo
echo "=== Status Check Complete ==="

# Check if there are any obvious issues
echo
if [ ! -d "$COMFYUI_DIR" ] || [ ! -f "$COMFYUI_DIR/main.py" ]; then
    echo "⚠️  WARNING: ComfyUI does not appear to be properly installed."
    echo "   Consider running: bash /workspace/comfy_template/start_services.sh"
elif [ ! -f "$MARKERS_DIR/overall_installation.done" ]; then
    echo "⚠️  WARNING: Installation may be incomplete."
    echo "   Some components might still be installing or have failed."
    echo "   Check logs for more details."
else
    echo "✅ Installation appears to be complete and healthy!"
fi
