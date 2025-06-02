from flask import Flask, render_template, request, jsonify
import os
import requests
from pathlib import Path
import threading
import json

app = Flask(__name__)

# Base directory for models
MODELS_BASE_DIR = "/workspace/ComfyUI/models"

# Model configurations
MODEL_CONFIGS = {
    "flux": {
        "name": "Flux Model Set",
        "models": {
            "t5xxl_fp16": {
                "name": "T5xXL FP16 Text Encoder",
                "url": "https://huggingface.co/vivi168/text_encoder/resolve/main/t5xxl_fp16.safetensors",
                "path": "text_encoders/t5xxl_fp16.safetensors"
            },
            "clip_l": {
                "name": "CLIP L Text Encoder",
                "url": "https://huggingface.co/vivi168/text_encoder/resolve/main/clip_l.safetensors",
                "path": "text_encoders/clip_I.safetensors"
            },
            "ae_vae": {
                "name": "Flux VAE",
                "url": "https://huggingface.co/vivi168/vae/resolve/main/ae.safetensors",
                "path": "vae/ae.safetensors"
            },
            "flux1_dev": {
                "name": "Flux Main Model",
                "url": "https://huggingface.co/vivi168/model/resolve/main/flux1-dev.safetensors",
                "path": "diffusion_models/flux1-dev.safetensors"
            }
        }
    },
    # "example_set": {  # Example of how to add a new model set
    #     "name": "Example Model Set",
    #     "models": {
    #         "model1": {
    #             "name": "Example Model 1",
    #             "url": "https://huggingface.co/example/model1/resolve/main/model1.safetensors",
    #             "path": "diffusion_models/model1.safetensors"
    #         },
    #         "model2": {
    #             "name": "Example Model 2",
    #             "url": "https://huggingface.co/example/model2/resolve/main/model2.safetensors",
    #             "path": "text_encoders/model2.safetensors"
    #         }
    #     }
    # }
    # Add more model sets here
}

# Store download status
download_status = {}

def download_file(url, destination):
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        total_size = int(response.headers.get('content-length', 0))
        
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        
        block_size = 1024  # 1 Kibibyte
        downloaded = 0
        
        with open(destination, 'wb') as f:
            for data in response.iter_content(block_size):
                downloaded += len(data)
                f.write(data)
                progress = int((downloaded / total_size) * 100) if total_size > 0 else 0
                download_status[destination] = {
                    'progress': progress,
                    'status': 'downloading'
                }
        
        download_status[destination] = {
            'progress': 100,
            'status': 'completed'
        }
        return True
    except Exception as e:
        download_status[destination] = {
            'progress': 0,
            'status': 'error',
            'error': str(e)
        }
        return False

@app.route('/')
def index():
    return render_template('index.html', model_configs=MODEL_CONFIGS)

@app.route('/download', methods=['POST'])
def start_download():
    model_id = request.form.get('model_id')
    model_set = request.form.get('model_set')
    
    if not model_id or not model_set or model_set not in MODEL_CONFIGS:
        return jsonify({'error': 'Invalid request'}), 400
    
    model_info = MODEL_CONFIGS[model_set]['models'].get(model_id)
    if not model_info:
        return jsonify({'error': 'Model not found'}), 404
    
    destination = os.path.join(MODELS_BASE_DIR, model_info['path'])
    
    if destination in download_status and download_status[destination]['status'] == 'downloading':
        return jsonify({'error': 'Download already in progress'}), 409
    
    thread = threading.Thread(target=download_file, args=(model_info['url'], destination))
    thread.daemon = True
    thread.start()
    
    return jsonify({'status': 'started', 'destination': destination})

@app.route('/status')
def get_status():
    return jsonify(download_status)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8866)
