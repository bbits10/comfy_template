#!/bin/bash

# This script is intended to be run *inside* the RunPod container
# after it has started and a GPU is available.
# Updated for SageAttention 2.1.1 (June 2025)

COMFYUI_DIR="/workspace/ComfyUI"
SAGE_ATTENTION_DIR_NAME="SageAttention"
SAGE_ATTENTION_REPO_URL="https://github.com/thu-ml/SageAttention.git"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"

echo "--- Starting Manual SageAttention 2.1.1 Installation ---"

# Check base requirements
echo "Checking base requirements..."
python_version=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
echo "Python version: $python_version"

# Check PyTorch version
torch_version=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null || echo "not installed")
echo "PyTorch version: $torch_version"

# Check Triton version  
triton_version=$(python3 -c "import triton; print(triton.__version__)" 2>/dev/null || echo "not installed")
echo "Triton version: $triton_version"

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
  # Updated CUDA requirements for SageAttention 2.1.1:
  # >=12.8 for Blackwell, >=12.4 for Ada fp8, >=12.3 for Hopper fp8, >=12.0 for Ampere
  # Common architectures: 7.0 (V100), 7.5 (T4), 8.0 (A10), 8.6 (A100, RTX30xx), 8.9 (RTX40xx), 9.0 (H100)
  export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-7.5;8.0;8.6;8.9;9.0}" 
  export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
  export LD_LIBRARY_PATH="${CUDA_HOME}/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  export PATH="${CUDA_HOME}/bin${PATH:+:${PATH}}"

  echo "Using environment:"
  echo "  TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST"
  echo "  CUDA_HOME=$CUDA_HOME"
  echo "  LD_LIBRARY_PATH (snippet)=${LD_LIBRARY_PATH:0:100}..."
  echo "  PATH (snippet)=${PATH:0:100}..."

  # Check CUDA version compatibility
  if command -v nvcc &> /dev/null; then
      echo "nvcc found at: $(command -v nvcc)"
      cuda_version=$(nvcc --version | grep "release" | sed 's/.*release //' | sed 's/,.*//')
      echo "CUDA version: $cuda_version"
      
      # Check minimum CUDA requirements
      if [[ $(echo "$cuda_version >= 12.0" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
          echo "✓ CUDA version meets minimum requirement (>=12.0)"
      else
          echo "⚠️  WARNING: CUDA version may be too old. SageAttention 2.1.1 requires CUDA >=12.0"
      fi
  else
      echo "WARNING: nvcc (NVIDIA CUDA Compiler) not found in PATH. The build might fail."
      echo "Ensure CUDA toolkit is correctly installed and PATH is set."
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
  
  # Use the recommended installation method for SageAttention 2.1.1
  echo "Running: python setup.py install"
  python setup.py install
  
  if [ $? -eq 0 ]; then
    echo "✓ SageAttention 2.1.1 installed successfully."
    echo "Testing import..."
    python -c "from sageattention import sageattn; print('✓ SageAttention import successful')" || echo "⚠️  Import test failed"
  else
    echo "ERROR: SageAttention installation failed. Check output above."
    echo "Troubleshooting tips:"
    echo "1. Ensure CUDA toolkit >=12.0 is installed"
    echo "2. Verify PyTorch >=2.3.0 and Triton >=3.0.0"
    echo "3. Check that your GPU is compatible with TORCH_CUDA_ARCH_LIST"
    echo "4. Try: pip install triton>=3.0.0 torch>=2.3.0"
    exit 1
  fi
  cd "$CUSTOM_NODES_DIR" # Go back to custom_nodes
else
  echo "ERROR: SageAttention directory ($SAGE_ATTENTION_DIR_NAME) not found after attempting clone. Cannot install."
  exit 1
fi

echo "--- SageAttention 2.1.1 Installation Script Finished ---"
echo "If successful, you may need to restart ComfyUI for the new node to be recognized."
echo ""
echo "Usage in ComfyUI:"
echo "  The SageAttention nodes should now be available in the ComfyUI node menu."
echo "  Look for attention-related nodes that support quantized attention."
echo ""
echo "Manual testing:"
echo "  python -c \"from sageattention import sageattn; print('SageAttention ready!')\""
exit 0
