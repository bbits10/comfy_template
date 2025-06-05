#!/bin/bash

# Exit on error
set -e

# --- Configuration ---
COMFYUI_DIR="/workspace/ComfyUI" # Main directory for ComfyUI installation
UPDATE_COMFY_UI=${1:-true}       # Set to "false" as first script argument to disable ComfyUI git pull
INSTALL_CUSTOM_NODES_DEPENDENCIES=true
USE_COMFYUI_MANAGER=true

# --- Script Start ---
echo "=================================================="
echo "Starting ComfyUI Setup for RunPod"
echo "Target Directory: $COMFYUI_DIR"
echo "Update ComfyUI: $UPDATE_COMFY_UI"
echo "Install Custom Nodes & Dependencies: $INSTALL_CUSTOM_NODES_DEPENDENCIES"
echo "Use ComfyUI Manager: $USE_COMFYUI_MANAGER"
echo "=================================================="
echo

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
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
  cd "$COMFYUI_DIR"
else
  cd "$COMFYUI_DIR"
  if [ "$UPDATE_COMFY_UI" = true ]; then
    echo_section "Updating ComfyUI"
    git pull
  else
    echo_section "ComfyUI exists, skipping update as per configuration."
  fi
fi

# 3. Install ComfyUI Main Dependencies
echo_section "Installing ComfyUI main dependencies (from requirements.txt)"
pip install -r requirements.txt

# 4. Install Additional Core Dependencies (from Colab script)
echo_section "Installing additional core dependencies"
pip install accelerate einops transformers>=4.28.1 safetensors>=0.4.2 aiohttp pyyaml Pillow scipy tqdm psutil tokenizers>=0.13.3
pip install torchsde
pip install kornia>=0.7.1 spandrel soundfile sentencepiece
pip install imageio-ffmpeg  # For VHS_VideoCombine node

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

# 10. Download Models
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

# Optional: Automatically start ComfyUI
# echo "Starting ComfyUI..."
# cd "$COMFYUI_DIR"
# exec python main.py --listen --port 8188 --preview-method auto

exit 0