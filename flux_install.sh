#!/bin/bash

# Exit on error
set -e

# Source installation logger
source /workspace/comfy_template/installation_logger.sh 2>/dev/null || true

# --- Configuration ---
COMFYUI_DIR="/workspace/ComfyUI" # Main directory for ComfyUI installation
UPDATE_COMFY_UI=${1:-true}       # Set to "false" as first script argument to disable ComfyUI git pull
INSTALL_CUSTOM_NODES_DEPENDENCIES=true
USE_COMFYUI_MANAGER=true
INSTALL_SAGEATTENTION=${INSTALL_SAGEATTENTION:-"background"} # "true", "false", or "background"

# --- Script Start ---
echo "=================================================="
echo "Starting ComfyUI Setup for RunPod"
echo "Target Directory: $COMFYUI_DIR"
echo "Update ComfyUI: $UPDATE_COMFY_UI"
echo "Install Custom Nodes & Dependencies: $INSTALL_CUSTOM_NODES_DEPENDENCIES"
echo "Use ComfyUI Manager: $USE_COMFYUI_MANAGER"
echo "SageAttention Installation: $INSTALL_SAGEATTENTION"
echo "=================================================="
echo

# Log installation start
log_step "Starting ComfyUI installation and setup"
update_status "overall" "starting"

# Create parent directory for COMFYUI_DIR if it doesn't exist and navigate
mkdir -p "$(dirname "$COMFYUI_DIR")"
cd "$(dirname "$COMFYUI_DIR")"

echo_section() {
  echo
  echo "--- $1 ---"
}

# 2. Clone or Update ComfyUI
if [ ! -d "$COMFYUI_DIR" ]; then
  echo_section "Cloning ComfyUI"
  log_step "Cloning ComfyUI repository"
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
  cd "$COMFYUI_DIR"
  mark_completed "ComfyUI repository cloned"
else
  cd "$COMFYUI_DIR"
  if [ "$UPDATE_COMFY_UI" = true ]; then
    echo_section "Updating ComfyUI"
    log_step "Updating ComfyUI repository"
    git pull
    mark_completed "ComfyUI repository updated"
  else
    echo_section "ComfyUI exists, skipping update as per configuration."
    log_step "ComfyUI exists, skipping update"
  fi
fi

update_status "comfyui_core" "completed"

# 3. Install ComfyUI Main Dependencies
echo_section "Installing ComfyUI main dependencies (from requirements.txt)"
log_step "Installing ComfyUI main dependencies"
pip install -r requirements.txt
mark_completed "ComfyUI main dependencies installed"
update_status "dependencies_main" "completed"

# 4. Install Additional Core Dependencies (from Colab script)
echo_section "Installing additional core dependencies"
log_step "Installing additional core dependencies"
pip install accelerate einops transformers>=4.28.1 safetensors>=0.4.2 aiohttp pyyaml Pillow scipy tqdm psutil tokenizers>=0.13.3
pip install torchsde
pip install kornia>=0.7.1 spandrel soundfile sentencepiece
pip install imageio-ffmpeg  # For VHS_VideoCombine nodefmpeg  # For VHS_VideoCombine node
mark_completed "Additional core dependencies installed"
update_status "dependencies_additional" "completed"

# 5. Install prerequisites for ComfyUI-Manager CLI and other tools
echo_section "Installing GitPython and Typer (for ComfyUI-Manager CLI)"
pip install GitPython typer

