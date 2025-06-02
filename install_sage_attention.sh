#!/bin/bash

# This script is intended to be run *inside* the RunPod container
# after it has started and a GPU is available.

COMFYUI_DIR="/workspace/ComfyUI"
SAGE_ATTENTION_DIR_NAME="SageAttention"
SAGE_ATTENTION_REPO_URL="https://github.com/thu-ml/SageAttention.git"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"

echo "--- Starting Manual SageAttention Installation ---"

# 1. Ensure we are in the custom_nodes directory
mkdir -p "$CUSTOM_NODES_DIR"
cd "$CUSTOM_NODES_DIR"
echo "Changed directory to $CUSTOM_NODES_DIR"

# 2. Clone SageAttention if not already present
if [ ! -d "$SAGE_ATTENTION_DIR_NAME" ]; then
  echo "Cloning SageAttention repository..."
  git clone "$SAGE_ATTENTION_REPO_URL" "$SAGE_ATTENTION_DIR_NAME"
else
  echo "SageAttention directory already exists. Skipping clone."
  echo "If you need to update, please remove the directory and re-run."
fi

# 3. Install SageAttention in editable mode
if [ -d "$SAGE_ATTENTION_DIR_NAME" ]; then
  echo "Attempting to install SageAttention (editable mode)..."
  
  # Set environment variables that might be needed for the build
  # Adjust TORCH_CUDA_ARCH_LIST if your GPU requires different architectures
  # Common ones: 7.0 (V100), 7.5 (T4), 8.0 (A10), 8.6 (A100, RTX30xx), 8.9 (RTX40xx), 9.0 (H100)
  export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.6;8.9;9.0}" 
  export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}" # Default CUDA path in many images
  export LD_LIBRARY_PATH="${CUDA_HOME}/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  export PATH="${CUDA_HOME}/bin${PATH:+:${PATH}}"

  echo "Using environment:"
  echo "  TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST"
  echo "  CUDA_HOME=$CUDA_HOME"
  echo "  LD_LIBRARY_PATH (snippet)=${LD_LIBRARY_PATH:0:100}..." # Show a snippet
  echo "  PATH (snippet)=${PATH:0:100}..." # Show a snippet

  # Check if nvcc is available
  if ! command -v nvcc &> /dev/null
  then
      echo "WARNING: nvcc (NVIDIA CUDA Compiler) not found in PATH. The build might fail."
      echo "Ensure CUDA toolkit is correctly installed and PATH is set."
  else
      echo "nvcc found at: $(command -v nvcc)"
      nvcc --version
  fi

  # Check for NVIDIA SMI
  if ! command -v nvidia-smi &> /dev/null
  then
      echo "WARNING: nvidia-smi not found. Cannot confirm GPU presence programmatically from here."
  else
      echo "NVIDIA GPU detected by nvidia-smi:"
      nvidia-smi -L
  fi

  cd "$SAGE_ATTENTION_DIR_NAME"
  echo "Changed directory to $(pwd)"
  
  echo "Running: pip install -e ."
  pip install -e .
  
  if [ $? -eq 0 ]; then
    echo "SageAttention installed successfully."
  else
    echo "ERROR: SageAttention installation failed. Check output above."
    echo "You might need to ensure CUDA toolkit is fully installed and accessible,"
    echo "and that your GPU is compatible with the TORCH_CUDA_ARCH_LIST."
    exit 1
  fi
  cd "$CUSTOM_NODES_DIR" # Go back to custom_nodes
else
  echo "ERROR: SageAttention directory ($SAGE_ATTENTION_DIR_NAME) not found after attempting clone. Cannot install."
  exit 1
fi

echo "--- SageAttention Installation Script Finished ---"
echo "If successful, you may need to restart ComfyUI for the new node to be recognized."
exit 0
