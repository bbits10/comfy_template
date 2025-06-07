#!/bin/bash

# Installation progress logger
# This script helps track installation progress for the status page

LOG_FILE="/workspace/installation_progress.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to log with timestamp
log_step() {
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE"
    echo "$1"
}

# Function to mark step as completed
mark_completed() {
    echo "[$TIMESTAMP] ✓ COMPLETED: $1" >> "$LOG_FILE"
    echo "✓ $1"
}

# Function to mark step as failed
mark_failed() {
    echo "[$TIMESTAMP] ✗ FAILED: $1" >> "$LOG_FILE"
    echo "✗ $1"
}

# Function to update overall status
update_status() {
    local component="$1"
    local status="$2"
    local status_file="/workspace/installation_status.json"
    
    # Create or update status file
    if [ ! -f "$status_file" ]; then
        echo '{}' > "$status_file"
    fi
    
    # Update component status
    python3 -c "
import json
import sys

try:
    with open('$status_file', 'r') as f:
        status = json.load(f)
except:
    status = {}

status['$component'] = '$status'
status['last_updated'] = '$TIMESTAMP'

with open('$status_file', 'w') as f:
    json.dump(status, f, indent=2)
"
}

# Export functions for use in other scripts
export -f log_step
export -f mark_completed  
export -f mark_failed
export -f update_status
export LOG_FILE
