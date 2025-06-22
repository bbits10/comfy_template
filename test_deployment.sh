#!/bin/bash

# ComfyUI Template Deployment Test Script
# This script verifies that all components are working correctly

echo "🔍 ComfyUI Template Deployment Test"
echo "=================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Check if Docker image exists
run_test "Docker image exists" "docker images | grep -q 'beautyinbits/comfyui-flux'"

# Test 2: Check if start_services.sh exists and is executable
run_test "start_services.sh executable" "test -x /opt/comfy_template/start_services.sh"

# Test 3: Check if model_downloader.py exists
run_test "model_downloader.py exists" "test -f /opt/comfy_template/model_downloader.py"

# Test 4: Check if model_configs.json exists and is valid JSON
run_test "model_configs.json valid" "python3 -c 'import json; json.load(open(\"/opt/comfy_template/model_configs.json\"))'"

# Test 5: Check if templates directory exists
run_test "templates directory exists" "test -d /opt/comfy_template/templates"

# Test 6: Check if index.html template exists
run_test "index.html template exists" "test -f /opt/comfy_template/templates/index.html"

# Test 7: Check if Flask can be imported
run_test "Flask available" "python3 -c 'import flask'"

# Test 8: Check if requests library available
run_test "requests library available" "python3 -c 'import requests'"

# Test 9: Check if installation scripts exist
run_test "flux_install.sh exists" "test -f /opt/comfy_template/flux_install.sh"

# Test 10: Check if documentation files exist
run_test "README.md exists" "test -f /opt/comfy_template/README.md"

echo ""
echo "🧪 Test Results Summary"
echo "======================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! Ready for deployment.${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed. Check the output above.${NC}"
    exit 1
fi
