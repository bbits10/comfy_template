# Use the RunPod CUDA 12.8.1 base image for full CUDA 12.8 compatibility
FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget \
    git \
    python3-pip \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --upgrade pip && \
    python -m pip install --no-cache-dir flask==2.3.3 requests werkzeug==2.3.7 --ignore-installed

WORKDIR /workspace

RUN git clone --depth 1 https://github.com/bbits10/comfy_template.git /workspace/comfy_template
WORKDIR /workspace/comfy_template

# Fix line endings for all shell scripts (important for Windows users)
RUN dos2unix *.sh

RUN chmod +x flux_install.sh && \
    ./flux_install.sh && \
    chmod +x install_sage_attention.sh

RUN chmod +x start_services.sh

EXPOSE 8188 8866 8888

ENTRYPOINT ["/workspace/comfy_template/start_services.sh"]