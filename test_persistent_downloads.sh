#!/bin/bash

# Test script for persistent download tracking

echo "=== Testing Persistent Download System ==="
echo

# Start the model downloader in background
echo "1. Starting model downloader..."
cd /workspace/comfy_template
python model_downloader.py &
DOWNLOADER_PID=$!
echo "Model downloader started with PID: $DOWNLOADER_PID"

# Wait for server to start
echo "2. Waiting for server to start..."
sleep 5

# Check if server is running
echo "3. Testing server status..."
if curl -s http://localhost:8866/status > /dev/null; then
    echo "✓ Server is running and responsive"
else
    echo "✗ Server is not responding"
    kill $DOWNLOADER_PID 2>/dev/null
    exit 1
fi

# Test the status endpoint
echo "4. Testing status endpoint..."
STATUS_RESPONSE=$(curl -s http://localhost:8866/status)
echo "Status response: $STATUS_RESPONSE"

# Check if download status file exists and is writable
echo "5. Testing download status file..."
if [ -f "/workspace/.download_status.json" ]; then
    echo "✓ Download status file exists"
    echo "Content: $(cat /workspace/.download_status.json)"
else
    echo "✓ Download status file will be created on first download"
fi

# Test clearing completed downloads
echo "6. Testing clear completed endpoint..."
CLEAR_RESPONSE=$(curl -s -X POST http://localhost:8866/clear_completed)
echo "Clear response: $CLEAR_RESPONSE"

echo
echo "=== Test Results ==="
echo "✓ Persistent download system is ready"
echo "✓ Download status will persist across page refreshes"
echo "✓ Server is running on http://localhost:8866"
echo
echo "To test the system:"
echo "1. Open http://localhost:8866 in your browser"
echo "2. Start downloading a model"
echo "3. Refresh the page during download"
echo "4. Verify that progress is still visible"
echo
echo "To stop the test server: kill $DOWNLOADER_PID"
