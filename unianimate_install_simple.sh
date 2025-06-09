#!/bin/bash

# Exit on error
set -e

# Source installation logger
source /workspace/comfy_template/installation_logger.sh 2>/dev/null || true

# --- Configuration ---
CONDA_DIR="/workspace/miniconda3"
ENV_NAME="UniAnimate-DiT"
INSTALL_SAGEATTENTION=${INSTALL_SAGEATTENTION:-"background"} # "true", "false", or "background"
INSTALL_MODELS=${INSTALL_MODELS:-"true"}

# --- Script Start ---
echo "=================================================="
echo "Simple UniAnimate-DiT Setup for RunPod"
echo "Following user requirements from unianiamte_requirement.txt"
echo "Conda Environment: $ENV_NAME"
echo "SageAttention Installation: $INSTALL_SAGEATTENTION"
echo "=================================================="
echo

# Log installation start
log_step "Starting simplified UniAnimate-DiT installation"
update_status "overall" "starting"

echo_section() {
  echo
  echo "--- $1 ---"
}

# 1. Install Miniconda if not present
if [ ! -d "$CONDA_DIR" ]; then
  echo_section "Installing Miniconda"
  log_step "Downloading and installing Miniconda"
  update_status "conda" "installing"
  
  cd /workspace
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
  bash Miniconda3-latest-Linux-x86_64.sh -b -p /workspace/miniconda3
  
  # Add to PATH
  echo 'export PATH="/workspace/miniconda3/bin:$PATH"' >> ~/.bashrc
  export PATH="/workspace/miniconda3/bin:$PATH"
  
  mark_completed "Miniconda installed"
  update_status "conda" "completed"
else
  echo_section "Miniconda already installed"
  export PATH="/workspace/miniconda3/bin:$PATH"
  mark_completed "Miniconda already present"
fi

# Source bashrc and conda
source ~/.bashrc 2>/dev/null || true
source $CONDA_DIR/etc/profile.d/conda.sh 2>/dev/null || true
conda init

# 2. Create conda environment
echo_section "Creating conda environment: $ENV_NAME"
log_step "Creating conda environment with Python 3.10.16"
update_status "environment" "creating"

# Remove existing environment if it exists
conda env remove -n $ENV_NAME -y 2>/dev/null || true
conda create -n $ENV_NAME python=3.10.16 -y

# Activate environment (this is critical - must happen before any pip installs)
source ~/.bashrc 2>/dev/null || true
conda init
source ~/.bashrc 2>/dev/null || true
conda activate $ENV_NAME

echo "✅ Created and activated conda environment: $ENV_NAME"
echo "Current Python: $(which python)"

mark_completed "Conda environment '$ENV_NAME' created and activated"
update_status "environment" "completed"

# 3. Install SageAttention FIRST (per user requirements)
if [ "$INSTALL_SAGEATTENTION" != "false" ]; then
  echo_section "Installing SageAttention (mode: $INSTALL_SAGEATTENTION)"
  log_step "Installing SageAttention for transformer acceleration"
  
  cd /workspace
  if [ ! -d "SageAttention" ]; then
    echo "Cloning SageAttention repository..."
    git clone https://github.com/thu-ml/SageAttention.git
  else
    echo "SageAttention directory already exists."
  fi

  if [ "$INSTALL_SAGEATTENTION" = "background" ]; then
    # Create a background installation script
    cat > install_sageattention_simple.sh << 'EOF'
#!/bin/bash
echo "$(date): Starting SageAttention background installation..."
source /workspace/comfy_template/installation_logger.sh 2>/dev/null || true
log_step "SageAttention background installation started"

# Ensure conda environment is activated
export PATH="/workspace/miniconda3/bin:$PATH"
source ~/.bashrc 2>/dev/null || true
source /workspace/miniconda3/etc/profile.d/conda.sh 2>/dev/null || true
conda activate UniAnimate-DiT

cd /workspace/SageAttention
echo "$(date): Installing SageAttention with pip install -e ..."
pip install -e .

mark_completed "SageAttention installation completed in background"
update_status "sageattention" "completed"
echo "$(date): SageAttention installation completed!" >> /workspace/sageattention_install.log
EOF

    chmod +x install_sageattention_simple.sh
    echo "SageAttention will be installed in the background. Check /workspace/sageattention_install.log for progress."
    log_step "Starting SageAttention installation in background"
    nohup ./install_sageattention_simple.sh > /workspace/sageattention_install.log 2>&1 &
    update_status "sageattention" "installing_background"
    mark_completed "SageAttention installation started in background"
  else
    # Install synchronously
    cd SageAttention
    echo "Installing SageAttention synchronously (this may take 15-20 minutes)..."
    log_step "Installing SageAttention synchronously (15-20 minutes)"
    update_status "sageattention" "installing_sync"
    pip install -e .
    mark_completed "SageAttention installation completed synchronously"
    update_status "sageattention" "completed"
  fi
  
  cd /workspace
