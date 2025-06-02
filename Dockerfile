# Use the same base image as your RunPod template
FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

# Set environment variables to prevent interactive prompts during package installations
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install essential build tools + git
RUN apt-get update && apt-get install -y \
    wget \
    git \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Flask and requests for the model downloader
RUN pip install flask requests

# Set working directory
WORKDIR /workspace

# Copy your installation script and model downloader into the image
COPY flux_install.sh /workspace/flux_install.sh
COPY model_downloader.py /workspace/model_downloader.py
COPY templates /workspace/templates

# Make the script executable and run it.
RUN chmod +x /workspace/flux_install.sh && \
    /workspace/flux_install.sh

# Set the working directory for the final CMD
WORKDIR /workspace/ComfyUI

# Expose the ports for ComfyUI and model downloader
EXPOSE 8188 8866

# Copy and set up the startup script
COPY start_services.sh /workspace/start_services.sh
RUN chmod +x /workspace/start_services.sh

# Command to start both services when the container launches
CMD ["/workspace/start_services.sh"]