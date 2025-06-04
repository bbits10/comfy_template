#!/bin/bash

# Create model directories
mkdir -p /workspace/ComfyUI/models/{checkpoints,clip,clip_vision,controlnet,diffusers,embeddings,loras,upscale_models,vae,unet,configs}

# Start Jupyter Notebook (no password, on port 8888)
jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' &

# Start the model downloader in the background
cd /workspace
python model_downloader.py &

# Start ComfyUI
cd /workspace/ComfyUI
python main.py --listen --port 8188 --preview-method auto &

# Ensure the process started
sleep 2
if ! pgrep -f "python.*main.py.*--port.*8188" > /dev/null; then
    echo "Failed to start ComfyUI"
    exit 1
fi

wait
