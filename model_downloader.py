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
                "path": "text_encoders/t5xxl_fp16.safetensors",
                "description": "Large text encoder for Flux models. Required for text-to-image tasks."
            },
            "clip_l": {
                "name": "CLIP L Text Encoder",
                "url": "https://huggingface.co/vivi168/text_encoder/resolve/main/clip_l.safetensors",
                "path": "text_encoders/clip_I.safetensors",
                "description": "CLIP-L text encoder for improved prompt understanding."
            },
            "ae_vae": {
                "name": "Flux VAE",
                "url": "https://huggingface.co/vivi168/vae/resolve/main/ae.safetensors",
                "path": "vae/ae.safetensors",
                "description": "Variational Autoencoder for Flux. Required for decoding images."
            },
            "flux1_dev": {
                "name": "Flux Main Model",
                "url": "https://huggingface.co/vivi168/model/resolve/main/flux1-dev.safetensors",
                "path": "diffusion_models/flux1-dev.safetensors",
                "description": "Main diffusion model weights for Flux."
            }
        }
    },
    "Wan2.1 Vace": {
        "name": "Wan Vace Model Set",
        "models": {
            "Wan_Vace_fp16": {
                "name": "Wan Vace 14B FP16",
                "url": "https://huggingface.co/QuantStack/Wan2.1-VACE-14B-GGUF/resolve/main/Wan2.1-VACE-14B-F16.gguf",
                "path": "unet/Wan2.1-VACE-14B-F16.gguf",
                "description": "Wan2.1 VACE 14B model in GGUF format (FP16). For advanced video tasks."
            },
            "wan_2.1_vae": {
                "name": "Wan 2.1 VAE",
                "url": "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors",
                "path": "vae/wan_2.1_vae.safetensors",
                "description": "VAE for Wan2.1. Required for decoding outputs."
            },
            "umt5_xxl_fp16": {
                "name": "UMT5 XXL FP16 Text Encoder",
                "url": "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors",
                "path": "text_encoders/umt5_xxl_fp16.safetensors",
                "description": "UMT5 XXL text encoder for Wan2.1."
            },
            "wan21_causvid_14b_t2v_lora_rank32": {
                "name": "Wan21 CausVid 14B T2V LoRA Rank32",
                "url": "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_CausVid_14B_T2V_lora_rank32.safetensors",
                "path": "lora/Wan21_CausVid_14B_T2V_lora_rank32.safetensors",
                "description": "LoRA for Wan2.1 CausVid 14B T2V. For video-to-video tasks."
            }
        }
    }
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

@app.route('/get_model_configs')
def get_model_configs():
    return jsonify(MODEL_CONFIGS)

@app.route('/add_model', methods=['POST'])
def add_model():
    data = request.json
    model_set = data.get('model_set')
    model_id = data.get('model_id')
    model_info = data.get('model_info')
    new_group = data.get('new_group', False)
    new_group_name = data.get('new_group_name', None)
    if not model_set or not model_id or not model_info:
        return jsonify({'error': 'Missing fields'}), 400
    if new_group:
        if not new_group_name:
            return jsonify({'error': 'New group name required'}), 400
        if model_set in MODEL_CONFIGS:
            return jsonify({'error': 'Group already exists'}), 409
        MODEL_CONFIGS[model_set] = {
            'name': new_group_name,
            'models': {model_id: model_info}
        }
    else:
        if model_set not in MODEL_CONFIGS:
            return jsonify({'error': 'Model set not found'}), 404
        if model_id in MODEL_CONFIGS[model_set]['models']:
            return jsonify({'error': 'Model ID already exists'}), 409
        MODEL_CONFIGS[model_set]['models'][model_id] = model_info
    save_model_configs(MODEL_CONFIGS)
    return jsonify({'status': 'added'})

@app.route('/edit_model', methods=['POST'])
def edit_model():
    data = request.json
    model_set = data.get('model_set')
    model_id = data.get('model_id')
    model_info = data.get('model_info')
    if not model_set or not model_id or not model_info:
        return jsonify({'error': 'Missing fields'}), 400
    # Find the current group containing this model (in case group is changed)
    old_group = None
    for group, group_data in MODEL_CONFIGS.items():
        if model_id in group_data['models']:
            old_group = group
            break
    if old_group is None:
        return jsonify({'error': 'Model ID not found in any group'}), 404
    # If group changed, move the model
    if old_group != model_set:
        # Don't overwrite if model_id already exists in new group
        if model_id in MODEL_CONFIGS[model_set]['models']:
            return jsonify({'error': 'Model ID already exists in target group'}), 409
        MODEL_CONFIGS[model_set]['models'][model_id] = model_info
        del MODEL_CONFIGS[old_group]['models'][model_id]
    else:
        MODEL_CONFIGS[model_set]['models'][model_id] = model_info
    save_model_configs(MODEL_CONFIGS)
    return jsonify({'status': 'edited'})

@app.route('/delete_model', methods=['POST'])
def delete_model():
    data = request.json
    model_set = data.get('model_set')
    model_id = data.get('model_id')
    if not model_set or not model_id:
        return jsonify({'error': 'Missing fields'}), 400
    if model_set not in MODEL_CONFIGS:
        return jsonify({'error': 'Model set not found'}), 404
    if model_id not in MODEL_CONFIGS[model_set]['models']:
        return jsonify({'error': 'Model ID not found'}), 404
    del MODEL_CONFIGS[model_set]['models'][model_id]
    save_model_configs(MODEL_CONFIGS)
    return jsonify({'status': 'deleted'})

CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'model_configs.json')

def load_model_configs():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return MODEL_CONFIGS

def save_model_configs(configs):
    with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
        json.dump(configs, f, indent=2)

MODEL_CONFIGS = load_model_configs()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8866)
