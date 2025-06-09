# Simple UniAnimate-DiT RunPod Template

A simplified template that focuses on the essentials for UniAnimate-DiT:

- ✅ Conda environment management with auto-activation
- ✅ SageAttention background installation (AFTER conda activation)
- ✅ File manager access to /workspace/UniAnimate-DiT
- ✅ No unnecessary GUI components
- ✅ Follows user requirements from `unianiamte_requirement.txt`

## 🚀 Key Features

### Essential Components Only

- **Conda Environment**: Proper `UniAnimate-DiT` environment with Python 3.10.16
- **SageAttention**: Installs in background AFTER conda activation (15-20min)
- **UniAnimate-DiT**: Direct installation with `pip install -e .`
- **File Manager**: Access scripts and files in UniAnimate-DiT directory
- **Auto-Activation**: Conda environment activates immediately when installation completes

### Installation Order (Fixed)

1. ✅ Install Miniconda
2. ✅ Create `UniAnimate-DiT` conda environment
3. ✅ **ACTIVATE conda environment first**
4. ✅ Install SageAttention (background, after activation)
5. ✅ Install UniAnimate-DiT with `pip install -e .`
6. ✅ Download models (optional)
7. ✅ Setup auto-activation

## 📁 Files Structure

### Core Installation

- `unianimate_install_simple.sh` - Simplified installation script
- `start_services_unianimate_simple.sh` - Simple service startup
- `Dockerfile.unianimate_simple` - Minimal Docker configuration

### Build Script

- `build_unianimate_simple.ps1` - PowerShell build script

## 🔧 Usage Instructions

### For RunPod Template Creation

1. **Upload files to RunPod template:**

   ```
   unianimate_install_simple.sh
   start_services_unianimate_simple.sh
   installation_logger.sh
   file_manager.py
   templates/
   ```

2. **Set Dockerfile content:**

   ```dockerfile
   FROM runpod/pytorch:2.2.0-py3.10-cuda12.1.1-devel-ubuntu22.04

   RUN apt-get update && apt-get install -y git wget curl vim htop tmux tree unzip build-essential && rm -rf /var/lib/apt/lists/*

   WORKDIR /workspace
   COPY unianimate_install_simple.sh /workspace/
   COPY start_services_unianimate_simple.sh /workspace/
   COPY installation_logger.sh /workspace/comfy_template/
   COPY file_manager.py /workspace/comfy_template/
   COPY templates/ /workspace/comfy_template/templates/

   RUN chmod +x /workspace/unianimate_install_simple.sh && chmod +x /workspace/start_services_unianimate_simple.sh

   RUN echo '#!/bin/bash\n/workspace/unianimate_install_simple.sh\n/workspace/start_services_unianimate_simple.sh' > /workspace/start.sh && chmod +x /workspace/start.sh

   ENV INSTALL_SAGEATTENTION=background
   ENV INSTALL_MODELS=true
   EXPOSE 8077
   CMD ["/workspace/start.sh"]
   ```

3. **Environment Variables:**
   - `INSTALL_SAGEATTENTION=background` (recommended)
   - `INSTALL_MODELS=true` (downloads models automatically)

### For Local Testing (if Docker Desktop available)

```powershell
# Navigate to template directory
cd e:\runpod\comfy_template

# Build the image
powershell -ExecutionPolicy Bypass -File build_unianimate_simple.ps1

# Run locally
docker run -p 8077:8077 unianimate-dit-simple:latest
```

## 🌐 Access Points

When the pod starts:

- **File Manager**: `http://your-pod-url:8077`
- **UniAnimate-DiT Directory**: Available via file manager at `/workspace/UniAnimate-DiT`
- **Conda Environment**: Auto-activates as `UniAnimate-DiT`

## 📊 Installation Progress

### Immediate Access

- File manager available immediately (no waiting for SageAttention)
- Conda environment activated and ready to use
- UniAnimate-DiT installed and accessible

### Background Process

- SageAttention compiles in background (15-20 minutes)
- Check progress: `tail -f /workspace/sageattention_install.log`
- No blocking of main services

## 🎯 Key Improvements from Complex Version

### Simplified Flow

- ❌ Removed unnecessary web interfaces
- ❌ Removed complex GUI components
- ❌ Removed redundant scripts
- ✅ Just conda + file manager (like flux_install)

### Fixed Installation Order

- 🔧 **FIXED**: SageAttention now installs AFTER conda activation
- 🔧 **FIXED**: Proper environment activation before pip installs
- 🔧 **FIXED**: Immediate conda activation when installation completes

### Matches User Requirements

- ✅ Follows exact pattern from `unianiamte_requirement.txt`
- ✅ Uses `pip install -e .` for both SageAttention and UniAnimate-DiT
- ✅ Creates `UniAnimate-DiT` environment (not `unianimate`)
- ✅ Python 3.10.16 (exact version)

## 🚨 Critical Fixes Applied

1. **SageAttention Timing**: Now installs AFTER conda environment activation
2. **Environment Activation**: Proper activation sequence before any pip installs
3. **Background Installation**: Uses correct environment in background script
4. **Auto-Activation**: Environment activates immediately when installation completes
5. **Simplified Structure**: Removed GUI complexity, focuses on essentials

## 📝 Manual Commands (if needed)

```bash
# Activate environment manually
source /workspace/activate_unianimate.sh

# Check SageAttention installation progress
tail -f /workspace/sageattention_install.log

# Navigate to UniAnimate-DiT
cd /workspace/UniAnimate-DiT

# Test installation
python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')"
```

This simplified template provides exactly what's needed: conda environment management, SageAttention background installation AFTER conda activation, file manager access, and immediate conda activation when installation completes. No unnecessary complexity.