else
  echo_section "Skipping SageAttention installation"
  mark_completed "SageAttention installation skipped"
fi

# 4. Clone and install UniAnimate-DiT
echo_section "Installing UniAnimate-DiT"
log_step "Cloning and installing UniAnimate-DiT"
update_status "unianimate" "installing"

cd /workspace
if [ ! -d "UniAnimate-DiT" ]; then
  git clone https://github.com/ali-vilab/UniAnimate-DiT.git
else
  echo "UniAnimate-DiT directory already exists."
fi

cd UniAnimate-DiT
pip install -e .

mark_completed "UniAnimate-DiT cloned and installed"
update_status "unianimate" "completed"

# 5. Install HuggingFace CLI and download models (if requested)
if [ "$INSTALL_MODELS" = "true" ]; then
  echo_section "Installing HuggingFace CLI and downloading models"
  log_step "Installing HuggingFace CLI and downloading models"
  update_status "models" "installing"
  
  pip install "huggingface_hub[cli]"
  
  echo "Downloading Wan2.1-I2V-14B-720P model..."
  huggingface-cli download Wan-AI/Wan2.1-I2V-14B-720P --local-dir ./Wan2.1-I2V-14B-720P
  
  echo "Downloading UniAnimate-DiT checkpoints..."
  huggingface-cli download ZheWang123/UniAnimate-DiT --local-dir ./checkpoints
  
  mark_completed "Models downloaded successfully"
  update_status "models" "completed"
else
  echo_section "Skipping model download"
  mark_completed "Model download skipped"
fi

# 6. Create activation script for immediate conda activation
echo_section "Setting up auto-activation"
log_step "Setting up automatic conda environment activation"
update_status "activation" "setting_up"

# Create activation script
cat > /workspace/activate_unianimate.sh << 'EOF'
#!/bin/bash
# Auto-activate UniAnimate-DiT conda environment
export PATH="/workspace/miniconda3/bin:$PATH"
source ~/.bashrc 2>/dev/null || true
source /workspace/miniconda3/etc/profile.d/conda.sh 2>/dev/null || true
conda activate UniAnimate-DiT

echo "✅ UniAnimate-DiT conda environment activated"
echo "Current environment: $(conda info --envs | grep '*' | awk '{print $1}' 2>/dev/null || echo 'UniAnimate-DiT')"
echo "Python location: $(which python)"
echo "Working directory: /workspace/UniAnimate-DiT"
cd /workspace/UniAnimate-DiT
EOF

chmod +x /workspace/activate_unianimate.sh

# Update bashrc for immediate activation
if ! grep -q "activate_unianimate.sh" ~/.bashrc; then
  echo "" >> ~/.bashrc
  echo "# Auto-activate UniAnimate-DiT environment" >> ~/.bashrc
  echo "source /workspace/activate_unianimate.sh" >> ~/.bashrc
fi

mark_completed "Auto-activation script created"
update_status "activation" "completed"

# 7. Final verification
echo_section "Installation complete - Running verification"
log_step "Running final verification"
update_status "verification" "running"

cd /workspace/UniAnimate-DiT
echo "Testing Python imports..."
python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}')"

echo
echo "=================================================="
echo "✅ Simple UniAnimate-DiT Installation Completed!"
echo "=================================================="
echo "Installation Directory: /workspace/UniAnimate-DiT"
echo "Conda Environment: $ENV_NAME"
echo
echo "🔧 To activate environment manually:"
echo "  source /workspace/activate_unianimate.sh"
echo
echo "📁 File Manager: Access via web interface"
echo "📂 Working Directory: /workspace/UniAnimate-DiT"
echo
if [ "$INSTALL_SAGEATTENTION" = "background" ]; then
  echo "⏳ SageAttention installing in background"
  echo "   Check: tail -f /workspace/sageattention_install.log"
fi
echo "=================================================="

mark_completed "Simple UniAnimate-DiT installation completed successfully"
update_status "overall" "completed"
update_status "verification" "completed"

# Log completion
log_step "Simple UniAnimate-DiT installation completed successfully"

# Immediately activate the environment for this session
source /workspace/activate_unianimate.sh
