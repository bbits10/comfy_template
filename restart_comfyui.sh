#!/bin/bash
# Manual ComfyUI restart script for RunPod

echo "=== ComfyUI Restart Script ==="

# Find ComfyUI process
COMFY_PID=$(pgrep -f "python.*main.py.*--listen.*--port.*8188" || echo "")

if [ ! -z "$COMFY_PID" ]; then
    echo "Found ComfyUI running (PID: $COMFY_PID)"
    echo "Stopping ComfyUI..."
    kill $COMFY_PID
    
    # Wait for process to stop
    sleep 5
    
    # Check if process is still running
    if kill -0 $COMFY_PID 2>/dev/null; then
        echo "Process still running, force killing..."
        kill -9 $COMFY_PID
        sleep 2
    fi
    
    echo "ComfyUI stopped successfully"
else
    echo "ComfyUI is not currently running"
fi

# Start ComfyUI
echo "Starting ComfyUI..."
cd /workspace/ComfyUI

# Start in background
nohup python main.py --listen --port 8188 --preview-method auto > /workspace/comfyui.log 2>&1 &
NEW_PID=$!

echo "ComfyUI started with PID: $NEW_PID"
echo "ComfyUI will be available at port 8188"
echo "Check logs: tail -f /workspace/comfyui.log"
echo "Check if running: ps aux | grep $NEW_PID"

# Wait a moment and check if it started successfully
sleep 3
if kill -0 $NEW_PID 2>/dev/null; then
    echo "✅ ComfyUI is running successfully!"
    echo "🌐 Access it through your RunPod's HTTP service on port 8188"
else
    echo "❌ ComfyUI failed to start. Check logs: cat /workspace/comfyui.log"
fi
