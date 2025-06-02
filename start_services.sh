#!/bin/bash

# Start the model downloader in the background
cd /workspace
python model_downloader.py &

# Start ComfyUI
cd /workspace/ComfyUI
python main.py --listen --port 8188 --preview-method auto
