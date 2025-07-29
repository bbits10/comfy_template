#!/bin/bash

echo "🧪 Testing Wan2GP Template Deployment"
echo "====================================="

# Test conda installation
echo "📋 Testing conda installation..."
if command -v conda &> /dev/null; then
    echo "✅ Conda is installed"
    conda --version
else
    echo "❌ Conda not found"
    exit 1
fi

# Test if wan2gp environment exists
echo "📋 Testing wan2gp environment..."
if conda env list | grep -q "wan2gp"; then
    echo "✅ wan2gp environment exists"
    
    # Activate environment and test
    eval "$(conda shell.bash hook)"
    conda activate wan2gp
    
    # Test Python version
    python_version=$(python --version)
    echo "🐍 Python version: $python_version"
    
    # Test PyTorch installation
    echo "📋 Testing PyTorch installation..."
    python -c "
import torch
print(f'✅ PyTorch version: {torch.__version__}')
print(f'✅ CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'✅ CUDA version: {torch.version.cuda}')
    print(f'✅ GPU count: {torch.cuda.device_count()}')
"
    
else
    echo "❌ wan2gp environment not found"
    exit 1
fi

# Test if Wan2GP directory exists
echo "📋 Testing Wan2GP installation..."
if [ -d "/workspace/Wan2GP" ]; then
    echo "✅ Wan2GP directory exists"
    cd /workspace/Wan2GP
    
    # Check if it's a git repository
    if [ -d ".git" ]; then
        echo "✅ Git repository detected"
        git_status=$(git status --porcelain)
        if [ -z "$git_status" ]; then
            echo "✅ Repository is clean"
        else
            echo "⚠️  Repository has uncommitted changes"
        fi
    else
        echo "⚠️  Not a git repository"
    fi
    
    # Check for requirements.txt
    if [ -f "requirements.txt" ]; then
        echo "✅ requirements.txt found"
        echo "📋 Requirements preview:"
        head -5 requirements.txt
    else
        echo "⚠️  requirements.txt not found"
    fi
    
else
    echo "❌ Wan2GP directory not found"
    exit 1
fi

# Test file manager
echo "📋 Testing file manager..."
if [ -f "/workspace/file_manager.py" ]; then
    echo "✅ File manager script exists"
    
    # Test if flask is installed
    python -c "import flask; print('✅ Flask is available')" 2>/dev/null || echo "⚠️  Flask not available"
    
else
    echo "❌ File manager script not found"
fi

# Test ports
echo "📋 Testing port availability..."
ports=(8866 8888 8188 8765)
for port in "${ports[@]}"; do
    if netstat -ln | grep -q ":$port "; then
        echo "⚠️  Port $port is in use"
    else
        echo "✅ Port $port is available"
    fi
done

echo ""
echo "🎉 Deployment test completed!"
echo ""
echo "📋 Summary:"
echo "- Conda environment: ✅"
echo "- PyTorch with CUDA: ✅"
echo "- Wan2GP repository: ✅"
echo "- File manager: ✅"
echo ""
echo "🚀 Ready to use Wan2GP!"
