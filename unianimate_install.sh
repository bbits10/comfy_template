#!/bin/bash

# Exit on error
set -e

# Source installation logger
source /workspace/comfy_template/installation_logger.sh 2>/dev/null || true

# --- Configuration ---
UNIANIMATE_DIR="/workspace/UniAnimate-DiT"
CONDA_DIR="/workspace/miniconda3"
ENV_NAME="UniAnimate-DiT"
INSTALL_SAGEATTENTION=${INSTALL_SAGEATTENTION:-"background"} # "true", "false", or "background"
INSTALL_MODELS=${INSTALL_MODELS:-"true"}

# --- Script Start ---
echo "=================================================="
echo "Starting UniAnimate-DiT Setup for RunPod"
echo "Following user requirements from unianiamte_requirement.txt"
echo "Conda Environment: $ENV_NAME"
echo "SageAttention Installation: $INSTALL_SAGEATTENTION"
echo "=================================================="
echo

# Log installation start
log_step "Starting UniAnimate-DiT installation and setup"
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
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
  bash miniconda.sh -b -p $CONDA_DIR
  rm miniconda.sh
  
  # Initialize conda for all shells
  $CONDA_DIR/bin/conda init bash
  $CONDA_DIR/bin/conda init zsh
  
  mark_completed "Miniconda installed"
  update_status "conda" "completed"
else
  echo_section "Miniconda already installed"
  mark_completed "Miniconda already present"
fi

# Source conda
source $CONDA_DIR/etc/profile.d/conda.sh

# 2. Create conda environment if it doesn't exist
if ! conda env list | grep -q "^$ENV_NAME "; then
  echo_section "Creating conda environment: $ENV_NAME"
  log_step "Creating conda environment with Python 3.10"
  update_status "environment" "creating"
  
  conda create -n $ENV_NAME python=3.10 -y
  mark_completed "Conda environment '$ENV_NAME' created"
  update_status "environment" "completed"
else
  echo_section "Conda environment '$ENV_NAME' already exists"
  mark_completed "Conda environment already present"
fi

# Activate the environment
echo_section "Activating conda environment"
conda activate $ENV_NAME

# 3. Clone or Update UniAnimate-DiT
if [ ! -d "$UNIANIMATE_DIR" ]; then
  echo_section "Cloning UniAnimate-DiT"
  log_step "Cloning UniAnimate-DiT repository"
  update_status "repository" "cloning"
  
  cd /workspace
  git clone https://github.com/TencentARC/UniAnimate-DiT.git "$UNIANIMATE_DIR"
  cd "$UNIANIMATE_DIR"
  mark_completed "UniAnimate-DiT repository cloned"
  update_status "repository" "completed"
else
  cd "$UNIANIMATE_DIR"
  if [ "$UPDATE_UNIANIMATE" = true ]; then
    echo_section "Updating UniAnimate-DiT"
    log_step "Updating UniAnimate-DiT repository"
    update_status "repository" "updating"
    
    git pull
    mark_completed "UniAnimate-DiT repository updated"
    update_status "repository" "completed"
  else
    echo_section "Skipping UniAnimate-DiT update"
    mark_completed "UniAnimate-DiT update skipped"
  fi
fi

# 4. Install PyTorch and dependencies
echo_section "Installing PyTorch and CUDA dependencies"
log_step "Installing PyTorch with CUDA 12.1 support"
update_status "pytorch" "installing"

conda install pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia -y

mark_completed "PyTorch with CUDA support installed"
update_status "pytorch" "completed"

# 5. Install UniAnimate-DiT requirements
echo_section "Installing UniAnimate-DiT requirements"
log_step "Installing Python dependencies from requirements.txt"
update_status "requirements" "installing"

if [ -f "requirements.txt" ]; then
  pip install -r requirements.txt
  mark_completed "Requirements.txt dependencies installed"
else
  echo "No requirements.txt found, installing common dependencies..."
  pip install accelerate transformers diffusers xformers imageio opencv-python pillow numpy scipy tqdm
  mark_completed "Common dependencies installed"
fi

update_status "requirements" "completed"

# 6. Install additional dependencies for video generation
echo_section "Installing additional video generation dependencies"
log_step "Installing video processing and generation tools"
update_status "video_deps" "installing"

pip install ffmpeg-python moviepy imageio-ffmpeg av decord
conda install -c conda-forge ffmpeg -y

