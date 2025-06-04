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

# Clone the repository and ensure we're in the right directory
RUN git clone --depth 1 https://github.com/bbits10/comfy_template.git /workspace/comfy_template

# Change to the template directory
WORKDIR /workspace/comfy_template

# Verify we have the files and fix line endings
RUN ls -la && \
    dos2unix *.sh && \
    chmod +x *.sh

# Install flux and set permissions
RUN ./flux_install.sh && \
    chmod +x install_sage_attention.sh

# Final verification that start_services.sh exists and is executable
RUN ls -la start_services.sh && \
    test -x start_services.sh && \
    echo "start_services.sh is executable"

EXPOSE 8188 8866 8888

# Debug entrypoint
RUN echo "=== Creating debug entrypoint ===" && \
    echo '#!/bin/bash' > /debug_entrypoint.sh && \
    echo 'echo "=== Debug: Container starting ==="' >> /debug_entrypoint.sh && \
    echo 'echo "Current directory: $(pwd)"' >> /debug_entrypoint.sh && \
    echo 'echo "Listing /workspace:"' >> /debug_entrypoint.sh && \
    echo 'ls -la /workspace/' >> /debug_entrypoint.sh && \
    echo 'echo "Listing /workspace/comfy_template:"' >> /debug_entrypoint.sh && \
    echo 'ls -la /workspace/comfy_template/' >> /debug_entrypoint.sh && \
    echo 'echo "Checking start_services.sh:"' >> /debug_entrypoint.sh && \
    echo 'ls -la /workspace/comfy_template/start_services.sh' >> /debug_entrypoint.sh && \
    echo 'file /workspace/comfy_template/start_services.sh' >> /debug_entrypoint.sh && \
    echo 'echo "=== Executing start_services.sh ==="' >> /debug_entrypoint.sh && \
    echo 'exec /workspace/comfy_template/start_services.sh' >> /debug_entrypoint.sh && \
    chmod +x /debug_entrypoint.sh

ENTRYPOINT ["/debug_entrypoint.sh"]