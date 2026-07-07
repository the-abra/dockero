#!/bin/bash
# Simple test script to validate Dockero commands

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERO="${SCRIPT_DIR}/dist/dockero"

echo "Running Dockero tests..."

# Test basic help command
echo "Testing help command..."
if "$DOCKERO" -h > /dev/null 2>&1; then
    echo "✅ Help command works"
else
    echo "❌ Help command failed"
    exit 1
fi

# Test new commands exist in help
echo "Testing new commands in help..."
for cmd in registry secrets monitor wizard; do
    if "$DOCKERO" -h | grep -q "$cmd"; then
        echo "✅ $cmd command in help"
    else
        echo "❌ $cmd command missing from help"
        exit 1
    fi
done

# Test version command
echo "Testing version command..."
if "$DOCKERO" version > /dev/null 2>&1; then
    echo "✅ Version command works"
else
    echo "❌ Version command failed"
    exit 1
fi

# Test show command
echo "Testing show command..."
if "$DOCKERO" show dashboard > /dev/null 2>&1; then
    echo "✅ Show dashboard command works"
else
    echo "❌ Show dashboard command failed"
    exit 1
fi

# Test version string match
if "$DOCKERO" version | grep -q "Dockero CLI"; then
    echo "✅ Version output matches format"
else
    echo "❌ Version output format incorrect"
    exit 1
fi

# Test validation functions
echo "Testing validation functions..."
if ! "$DOCKERO" create "invalid name with spaces" 2>/dev/null; then
    echo "✅ Validation functions work (successfully rejected invalid container name)"
else
    echo "❌ Validation functions failed (allowed invalid container name)"
    exit 1
fi

# Network subcommand tests
TEST_NETWORK_NAME="test_net_$(date +%s)"
echo "Testing net commands..."
if "$DOCKERO" net new "$TEST_NETWORK_NAME" > /dev/null 2>&1; then
    echo "✅ net new command works"
else
    echo "❌ net new command failed"
    exit 1
fi

INSPECT_OUTPUT=$("$DOCKERO" net inspect "$TEST_NETWORK_NAME" 2>/dev/null || true)
if [[ -n "$INSPECT_OUTPUT" ]]; then
    echo "✅ net inspect command works"
else
    echo "❌ net inspect command failed"
    exit 1
fi

if "$DOCKERO" net delete "$TEST_NETWORK_NAME" > /dev/null 2>&1; then
    echo "✅ net delete command works"
else
    echo "❌ net delete command failed"
    exit 1
fi

# Preset validation tests
echo "Testing setup --preset initialization..."
PRESET_PROJ="${SCRIPT_DIR}/dist/preset-test"
mkdir -p "$PRESET_PROJ"
rm -f "${PRESET_PROJ}/.dockero"

if "$DOCKERO" setup init "$PRESET_PROJ" --preset python > /dev/null 2>&1; then
    if [[ -f "${PRESET_PROJ}/.dockero" ]] && grep -q "image = python:3.10-alpine" "${PRESET_PROJ}/.dockero"; then
        echo "✅ setup --preset python config works"
    else
        echo "❌ setup --preset python config contents incorrect"
        exit 1
    fi
else
    echo "❌ setup --preset python init command failed"
    exit 1
fi
rm -rf "$PRESET_PROJ"

echo "All integration command tests passed! 🎉"
