from flask import Flask, render_template, request, jsonify
import os
import requests
from pathlib import Path
import threading
import json
import time
import fcntl
from datetime import datetime

app = Flask(__name__)

# Base directory for models
MODELS_BASE_DIR = "/workspace/ComfyUI/models"

# Persistent download status file
DOWNLOAD_STATUS_FILE = "/workspace/.download_status.json"

# Default model configurations (used only if model_configs.json doesn't exist)
DEFAULT_MODEL_CONFIGS = {
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
        "path": "text_encoders/clip_l.safetensors",
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
      },
      "t5xxl_fp8_e4m3fn_scaled": {
        "name": "T5xXL FP8 E4M3FN Scaled Text Encoder",
        "url": "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn_scaled.safetensors",
        "path": "text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors",
        "description": "T5xXL FP8 E4M3FN scaled text encoder for Flux models."
      },
      "t5xxl_fp8_e4m3fn": {
        "name": "T5xXL FP8 E4M3FN Text Encoder",
        "url": "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors",
        "path": "text_encoders/t5xxl_fp8_e4m3fn.safetensors",
        "description": "T5xXL FP8 E4M3FN text encoder for Flux models."
      }
    }
  },
  "Wan2.1 Vace": {
    "name": "Wan Vace Model Set",
    "models": {
      "Wan_Vace_F16": {
        "name": "Wan Vace 14B FP16",
        "url": "https://huggingface.co/vivi168/model/resolve/main/Wan2.1_14B_VACE-BF16.gguf",
        "path": "unet/Wan2.1-VACE-14B-F16.gguf",
        "description": "Wan2.1 VACE 14B model in GGUF format (FP16). For advanced video tasks."
      },
      "Wan_Vace_BF16": {
        "name": "Wan Vace 14B BF16",
        "url": "https://huggingface.co/QuantStack/Wan2.1_14B_VACE-GGUF/resolve/main/Wan2.1_14B_VACE-BF16.gguf",
        "path": "unet/Wan2.1-VACE-14B-FB16.gguf",
        "description": "Wan2.1 VACE 14B model in GGUF format (BF16). For advanced video tasks."
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
        "path": "loras/Wan21_CausVid_14B_T2V_lora_rank32.safetensors",
        "description": "LoRA for Wan2.1 CausVid 14B T2V. For video-to-video tasks."
      },
      "wan21_causvid_14b_t2v_lora_rank32_v2": {
        "name": "Wan21 CausVid 14B T2V LoRA Rank32 v2",
        "url": "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_CausVid_14B_T2V_lora_rank32_v2.safetensors",
        "path": "loras/Wan21_CausVid_14B_T2V_lora_rank32_v2.safetensors",
        "description": "LoRA v2 for Wan2.1 CausVid 14B T2V. For video-to-video tasks."
      },
      "Wan2.1-VACE-14B-Q8_0": {
        "name": "Wan2.1-VACE-14B-Q8_0",
        "url": "https://huggingface.co/QuantStack/Wan2.1_14B_VACE-GGUF/resolve/main/Wan2.1_14B_VACE-Q8_0.gguf",
        "path": "unet/Wan2.1-VACE-14B-Q8_0.gguf",
        "description": "Wan2.1-VACE-14B-Q8_0"
      },
      "Wan2_1-VACE_module_14B_bf16": {
        "name": "Wan2.1-VACE Module 14B BF16",
        "url": "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-VACE_module_14B_bf16.safetensors",
        "path": "unet/Wan2_1-VACE_module_14B_bf16.safetensors",
        "description": "Wan2.1-VACE module 14B in BF16 format."
      },
      "Wan2_1-VACE_module_14B_fp8_e4m3fn": {
        "name": "Wan2.1-VACE Module 14B FP8 E4M3FN",
        "url": "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-VACE_module_14B_fp8_e4m3fn.safetensors",
        "path": "unet/Wan2_1-VACE_module_14B_fp8_e4m3fn.safetensors",
        "description": "Wan2.1-VACE module 14B in FP8 E4M3FN format."
      },
      "Wan21_AccVid_I2V_480P_14B_lora_rank32_fp16": {
        "name": "Wan21 AccVid I2V 480P 14B LoRA Rank32 FP16",
        "url": "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_AccVid_I2V_480P_14B_lora_rank32_fp16.safetensors",
        "path": "lora/Wan21_AccVid_I2V_480P_14B_lora_rank32_fp16.safetensors",
        "description": "LoRA for Wan21 AccVid I2V 480P 14B, Rank32, FP16."
      },
      "Wan2_1-I2V-ATI-14B_fp16": {
        "name": "Wan2.1 I2V ATI 14B FP16",
        "url": "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-ATI-14B_fp16.safetensors",
        "path": "unet/Wan2_1-I2V-ATI-14B_fp16.safetensors",
        "description": "Wan2.1 I2V ATI 14B model in FP16 format."
      },
      "Wan2_1-I2V-ATI-14B_fp8_e4m3fn": {
        "name": "Wan2.1 I2V ATI 14B FP8 E4M3FN",
        "url": "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-ATI-14B_fp8_e4m3fn.safetensors",
        "path": "unet/Wan2_1-I2V-ATI-14B_fp8_e4m3fn.safetensors",
        "description": "Wan2.1 I2V ATI 14B model in FP8 E4M3FN format."
      },
      "Wan2_1-I2V-ATI-14B_fp8_e5m2": {
        "name": "Wan2.1 I2V ATI 14B FP8 E5M2",
        "url": "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-ATI-14B_fp8_e5m2.safetensors",
        "path": "unet/Wan2_1-I2V-ATI-14B_fp8_e5m2.safetensors",
        "description": "Wan2.1 I2V ATI 14B model in FP8 E5M2 format."
      }
    }
  },
  
  "Hi-Dream": {
    "name": "Hi-Dream Model Set",
    "models": {
      "hidream_e1_full_bf16": {
        "name": "HiDream E1 Full BF16",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_e1_full_bf16.safetensors",
        "path": "diffusion_models/hidream_e1_full_bf16.safetensors",
        "description": "HiDream E1 full model in BF16 format (34.2 GB). High-quality image generation."
      },
      "hidream_i1_dev_bf16": {
        "name": "HiDream I1 Dev BF16",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_dev_bf16.safetensors",
        "path": "diffusion_models/hidream_i1_dev_bf16.safetensors",
        "description": "HiDream I1 development model in BF16 format (34.2 GB). Balanced quality and performance."
      },
      "hidream_i1_dev_fp8": {
        "name": "HiDream I1 Dev FP8",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_dev_fp8.safetensors",
        "path": "diffusion_models/hidream_i1_dev_fp8.safetensors",
        "description": "HiDream I1 development model in FP8 format (17.1 GB). Smaller size with good quality."
      },
      "hidream_i1_fast_bf16": {
        "name": "HiDream I1 Fast BF16",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_fast_bf16.safetensors",
        "path": "diffusion_models/hidream_i1_fast_bf16.safetensors",
        "description": "HiDream I1 fast model in BF16 format (34.2 GB). Optimized for faster generation."
      },
      "hidream_i1_fast_fp8": {
        "name": "HiDream I1 Fast FP8",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_fast_fp8.safetensors",
        "path": "diffusion_models/hidream_i1_fast_fp8.safetensors",
        "description": "HiDream I1 fast model in FP8 format (17.1 GB). Fastest generation with smaller size."
      },
      "hidream_i1_full_fp16": {
        "name": "HiDream I1 Full FP16",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_full_fp16.safetensors",
        "path": "diffusion_models/hidream_i1_full_fp16.safetensors",
        "description": "HiDream I1 full model in FP16 format (34.2 GB). Maximum quality and detail."
      },
      "hidream_i1_full_fp8": {
        "name": "HiDream I1 Full FP8",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_full_fp8.safetensors",
        "path": "diffusion_models/hidream_i1_full_fp8.safetensors",
        "description": "HiDream I1 full model in FP8 format (17.1 GB). High quality with reduced file size."
      },
      "clip_g_hidream": {
        "name": "CLIP-G HiDream Text Encoder",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/clip_g_hidream.safetensors",
        "path": "text_encoders/clip_g_hidream.safetensors",
        "description": "CLIP-G text encoder for HiDream models (1.39 GB). Required for text understanding."
      },
      "clip_l_hidream": {
        "name": "CLIP-L HiDream Text Encoder",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/clip_l_hidream.safetensors",
        "path": "text_encoders/clip_l_hidream.safetensors",
        "description": "CLIP-L text encoder for HiDream models (248 MB). Required for text understanding."
      },
      "llama_3_1_8b_instruct_fp8_scaled": {
        "name": "Llama 3.1 8B Instruct FP8 Scaled",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors",
        "path": "text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors",
        "description": "Llama 3.1 8B Instruct text encoder in FP8 format (9.08 GB). Advanced text understanding."
      },
      "t5xxl_fp8_e4m3fn_scaled_hidream": {
        "name": "T5XXL FP8 E4M3FN Scaled (HiDream)",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors",
        "path": "text_encoders/t5xxl_fp8_e4m3fn_scaled_hidream.safetensors",
        "description": "T5XXL FP8 E4M3FN scaled text encoder for HiDream (5.16 GB). High-quality text encoding."
      },
      "ae_hidream": {
        "name": "HiDream VAE",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/vae/ae.safetensors",
        "path": "vae/ae_hidream.safetensors",
        "description": "HiDream Variational Autoencoder (335 MB). Required for encoding/decoding images."      }
    }
  },
  
  "Hi-Dream": {
    "name": "Hi-Dream Model Set",
    "models": {
      "hidream_e1_full_bf16": {
        "name": "HiDream E1 Full BF16",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_e1_full_bf16.safetensors",
        "path": "diffusion_models/hidream_e1_full_bf16.safetensors",
        "description": "HiDream E1 full model in BF16 format (34.2 GB). High-quality image generation."
      },
      "hidream_i1_dev_bf16": {
        "name": "HiDream I1 Dev BF16",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_dev_bf16.safetensors",
        "path": "diffusion_models/hidream_i1_dev_bf16.safetensors",
        "description": "HiDream I1 development model in BF16 format (34.2 GB). Balanced quality and performance."
      },
      "hidream_i1_dev_fp8": {
        "name": "HiDream I1 Dev FP8",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_dev_fp8.safetensors",
        "path": "diffusion_models/hidream_i1_dev_fp8.safetensors",
        "description": "HiDream I1 development model in FP8 format (17.1 GB). Smaller size with good quality."
      },
      "hidream_i1_fast_bf16": {
        "name": "HiDream I1 Fast BF16",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_fast_bf16.safetensors",
        "path": "diffusion_models/hidream_i1_fast_bf16.safetensors",
        "description": "HiDream I1 fast model in BF16 format (34.2 GB). Optimized for faster generation."
      },
      "hidream_i1_fast_fp8": {
        "name": "HiDream I1 Fast FP8",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_fast_fp8.safetensors",
        "path": "diffusion_models/hidream_i1_fast_fp8.safetensors",
        "description": "HiDream I1 fast model in FP8 format (17.1 GB). Fastest generation with smaller size."
      },
      "hidream_i1_full_fp16": {
        "name": "HiDream I1 Full FP16",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_full_fp16.safetensors",
        "path": "diffusion_models/hidream_i1_full_fp16.safetensors",
        "description": "HiDream I1 full model in FP16 format (34.2 GB). Maximum quality and detail."
      },
      "hidream_i1_full_fp8": {
        "name": "HiDream I1 Full FP8",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_full_fp8.safetensors",
        "path": "diffusion_models/hidream_i1_full_fp8.safetensors",
        "description": "HiDream I1 full model in FP8 format (17.1 GB). High quality with reduced file size."
      },
      "clip_g_hidream": {
        "name": "CLIP-G HiDream Text Encoder",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/clip_g_hidream.safetensors",
        "path": "text_encoders/clip_g_hidream.safetensors",
        "description": "CLIP-G text encoder for HiDream models (1.39 GB). Required for text understanding."
      },
      "clip_l_hidream": {
        "name": "CLIP-L HiDream Text Encoder",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/clip_l_hidream.safetensors",
        "path": "text_encoders/clip_l_hidream.safetensors",
        "description": "CLIP-L text encoder for HiDream models (248 MB). Required for text understanding."
      },
      "llama_3_1_8b_instruct_fp8_scaled": {
        "name": "Llama 3.1 8B Instruct FP8 Scaled",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors",
        "path": "text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors",
        "description": "Llama 3.1 8B Instruct text encoder in FP8 format (9.08 GB). Advanced text understanding."
      },
      "t5xxl_fp8_e4m3fn_scaled_hidream": {
        "name": "T5XXL FP8 E4M3FN Scaled (HiDream)",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors",
        "path": "text_encoders/t5xxl_fp8_e4m3fn_scaled_hidream.safetensors",
        "description": "T5XXL FP8 E4M3FN scaled text encoder for HiDream (5.16 GB). High-quality text encoding."
      },
      "ae_hidream": {
        "name": "HiDream VAE",
        "url": "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/vae/ae.safetensors",
        "path": "vae/ae_hidream.safetensors",
        "description": "HiDream Variational Autoencoder (335 MB). Required for encoding/decoding images."
      }
    }
  }
}