# 6. Setup ComfyUI-Manager
if [ "$USE_COMFYUI_MANAGER" = true ]; then
  echo_section "Setting up ComfyUI-Manager"
  MANAGER_DIR="$COMFYUI_DIR/custom_nodes/ComfyUI-Manager"
  if [ ! -d "$MANAGER_DIR" ]; then
    echo "Cloning ComfyUI-Manager..."
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$MANAGER_DIR"
  else
    echo "Updating ComfyUI-Manager..."
    (cd "$MANAGER_DIR" && git pull) # Use subshell to avoid cd issues
  fi
  
  # Install requirements for ComfyUI-Manager, if any are specified in its own requirements.txt
  if [ -f "$MANAGER_DIR/requirements.txt" ]; then
    echo "Installing ComfyUI-Manager's own requirements..."
    pip install -r "$MANAGER_DIR/requirements.txt"
  fi

  echo "Attempting to restore dependencies via ComfyUI-Manager CLI..."
  # This command's behavior depends on ComfyUI-Manager's state/config.
  # It might restore a snapshot or install manager-specific dependencies.
  python "$MANAGER_DIR/cm-cli.py" restore-dependencies
fi

# 7. Install Custom Nodes and Their Dependencies
if [ "$INSTALL_CUSTOM_NODES_DEPENDENCIES" = true ]; then
  echo_section "Installing Custom Nodes & Their Dependencies"
  CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
  mkdir -p "$CUSTOM_NODES_DIR"
  cd "$CUSTOM_NODES_DIR"

  # Repositories to clone
  CUSTOM_NODES_REPOS=(
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/civitai/civitai_comfy_nodes"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/sipherxyz/comfyui-art-venture"
    "https://github.com/twri/sdxl_prompt_styler"
    "https://github.com/Nourepide/ComfyUI-Allor"
    "https://github.com/Extraltodeus/sigmas_tools_and_the_golden_scheduler"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/pollockjj/ComfyUI-MultiGPU"
    "https://github.com/daxcay/ComfyUI-JDCN"
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/calcuis/gguf"
    "https://github.com/Yuan-ManX/ComfyUI-SkyReels-A2"
    "https://github.com/kijai/ComfyUI-GIMM-VFI"
    # was-node-suite-comfyui is handled separately below
    # "https://github.com/thu-ml/SageAttention.git" # Note .git suffix - REMOVED
  )

  for repo_url in "${CUSTOM_NODES_REPOS[@]}"; do
    repo_name=$(basename "$repo_url" .git)
    if [ ! -d "$repo_name" ]; then
      echo "Cloning $repo_name..."
      git clone "$repo_url" "$repo_name" # Explicitly provide target directory name
    else
      echo "Updating $repo_name..."
      (cd "$repo_name" && git pull)
    fi
  done

  # Install requirements for specific nodes that bundle them
  NODES_WITH_REQS=(
    "ComfyUI-GGUF"
    "ComfyUI-JDCN"
    "ComfyUI-KJNodes"
    "ComfyUI-SkyReels-A2"
  )
  for node_name in "${NODES_WITH_REQS[@]}"; do
    if [ -d "$node_name" ] && [ -f "$node_name/requirements.txt" ]; then
      echo "Installing dependencies for $node_name..."
      pip install -r "$node_name/requirements.txt"
    fi
  done

  # Special handling for was-node-suite-comfyui (cloned to specific name if desired, original didn't)
  WAS_NODE_DIR_NAME="was-node-suite-comfyui" # Directory name it will be cloned into
  WAS_NODE_REPO="https://github.com/WASasquatch/was-node-suite-comfyui.git"
  if [ ! -d "$WAS_NODE_DIR_NAME" ]; then
    echo "Cloning $WAS_NODE_DIR_NAME..."
    git clone "$WAS_NODE_REPO" "$WAS_NODE_DIR_NAME"
  else
    echo "Updating $WAS_NODE_DIR_NAME..."
    (cd "$WAS_NODE_DIR_NAME" && git pull)
  fi
  if [ -f "$WAS_NODE_DIR_NAME/requirements.txt" ]; then
    echo "Installing dependencies for $WAS_NODE_DIR_NAME..."
    pip install -r "$WAS_NODE_DIR_NAME/requirements.txt"
  fi

  cd "$COMFYUI_DIR" # Return to the main ComfyUI directory
fi

