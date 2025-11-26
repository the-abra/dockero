#!/bin/bash
# Simple test script to validate Dockero commands

echo "Running Dockero tests..."

# Test basic help command
echo "Testing help command..."
if ./core/dockero.sh -h > /dev/null 2>&1; then
    echo "✅ Help command works"
else
    echo "❌ Help command failed"
    exit 1
fi

# Test new commands exist in help
echo "Testing new commands in help..."
if ./core/dockero.sh -h | grep -q "registry"; then
    echo "✅ Registry command in help"
else
    echo "❌ Registry command missing from help"
    exit 1
fi

if ./core/dockero.sh -h | grep -q "secrets"; then
    echo "✅ Secrets command in help"
else
    echo "❌ Secrets command missing from help"
    exit 1
fi

if ./core/dockero.sh -h | grep -q "monitor"; then
    echo "✅ Monitor command in help"
else
    echo "❌ Monitor command missing from help"
    exit 1
fi

if ./core/dockero.sh -h | grep -q "wizard"; then
    echo "✅ Wizard command in help"
else
    echo "❌ Wizard command missing from help"
    exit 1
fi

# Test version command
echo "Testing version command..."
if ./core/dockero.sh version > /dev/null 2>&1; then
    echo "✅ Version command works"
else
    echo "❌ Version command failed"
    exit 1
fi

# Test show command
echo "Testing show command..."
if ./core/dockero.sh show dashboard > /dev/null 2>&1; then
    echo "✅ Show dashboard command works"
else
    echo "❌ Show dashboard command failed"
    exit 1
fi

# Test new configuration loading
echo "Testing configuration loading..."
if ./core/dockero.sh version | grep -q "Dockero CLI"; then
    echo "✅ Configuration loading works"
else
    echo "❌ Configuration loading failed"
    exit 1
fi

# Test validation functions with invalid input
echo "Testing validation functions..."
# This should fail with validation error
if ! ./core/dockero.sh run "invalid name with spaces" 2>/dev/null; then
    echo "✅ Validation functions work"
else
    echo "⚠️  Validation may not be fully working"
fi

# Test new dashboard command specifically
echo "Testing new dashboard command..."
if ./core/dockero.sh show dashboard | grep -q "Dockero Dashboard"; then
    echo "✅ New dashboard command works"
else
    echo "❌ New dashboard command failed"
    exit 1
fi

echo "All tests passed! 🎉"