# Store download status (in memory and persisted)
download_status = {}
download_lock = threading.Lock()

def load_download_status():
    """Load download status from persistent storage"""
    global download_status
    try:
        if os.path.exists(DOWNLOAD_STATUS_FILE):
            with open(DOWNLOAD_STATUS_FILE, 'r') as f:
                loaded_status = json.load(f)
                # Clean up completed/error downloads older than 24 hours
                current_time = time.time()
                for dest, status in list(loaded_status.items()):
                    if status.get('status') in ['completed', 'error']:
                        if current_time - status.get('timestamp', 0) > 86400:  # 24 hours
                            del loaded_status[dest]
                download_status = loaded_status
                print(f"Loaded {len(download_status)} download status entries")
    except Exception as e:
        print(f"Error loading download status: {e}")
        download_status = {}

def save_download_status():
    """Save download status to persistent storage"""
    try:
        with open(DOWNLOAD_STATUS_FILE, 'w') as f:
            json.dump(download_status, f, indent=2)
    except Exception as e:
        print(f"Error saving download status: {e}")

def update_download_status(destination, status_update):
    """Thread-safe update of download status with persistence"""
    with download_lock:
        if destination not in download_status:
            download_status[destination] = {}
        
        download_status[destination].update(status_update)
        download_status[destination]['timestamp'] = time.time()
        
        # Save to disk every update
        save_download_status()