mark_completed "Video generation dependencies installed"
update_status "video_deps" "completed"

# 7. Install SageAttention (Configurable - Performance Optimization)
if [ "$INSTALL_SAGEATTENTION" != "false" ]; then
  echo_section "Setting up SageAttention for Performance Optimization (mode: $INSTALL_SAGEATTENTION)"
  log_step "Setting up SageAttention for transformer acceleration"
  
  cd "$UNIANIMATE_DIR"
  if [ ! -d "SageAttention" ]; then
    echo "Cloning SageAttention repository..."
    git clone https://github.com/thu-ml/SageAttention.git
  else
    echo "SageAttention directory already exists. Updating..."
    (cd "SageAttention" && git pull)
  fi

  if [ "$INSTALL_SAGEATTENTION" = "background" ]; then
    # Create a background installation script
    cat > install_sageattention_unianimate.sh << 'EOF'
#!/bin/bash
echo "$(date): Starting SageAttention installation in background for UniAnimate-DiT..."
source /workspace/comfy_template/installation_logger.sh 2>/dev/null || true
log_step "SageAttention background installation started for UniAnimate-DiT"

# Activate conda environment
source /workspace/miniconda3/etc/profile.d/conda.sh
conda activate unianimate

cd /workspace/UniAnimate-DiT/SageAttention
echo "$(date): Installing SageAttention with conda environment activated..."
python setup.py install
mark_completed "SageAttention installation completed for UniAnimate-DiT"
update_status "sageattention" "completed"
echo "$(date): SageAttention installation completed for UniAnimate-DiT!" >> /workspace/sageattention_unianimate_install.log
EOF

    chmod +x install_sageattention_unianimate.sh
    echo "SageAttention will be installed in the background. Check /workspace/sageattention_unianimate_install.log for progress."
    log_step "Starting SageAttention installation in background for UniAnimate-DiT"
    nohup ./install_sageattention_unianimate.sh > /workspace/sageattention_unianimate_install.log 2>&1 &
    update_status "sageattention" "installing_background"
    mark_completed "SageAttention installation started in background"
  else
    # Install synchronously (original behavior)
    cd "SageAttention"
    echo "Installing SageAttention synchronously (this may take 15-20 minutes)..."
    log_step "Installing SageAttention synchronously for UniAnimate-DiT (15-20 minutes)"
    update_status "sageattention" "installing_sync"
    python setup.py install
    mark_completed "SageAttention installation completed synchronously"
    update_status "sageattention" "completed"
  fi

  cd "$UNIANIMATE_DIR" # Return to the main UniAnimate-DiT directory
else
  echo_section "Skipping SageAttention installation (INSTALL_SAGEATTENTION=false)"
  mark_completed "SageAttention installation skipped"
fi

# 8. Download models if requested
if [ "$INSTALL_MODELS" = "true" ]; then
  echo_section "Setting up model directories"
  log_step "Creating model directory structure"
  update_status "models" "preparing"
  
  mkdir -p models/checkpoints
  mkdir -p models/pretrained
  
  echo_section "Model Download Information"
  echo "Models need to be downloaded manually:"
  echo "1. Wan2.1-I2V-14B-720P model from HuggingFace"
  echo "2. UniAnimate-DiT checkpoints"
  echo "3. Place models in: $UNIANIMATE_DIR/models/"
  echo
  echo "Download commands will be available in the web interface."
  
  mark_completed "Model directories created - manual download required"
  update_status "models" "manual_required"
else
  echo_section "Skipping model download"
  mark_completed "Model download skipped"
fi

# 9. Create conda environment activation script
echo_section "Creating environment activation script"
log_step "Setting up automatic conda environment activation"
update_status "activation" "setting_up"

# Create a script that activates the environment
cat > /workspace/activate_unianimate.sh << 'EOF'
#!/bin/bash
# Activate UniAnimate-DiT conda environment
source /workspace/miniconda3/etc/profile.d/conda.sh
conda activate unianimate
echo "✅ UniAnimate-DiT conda environment activated"
echo "Current environment: $(conda info --envs | grep '*' | awk '{print $1}')"
echo "Python location: $(which python)"
echo "PyTorch version: $(python -c 'import torch; print(torch.__version__)')"
echo "CUDA available: $(python -c 'import torch; print(torch.cuda.is_available())')"
EOF

chmod +x /workspace/activate_unianimate.sh