# 8. Clone FFmpeg source
echo_section "Cloning FFmpeg source"
cd "$COMFYUI_DIR"
if [ ! -d "ffmpeg" ]; then
  echo "Cloning FFmpeg repository..."
  git clone https://git.ffmpeg.org/ffmpeg.git
else
  echo "FFmpeg directory already exists. Skipping clone."
fi

# 9. Install gguf-node after ComfyUI setup is complete
echo_section "Installing gguf-node"
pip install gguf-node

# 10. Install SageAttention (Configurable)
if [ "$INSTALL_SAGEATTENTION" != "false" ]; then
  echo_section "Setting up SageAttention (mode: $INSTALL_SAGEATTENTION)"
  cd "$COMFYUI_DIR"
  if [ ! -d "SageAttention" ]; then
    echo "Cloning SageAttention repository..."
    git clone https://github.com/thu-ml/SageAttention.git
  else
    echo "SageAttention directory already exists. Updating..."
    (cd "SageAttention" && git pull)
  fi

  if [ "$INSTALL_SAGEATTENTION" = "background" ]; then
    # Create a background installation script
    cat > install_sageattention.sh << 'EOF'
#!/bin/bash
echo "$(date): Starting SageAttention installation in background..."
source /workspace/comfy_template/installation_logger.sh 2>/dev/null || true
log_step "SageAttention background installation started"
cd /workspace/ComfyUI/SageAttention
python setup.py install
mark_completed "SageAttention installation completed"
update_status "sageattention" "completed"
echo "$(date): SageAttention installation completed!" >> /workspace/sageattention_install.log
EOF

    chmod +x install_sageattention.sh
    echo "SageAttention will be installed in the background. Check /workspace/sageattention_install.log for progress."
    log_step "Starting SageAttention installation in background"
    nohup ./install_sageattention.sh > /workspace/sageattention_install.log 2>&1 &
    update_status "sageattention" "installing_background"
  else
    # Install synchronously (original behavior)
    cd "SageAttention"
    echo "Installing SageAttention synchronously (this may take 15-20 minutes)..."
    log_step "Installing SageAttention synchronously (15-20 minutes)"
    update_status "sageattention" "installing_sync"
    python setup.py install
    mark_completed "SageAttention installation completed"
    update_status "sageattention" "completed"
  fi

  cd "$COMFYUI_DIR" # Return to the main ComfyUI directory
else
  echo_section "Skipping SageAttention installation (INSTALL_SAGEATTENTION=false)"
fi

# 11. Download Models
# echo_section "Downloading Models"
# MODELS_BASE_DIR="$COMFYUI_DIR/models"
# mkdir -p "$MODELS_BASE_DIR/text_encoders"
# mkdir -p "$MODELS_BASE_DIR/vae"
# mkdir -p "$MODELS_BASE_DIR/diffusion_models"
# mkdir -p "$MODELS_BASE_DIR/unet" # For specific GGUF models if needed
# mkdir -p "$MODELS_BASE_DIR/loras"
# mkdir -p "$MODELS_BASE_DIR/clip_vision"



# --- Setup Complete ---
echo
echo "=================================================="
echo "ComfyUI Installation and Setup Complete!"
echo "Target Directory: $COMFYUI_DIR"
echo "=================================================="
echo
echo "To start ComfyUI, navigate to the ComfyUI directory and run:"
echo "  cd $COMFYUI_DIR"
echo "  python main.py --listen --port 8188 --preview-method auto"
echo
echo "Ensure your RunPod instance's HTTP port is mapped to 8188."
echo "For example, if RunPod exposes port 8080 externally, set it to proxy to 8188 internally."
echo

# Log completion
mark_completed "ComfyUI installation and setup completed"
update_status "overall" "completed"
log_step "Installation script finished successfully"

# Optional: Automatically start ComfyUI
# echo "Starting ComfyUI..."
# cd "$COMFYUI_DIR"
# exec python main.py --listen --port 8188 --preview-method auto

exit 0