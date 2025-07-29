#!/bin/bash

echo "--- wan2gp_install.sh: Starting Wan2GP installation ---"

# Ensure script exits on error
set -e

# Initialize conda for bash
eval "$(conda shell.bash hook)"

echo "📦 Installing Wan2GP..."

# Clone Wan2GP repository
if [ ! -d "Wan2GP" ]; then
    echo "🔄 Cloning Wan2GP repository..."
    git clone https://github.com/deepbeepmeep/Wan2GP.git
else
    echo "✅ Wan2GP directory already exists, skipping clone"
fi

cd Wan2GP

# Create conda environment
echo "🐍 Creating conda environment wan2gp..."
if conda env list | grep -q "wan2gp"; then
    echo "✅ Environment wan2gp already exists, activating it"
    conda activate wan2gp
else
    echo "🔄 Creating new conda environment..."
    conda create -n wan2gp python=3.10.9 -y
    conda activate wan2gp
fi

# Install PyTorch with CUDA support
echo "🔥 Installing PyTorch with CUDA support..."
pip install torch==2.7.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/test/cu124

# Install requirements
echo "📋 Installing requirements..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "⚠️ Warning: requirements.txt not found in Wan2GP directory"
fi

# Verify installation
echo "✅ Verifying installation..."
python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}')"

echo "🎉 Wan2GP installation completed successfully!"

cd /workspace
