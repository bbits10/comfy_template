#!/bin/bash

# Simple startup script for UniAnimate-DiT
echo "Starting UniAnimate-DiT services..."

# Source logging functions
source /workspace/comfy_template/installation_logger.sh 2>/dev/null || true

# Background installation check
if pgrep -f "install_sageattention_simple.sh" > /dev/null; then
    echo "⏳ SageAttention installation still running in background..."
    echo "   Check progress: tail -f /workspace/sageattention_install.log"
fi

# Start file manager with UniAnimate-DiT support
echo "Starting File Manager..."
cd /workspace/comfy_template
python file_manager.py &
FILE_MANAGER_PID=$!

# Wait a moment for services to start
sleep 2

echo
echo "🚀 UniAnimate-DiT Services Started!"
echo "=================================="
echo "📁 File Manager: http://localhost:8077"
echo "🔧 UniAnimate-DiT Dir: /workspace/UniAnimate-DiT"
echo
echo "💡 To activate conda environment:"
echo "   source /workspace/activate_unianimate.sh"
echo
if [ -f "/workspace/sageattention_install.log" ]; then
  echo "📊 SageAttention install status:"
  echo "   tail -f /workspace/sageattention_install.log"
fi
echo "=================================="

# Keep services running
wait $FILE_MANAGER_PID