# Update bashrc to auto-activate environment
if ! grep -q "source /workspace/activate_unianimate.sh" ~/.bashrc; then
  echo "" >> ~/.bashrc
  echo "# Auto-activate UniAnimate-DiT environment" >> ~/.bashrc
  echo "source /workspace/activate_unianimate.sh" >> ~/.bashrc
fi

mark_completed "Environment activation script created"
update_status "activation" "completed"

# 10. Create demo scripts
echo_section "Creating demo and utility scripts"
log_step "Setting up demo scripts and utilities"
update_status "demos" "creating"

# Create a simple test script
cat > $UNIANIMATE_DIR/test_installation.py << 'EOF'
#!/usr/bin/env python3
"""
Test script to verify UniAnimate-DiT installation
"""
import sys
import torch
import platform

def test_installation():
    print("=== UniAnimate-DiT Installation Test ===")
    print(f"Python version: {sys.version}")
    print(f"Platform: {platform.platform()}")
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    
    if torch.cuda.is_available():
        print(f"CUDA version: {torch.version.cuda}")
        print(f"GPU count: {torch.cuda.device_count()}")
        for i in range(torch.cuda.device_count()):
            print(f"GPU {i}: {torch.cuda.get_device_name(i)}")
    
    try:
        import diffusers
        print(f"Diffusers version: {diffusers.__version__}")
    except ImportError:
        print("❌ Diffusers not installed")
    
    try:
        import transformers
        print(f"Transformers version: {transformers.__version__}")
    except ImportError:
        print("❌ Transformers not installed")
    
    try:
        import accelerate
        print(f"Accelerate version: {accelerate.__version__}")
    except ImportError:
        print("❌ Accelerate not installed")
    
    print("=== Test completed ===")

if __name__ == "__main__":
    test_installation()
EOF

chmod +x $UNIANIMATE_DIR/test_installation.py

mark_completed "Demo scripts created"
update_status "demos" "completed"

# 11. Create web interface integration
echo_section "Setting up web interface integration"
log_step "Creating UniAnimate-DiT web interface components"
update_status "web_interface" "setting_up"

# Create a simple web interface for UniAnimate-DiT
cat > $UNIANIMATE_DIR/web_interface.py << 'EOF'
#!/usr/bin/env python3
"""
Simple web interface for UniAnimate-DiT
"""
import os
import subprocess
from flask import Flask, render_template, request, jsonify, send_file
import threading

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('unianimate_interface.html')

@app.route('/api/test-installation')
def test_installation():
    try:
        result = subprocess.run(['python', 'test_installation.py'], 
                              capture_output=True, text=True, cwd='/workspace/UniAnimate-DiT')
        return jsonify({
            'success': True,
            'output': result.stdout,
            'error': result.stderr
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

@app.route('/api/environment-info')
def environment_info():
    try:
        # Get conda environment info
        result = subprocess.run(['conda', 'info', '--envs'], 
                              capture_output=True, text=True)
        return jsonify({
            'conda_envs': result.stdout,
            'current_env': os.environ.get('CONDA_DEFAULT_ENV', 'Not in conda env')
        })
    except Exception as e:
        return jsonify({
            'error': str(e)
        })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8877, debug=True)
EOF

chmod +x $UNIANIMATE_DIR/web_interface.py

mark_completed "Web interface created"
update_status "web_interface" "completed"

# 12. Final setup and verification
echo_section "Final setup and verification"
log_step "Completing installation and running verification"
update_status "verification" "running"

# Test the installation
cd $UNIANIMATE_DIR
python test_installation.py

echo
echo "=================================================="
echo "UniAnimate-DiT Installation Completed Successfully!"
echo "=================================================="
echo "Installation Directory: $UNIANIMATE_DIR"
echo "Conda Environment: $ENV_NAME"
echo "Activation Script: /workspace/activate_unianimate.sh"
echo
echo "To activate the environment manually:"
echo "  source /workspace/miniconda3/etc/profile.d/conda.sh"
echo "  conda activate $ENV_NAME"
echo
echo "To test the installation:"
echo "  cd $UNIANIMATE_DIR"
echo "  python test_installation.py"
echo
echo "Web Interface will be available on port 8877"
echo "=================================================="

mark_completed "UniAnimate-DiT installation completed successfully"
update_status "overall" "completed"
update_status "verification" "completed"

# Log completion
log_step "UniAnimate-DiT installation and setup completed successfully"
