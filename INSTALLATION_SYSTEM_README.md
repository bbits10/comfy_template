# Improved RunPod Installation System

## Overview

The RunPod installation system has been significantly improved to handle pod resume scenarios properly. Instead of re-installing everything from scratch, the system now:

1. **Checks for existing installations** before proceeding
2. **Uses installation markers** to track what's been successfully installed
3. **Only installs missing components** when resuming a pod
4. **Handles failures gracefully** without breaking existing installations

## How It Works

### Installation Markers

The system uses marker files stored in `/workspace/.install_markers/` to track completed installations:

- `comfyui_core.done` - ComfyUI repository cloned/updated
- `dependencies_main.done` - Main pip dependencies installed
- `dependencies_additional.done` - Additional core dependencies installed
- `manager_prerequisites.done` - GitPython and Typer installed
- `comfyui_manager.done` - ComfyUI Manager installed
- `custom_nodes.done` - All custom nodes installed
- `ffmpeg_source.done` - FFmpeg source cloned
- `gguf_node.done` - GGUF node installed
- `sageattention.done` - SageAttention installed
- `overall_installation.done` - Complete installation finished

Each marker file contains the timestamp when the component was successfully installed.

### Resume Detection

When `start_services.sh` runs, it automatically detects if this is a pod resume by checking:

1. Does `/workspace/ComfyUI` directory exist?
2. Does `/workspace/ComfyUI/main.py` exist?

If both exist, it's considered a resume scenario and the system will:

- Skip waiting for full installation
- Verify model directories exist
- Run installation check in background to ensure completeness

### Smart Installation Logic

The `flux_install.sh` script now:

1. **Checks each component** before installing
2. **Skips already-installed components** automatically
3. **Shows clear status messages** about what's being skipped vs installed
4. **Handles partial installations** gracefully

## Usage

### Normal Operation (First Time)

Just start your RunPod normally - the installation will proceed as before, but with better tracking:

```bash
bash /workspace/comfy_template/start_services.sh
```

### Pod Resume (Automatic)

When you restart a stopped pod, the system automatically detects the resume and:

- Updates the template repository to get latest configs
- Starts web services immediately
- Runs a quick background check to ensure all components are installed
- Starts ComfyUI if it's ready

### Manual Status Check

Check what's installed and running:

```bash
bash /workspace/comfy_template/check_install_status.sh
```

This will show:

- ✓ What components are installed (with timestamps)
- ✗ What components are missing
- Current running processes
- Log file status
- Overall health assessment

### Force Full Reinstall

If you need to force a complete reinstallation:

```bash
bash /workspace/comfy_template/reset_install_markers.sh
```

This removes all installation markers, forcing a fresh install on next startup.

## Troubleshooting

### If Installation Seems Stuck

1. **Check status first:**

   ```bash
   bash /workspace/comfy_template/check_install_status.sh
   ```

2. **Check background processes:**

   ```bash
   ps aux | grep -E "(python|pip|git)"
   ```

3. **Check installation logs:**

   ```bash
   tail -f /workspace/installation_progress.log
   ```

4. **Check SageAttention (if installing):**
   ```bash
   tail -f /workspace/sageattention_install.log
   ```

### If Components Are Missing After Resume

The system should automatically detect and install missing components. If something is still missing:

1. **Check what's missing:**

   ```bash
   bash /workspace/comfy_template/check_install_status.sh
   ```

2. **Reset specific component** (remove its marker):

   ```bash
   rm /workspace/.install_markers/COMPONENT_NAME.done
   ```

3. **Re-run installation:**
   ```bash
   bash /workspace/comfy_template/flux_install.sh
   ```

### If You Want to Update Everything

To get latest versions of all components:

1. **Reset markers:**

   ```bash
   bash /workspace/comfy_template/reset_install_markers.sh
   ```

2. **Restart services:**
   ```bash
   bash /workspace/comfy_template/start_services.sh
   ```

## Benefits

### For Users

- **Faster pod resume** - no waiting for unnecessary reinstalls
- **More reliable** - less chance of installation failures
- **Better visibility** - clear status of what's installed
- **Less frustration** - stopped pods resume quickly

### For Development

- **Easier debugging** - clear tracking of what succeeded/failed
- **Incremental updates** - can add new components without full reinstall
- **Better testing** - can test individual components
- **Cleaner logs** - less noise from skipped installations

## Files Changed

1. **`flux_install.sh`** - Added idempotent installation logic
2. **`start_services.sh`** - Added resume detection and handling
3. **`check_install_status.sh`** - New script to check installation status
4. **`reset_install_markers.sh`** - New script to force full reinstall

## Technical Details

### Marker File Format

Each marker file contains a single line with the installation timestamp:

```
2025-06-20 10:30:45
```

### Installation Flow

1. Check if marker exists for component
2. If exists, skip with message "already installed"
3. If not exists, proceed with installation
4. On successful completion, create marker file
5. Update status in installation logger

### Background Installation

SageAttention installs in background by default to avoid blocking the UI. Its installation status is tracked separately and can be monitored via logs.

## Future Improvements

Potential enhancements for the future:

- Version tracking in marker files
- Dependency checking between components
- Rollback capability for failed updates
- Health checks for installed components
- Integration with ComfyUI Manager for node updates