def cleanup_stale_downloads():
    """Clean up downloads that appear to be stale/orphaned"""
    with download_lock:
        current_time = time.time()
        to_remove = []
        
        for dest, status in download_status.items():
            if status.get('status') == 'downloading':
                # Check if download has been stale for more than 10 minutes
                if current_time - status.get('timestamp', 0) > 600:
                    to_remove.append(dest)
        
        for dest in to_remove:
            download_status[dest]['status'] = 'error'
            download_status[dest]['error'] = 'Download appears to have stalled'
            print(f"Marked stale download as error: {dest}")
        
        if to_remove:
            save_download_status()

# Load existing download status on startup
load_download_status()
cleanup_stale_downloads()

# Configuration file path
CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'model_configs.json')

def download_file(url, destination):
    try:
        # Initialize download status
        update_download_status(destination, {
            'progress': 0,
            'status': 'starting',
            'url': url,
            'start_time': time.time(),
            'file_size': 0,
            'downloaded': 0
        })
        
        response = requests.get(url, stream=True)
        response.raise_for_status()
        total_size = int(response.headers.get('content-length', 0))
        
        # Update with file size info
        update_download_status(destination, {
            'status': 'downloading',
            'file_size': total_size
        })
        
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        
        block_size = 8192  # 8KB blocks for better performance
        downloaded = 0
        start_time = time.time()
        
        with open(destination, 'wb') as f:
            for data in response.iter_content(block_size):
                downloaded += len(data)
                f.write(data)
                
                current_time = time.time()
                elapsed_time = current_time - start_time
                
                progress = int((downloaded / total_size) * 100) if total_size > 0 else 0
                
                # Calculate speed and ETA
                speed = downloaded / elapsed_time if elapsed_time > 0 else 0
                eta = (total_size - downloaded) / speed if speed > 0 and total_size > 0 else 0
                
                # Update status every 1% or every 5 seconds, whichever comes first
                if progress > download_status.get(destination, {}).get('progress', 0) or \
                   current_time - download_status.get(destination, {}).get('timestamp', 0) > 5:
                    
                    update_download_status(destination, {
                        'progress': progress,
                        'status': 'downloading',
                        'downloaded': downloaded,
                        'speed': speed,
                        'eta': eta
                    })
        
        # Mark as completed
        update_download_status(destination, {
            'progress': 100,
            'status': 'completed',
            'downloaded': downloaded,
            'completion_time': time.time()
        })
        print(f"Download completed: {destination}")
        return True
        
    except Exception as e:
        error_msg = str(e)
        print(f"Download error for {destination}: {error_msg}")
        update_download_status(destination, {
            'progress': 0,
            'status': 'error',
            'error': error_msg
        })
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
    
    # Check if file already exists
    if os.path.exists(destination):
        file_size = os.path.getsize(destination)
        update_download_status(destination, {
            'progress': 100,
            'status': 'completed',
            'downloaded': file_size,
            'file_size': file_size
        })
        return jsonify({'status': 'already_exists', 'destination': destination})
    
    # Check if download is already in progress
    current_status = download_status.get(destination, {})
    if current_status.get('status') == 'downloading':
        return jsonify({'error': 'Download already in progress'}), 409
    
    # Start new download
    thread = threading.Thread(target=download_file, args=(model_info['url'], destination))
    thread.daemon = True
    thread.start()
    
    return jsonify({'status': 'started', 'destination': destination})

