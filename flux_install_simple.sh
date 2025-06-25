#!/bin/bash
set -e

# This script installs ComfyUI and all required custom nodes in a simple, robust, idempotent way.
# It is based on the proven logic from commit c4dc61b0af377b3c30b2ab4a9a6bc00e98445c07.

COMFY_DIR="/workspace/ComfyUI"
CUSTOM_NODES_DIR="$COMFY_DIR/custom_nodes"

# Ensure ComfyUI exists
if [ ! -d "$COMFY_DIR" ]; then
    echo "[INFO] Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
else
    echo "[INFO] ComfyUI already exists. Pulling latest..."
    cd "$COMFY_DIR"
    git pull || true
fi

# List of custom nodes to install (repo URL and optional folder name)
CUSTOM_NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager.git"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
    "https://github.com/WASasquatch/was-node-suite-comfyui.git"
    "https://github.com/cubiq/ComfyUI_InstantID.git"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
    "https://github.com/Fannovel16/comfyui_controlnet_aux.git"
    "https://github.com/Derfuu/ComfyUI-Advanced-ControlNet.git"
    "https://github.com/rgthree/rgthree-comfy.git"
    "https://github.com/SLAPaper/ComfyUI-TrainingNodes.git"
    "https://github.com/ExponentialML/ComfyUI-ExLlamaV2.git"
    "https://github.com/ExponentialML/ComfyUI-GGUF.git"
    "https://github.com/KJ002/ComfyUI_KJNodes.git"
    "https://github.com/Suzie1/ComfyUI_SAGAttention.git"
)

# Install or update each custom node
mkdir -p "$CUSTOM_NODES_DIR"
cd "$CUSTOM_NODES_DIR"
for repo in "${CUSTOM_NODES[@]}"; do
    name=$(basename "$repo" .git)
    if [ ! -d "$name" ]; then
        echo "[INFO] Cloning $name..."
        git clone "$repo"
    else
        echo "[INFO] Updating $name..."
        cd "$name"
        git pull || true
        cd ..
    fi
    echo "[INFO] $name installed/updated."
done

echo "[INFO] All custom nodes installed/updated."

# Install python requirements for ComfyUI and all custom nodes
cd "$COMFY_DIR"
if [ -f "requirements.txt" ]; then
    echo "[INFO] Installing ComfyUI requirements..."
    pip install --upgrade -r requirements.txt
fi

for node_dir in "$CUSTOM_NODES_DIR"/*; do
    if [ -f "$node_dir/requirements.txt" ]; then
        echo "[INFO] Installing requirements for $(basename "$node_dir")..."
        pip install --upgrade -r "$node_dir/requirements.txt"
    fi
done

echo "[INFO] ComfyUI and all custom nodes are ready."
