#!/bin/bash

# Start Jupyter Notebook (no password, on port 8888)
jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' &

# Start the model downloader in the background
cd /workspace
python model_downloader.py &

# Start ComfyUI
cd /workspace/ComfyUI
python main.py --listen --port 8188 --preview-method auto
