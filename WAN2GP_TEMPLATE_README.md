# Wan2GP RunPod Template

This template provides a complete Wan2GP environment for RunPod deployment.

## 🚀 Quick Start

### Building the Template

1. **Build the Docker image:**
   ```powershell
   .\build_wan2gp_template.ps1
   ```

2. **Test locally (optional):**
   ```bash
   docker run -p 8866:8866 -p 8888:8888 wan2gp-template:latest
   ```

3. **Push to registry:**
   ```bash
   docker tag wan2gp-template:latest your-registry/wan2gp-template:latest
   docker push your-registry/wan2gp-template:latest
   ```

## 📦 What's Included

- **Base Image**: RunPod PyTorch 2.8.0 with CUDA 12.8.1
- **Python Environment**: Conda environment with Python 3.10.9
- **Wan2GP**: Latest version from GitHub repository
- **PyTorch**: Version 2.7.0 with CUDA 12.4 support
- **File Manager**: Web-based interface for easy file management
- **JupyterLab**: For interactive development

## 🌐 Accessing Your Pod

Once deployed on RunPod:

1. **File Manager**: Access via port 8866
   - Web-based file browser and terminal
   - Upload/download files
   - Direct terminal access

2. **JupyterLab**: Access via port 8888
   - Interactive notebooks
   - Code development environment

## 🔧 Using Wan2GP

1. Access your pod's terminal through the file manager interface
2. Navigate to the Wan2GP directory:
   ```bash
   cd /workspace/Wan2GP
   ```
3. Activate the conda environment:
   ```bash
   conda activate wan2gp
   ```
4. Run your Wan2GP scripts and commands

## 📁 File Structure

```
/workspace/
├── Wan2GP/                 # Main Wan2GP repository
├── file_manager.py         # Web file manager
├── wan2gp_install.sh      # Installation script
└── start_services_wan2gp.sh # Service startup script
```

## 🔄 Pod Resume Support

The template supports RunPod's pod resume feature:
- Existing installations are preserved
- Quick startup on pod resume
- Automatic updates when available

## 🛠 Requirements

- Docker Desktop
- PowerShell (for build script)
- Registry access for pushing images

## 📋 Installation Commands

The template automatically runs these commands during setup:

```bash
git clone https://github.com/deepbeepmeep/Wan2GP.git
cd Wan2GP
conda create -n wan2gp python=3.10.9
conda activate wan2gp
pip install torch==2.7.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/test/cu124
pip install -r requirements.txt
```

## 🐛 Troubleshooting

1. **Build fails**: Check Docker is running and all required files are present
2. **Pod won't start**: Check the container logs in RunPod dashboard
3. **Services not accessible**: Ensure ports are properly exposed in RunPod configuration

## 🔗 Useful Links

- [Wan2GP Repository](https://github.com/deepbeepmeep/Wan2GP)
- [RunPod Documentation](https://docs.runpod.io/)
- [PyTorch Installation Guide](https://pytorch.org/get-started/locally/)
