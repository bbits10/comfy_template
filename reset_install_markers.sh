#!/bin/bash

# Reset installation markers to force full reinstallation
# Use this script if you want to force a complete reinstall

echo "=== Reset Installation Markers ==="
echo "This will force a complete reinstallation on next startup."
echo

# Ask for confirmation
read -p "Are you sure you want to reset all installation markers? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

MARKERS_DIR="/workspace/.install_markers"

if [ -d "$MARKERS_DIR" ]; then
    echo "Removing installation markers from $MARKERS_DIR..."
    rm -rf "$MARKERS_DIR"
    echo "✓ All installation markers removed"
else
    echo "No installation markers found at $MARKERS_DIR"
fi

# Also remove status files
STATUS_FILES=(
    "/workspace/installation_progress.log"
    "/workspace/installation_status.json"
    "/workspace/sageattention_install.log"
)

for file in "${STATUS_FILES[@]}"; do
    if [ -f "$file" ]; then
        rm "$file"
        echo "✓ Removed $file"
    fi
done

echo
echo "Installation markers have been reset."
echo "The next time you start the services, a full installation will be performed."
echo "To start services now, run: bash /workspace/comfy_template/start_services.sh"