@app.route('/status')
def get_status():
    # Clean up stale downloads before returning status
    cleanup_stale_downloads()
    
    # Return status with formatted data for display
    formatted_status = {}
    for dest, status in download_status.items():
        formatted_status[dest] = status.copy()
        
        # Add human-readable file sizes and speeds
        if 'file_size' in status and status['file_size'] > 0:
            formatted_status[dest]['file_size_mb'] = round(status['file_size'] / (1024 * 1024), 1)
        
        if 'downloaded' in status and status['downloaded'] > 0:
            formatted_status[dest]['downloaded_mb'] = round(status['downloaded'] / (1024 * 1024), 1)
        
        if 'speed' in status and status['speed'] > 0:
            speed_mb = status['speed'] / (1024 * 1024)
            formatted_status[dest]['speed_mb'] = round(speed_mb, 1)
        
        if 'eta' in status and status['eta'] > 0:
            eta_minutes = status['eta'] / 60
            formatted_status[dest]['eta_minutes'] = round(eta_minutes, 1)
    
    return jsonify(formatted_status)

@app.route('/clear_completed', methods=['POST'])
def clear_completed():
    """Clear completed and error downloads from status"""
    with download_lock:
        to_remove = []
        for dest, status in download_status.items():
            if status.get('status') in ['completed', 'error']:
                to_remove.append(dest)
        
        for dest in to_remove:
            del download_status[dest]
        
        save_download_status()
    
    return jsonify({'status': 'cleared', 'removed_count': len(to_remove)})

@app.route('/get_model_configs')
def get_model_configs():
    return jsonify(MODEL_CONFIGS)

@app.route('/add_model', methods=['POST'])
def add_model():
    data = request.json
    model_set = data.get('model_set')
    model_name = data.get('model_name')
    model_info = data.get('model_info')
    new_group = data.get('new_group', False)
    new_group_name = data.get('new_group_name', None)
    
    if not model_set or not model_name or not model_info:
        return jsonify({'error': 'Missing fields'}), 400
    
    # Auto-generate model ID from model name
    model_id = model_name.lower().replace(' ', '_').replace('-', '_')
    # Remove special characters and keep only alphanumeric and underscores
    model_id = ''.join(c for c in model_id if c.isalnum() or c == '_')
    
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
        
        # Check if model_id already exists, if so, append a number
        original_id = model_id
        counter = 1
        while model_id in MODEL_CONFIGS[model_set]['models']:
            model_id = f"{original_id}_{counter}"
            counter += 1
            
        MODEL_CONFIGS[model_set]['models'][model_id] = model_info
    
    save_model_configs(MODEL_CONFIGS)
    return jsonify({'status': 'added', 'model_id': model_id})

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

@app.route('/reload_config', methods=['POST'])
def reload_config():
    """Reload model configurations from file"""
    global MODEL_CONFIGS
    try:
        MODEL_CONFIGS = load_model_configs()
        return jsonify({'status': 'success', 'message': 'Configuration reloaded successfully'})
    except Exception as e:
        return jsonify({'status': 'error', 'message': f'Failed to reload config: {str(e)}'}), 500

@app.route('/debug_config')
def debug_config():
    """Debug endpoint to show current config state"""
    return jsonify({
        'config_file_path': CONFIG_FILE,
        'config_file_exists': os.path.exists(CONFIG_FILE),
        'model_sets': list(MODEL_CONFIGS.keys()),
        'total_models': sum(len(group['models']) for group in MODEL_CONFIGS.values()),
        'model_sets_detail': {
            group_name: {
                'name': group_data['name'],
                'model_count': len(group_data['models']),
                'models': list(group_data['models'].keys())
            }
            for group_name, group_data in MODEL_CONFIGS.items()
        }
    })

def load_model_configs():
    """Load model configurations from JSON file, fallback to defaults if file doesn't exist"""
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            print(f"Warning: Could not load {CONFIG_FILE}: {e}")
            print("Using default model configurations")
    return DEFAULT_MODEL_CONFIGS.copy()  # Return a copy to avoid modifying the default

def save_model_configs(configs):
    """Save model configurations to JSON file"""
    try:
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(configs, f, indent=2)
    except IOError as e:
        print(f"Error saving model configs: {e}")

def initialize_config_file():
    """Initialize the config file with defaults if it doesn't exist"""
    if not os.path.exists(CONFIG_FILE):
        print(f"Creating default model configuration file: {CONFIG_FILE}")
        save_model_configs(DEFAULT_MODEL_CONFIGS)

# Load model configurations at startup
MODEL_CONFIGS = load_model_configs()

# Initialize config file if needed
initialize_config_file()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8866)
