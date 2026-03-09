#!/bin/bash
# Simple test script to validate Dockero commands

echo "Running Dockero tests..."

# Test basic help command
echo "Testing help command..."
if ./core/dockero -h > /dev/null 2>&1; then
    echo "✅ Help command works"
else
    echo "❌ Help command failed"
    exit 1
fi

# Test new commands exist in help
echo "Testing new commands in help..."
if ./core/dockero -h | grep -q "registry"; then
    echo "✅ Registry command in help"
else
    echo "❌ Registry command missing from help"
    exit 1
fi

if ./core/dockero -h | grep -q "secrets"; then
    echo "✅ Secrets command in help"
else
    echo "❌ Secrets command missing from help"
    exit 1
fi

if ./core/dockero -h | grep -q "monitor"; then
    echo "✅ Monitor command in help"
else
    echo "❌ Monitor command missing from help"
    exit 1
fi

if ./core/dockero -h | grep -q "wizard"; then
    echo "✅ Wizard command in help"
else
    echo "❌ Wizard command missing from help"
    exit 1
fi

# Test version command
echo "Testing version command..."
if ./core/dockero version > /dev/null 2>&1; then
    echo "✅ Version command works"
else
    echo "❌ Version command failed"
    exit 1
fi

# Test show command
echo "Testing show command..."
if ./core/dockero show dashboard > /dev/null 2>&1; then
    echo "✅ Show dashboard command works"
else
    echo "❌ Show dashboard command failed"
    exit 1
fi

# Test new configuration loading
echo "Testing configuration loading..."
if ./core/dockero version | grep -q "Dockero CLI"; then
    echo "✅ Configuration loading works"
else
    echo "❌ Configuration loading failed"
    exit 1
fi

# Test validation functions with invalid input
echo "Testing validation functions..."
# This should fail with validation error
if ! ./core/dockero run "invalid name with spaces" 2>/dev/null; then
    echo "✅ Validation functions work"
else
    echo "⚠️  Validation may not be fully working"
fi

# Test new dashboard command specifically
echo "Testing new dashboard command..."
if ./core/dockero show dashboard | grep -q "Dockero Dashboard"; then
    echo "✅ New dashboard command works"
else
    echo "❌ New dashboard command failed"
    exit 1
fi

# Test net inspect command
echo "Testing net inspect command..."
TEST_NETWORK_NAME="test_inspect_net"
TEST_CONTAINER_NAME="test_inspect_container"

# Create a test network
./core/dockero net new "$TEST_NETWORK_NAME" > /dev/null 2>&1

# Run a container connected to the test network
docker run -d --name "$TEST_CONTAINER_NAME" --network "$TEST_NETWORK_NAME" alpine:latest sleep 30 > /dev/null 2>&1

# Inspect the network and check output
INSPECT_OUTPUT=$(./core/dockero net inspect "$TEST_NETWORK_NAME")

if ! echo "$INSPECT_OUTPUT" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | grep -q "✨ Inspecting Network: $TEST_NETWORK_NAME"; then
    echo "❌ net inspect command failed: Network name not found in output."
    echo "$INSPECT_OUTPUT"
    docker rm -f "$TEST_CONTAINER_NAME" > /dev/null 2>&1
    ./core/dockero net delete "$TEST_NETWORK_NAME" > /dev/null 2>&1
    exit 1
fi

if ! echo "$INSPECT_OUTPUT" | grep -q "$TEST_CONTAINER_NAME"; then
    echo "❌ net inspect command failed: Container name not found in output."
    echo "$INSPECT_OUTPUT"
    docker rm -f "$TEST_CONTAINER_NAME" > /dev/null 2>&1
    ./core/dockero net delete "$TEST_NETWORK_NAME" > /dev/null 2>&1
    exit 1
fi

echo "✅ net inspect command works"

# Clean up
docker rm -f "$TEST_CONTAINER_NAME" > /dev/null 2>&1
./core/dockero net delete "$TEST_NETWORK_NAME" > /dev/null 2>&1

# Test net prune command
echo "Testing net prune command..."
PRUNE_NET1="prune_net_1"
PRUNE_NET2="prune_net_2"
./core/dockero net new "$PRUNE_NET1" > /dev/null 2>&1
./core/dockero net new "$PRUNE_NET2" > /dev/null 2>&1

if ./core/dockero net prune; then # Check for successful exit code
    if ! docker network ls --format '{{.Name}}' | grep -q "$PRUNE_NET1" && \
       ! docker network ls --format '{{.Name}}' | grep -q "$PRUNE_NET2"; then
        echo "✅ net prune command works"
    else
        echo "❌ net prune command failed: Networks '$PRUNE_NET1' or '$PRUNE_NET2' still exist."
        docker network rm "$PRUNE_NET1" "$PRUNE_NET2" &>/dev/null
        exit 1
    fi
else
    echo "❌ net prune command failed with non-zero exit code."
    docker network rm "$PRUNE_NET1" "$PRUNE_NET2" &>/dev/null
    exit 1
fi

# Test net create alias
# echo "Testing net create alias..."
# CREATE_ALIAS_NET="create_alias_net"
# echo "Attempting to create network using alias: dockero net create $CREATE_ALIAS_NET"
# if ./core/dockero net create "$CREATE_ALIAS_NET"; then
#     if docker network inspect "$CREATE_ALIAS_NET" &>/dev/null; then
#         echo "✅ net create alias works"
#         ./core/dockero net delete "$CREATE_ALIAS_NET" > /dev/null 2>&1
#     else
#         echo "❌ net create alias failed: Network '$CREATE_ALIAS_NET' not created."
#         ./core/dockero net delete "$CREATE_ALIAS_NET" > /dev/null 2>&1
#         exit 1
#     fi
# else
#     echo "❌ net create alias failed."
#     ./core/dockero net delete "$CREATE_ALIAS_NET" > /dev/null 2>&1
#     exit 1
# fi

# Test net connect and net disconnect aliases
# echo "Testing net connect and net disconnect aliases..."
# ALIAS_TEST_NET="alias_test_net"
# ALIAS_TEST_CONTAINER="alias_test_container"

# ./core/dockero net new "$ALIAS_TEST_NET" > /dev/null 2>&1
# docker run -d --name "$ALIAS_TEST_CONTAINER" alpine:latest sleep 30 > /dev/null 2>&1

# # Connect
# if ./core/dockero net connect "$ALIAS_TEST_CONTAINER" "$ALIAS_TEST_NET" > /dev/null 2>&1; then
#     if ./core/dockero net inspect "$ALIAS_TEST_NET" | grep -q "$ALIAS_TEST_CONTAINER"; then
#         echo "✅ net connect alias works"
#     else
#         echo "❌ net connect alias failed: Container '$ALIAS_TEST_CONTAINER' not connected."
#         docker rm -f "$ALIAS_TEST_CONTAINER" > /dev/null 2>&1
#         ./core/dockero net delete "$ALIAS_TEST_NET" > /dev/null 2>&1
#         exit 1
#     fi
# else
#     echo "❌ net connect alias failed."
#     docker rm -f "$ALIAS_TEST_CONTAINER" > /dev/null 2>&1
#     ./core/dockero net delete "$ALIAS_TEST_NET" > /dev/null 2>&1
#     exit 1
# fi

# # Disconnect
# if ./core/dockero net disconnect "$ALIAS_TEST_CONTAINER" "$ALIAS_TEST_NET" > /dev/null 2>&1; then
#     if ! ./core/dockero net inspect "$ALIAS_TEST_NET" | grep -q "$ALIAS_TEST_CONTAINER"; then
#         echo "✅ net disconnect alias works"
#     else
#         echo "❌ net disconnect alias failed: Container '$ALIAS_TEST_CONTAINER' still connected."
#         docker rm -f "$ALIAS_TEST_CONTAINER" > /dev/null 2>&1
#         ./core/dockero net delete "$ALIAS_TEST_NET" > /dev/null 2>&1
#         exit 1
#     fi
# else
#     echo "❌ net disconnect alias failed."
#     docker rm -f "$ALIAS_TEST_CONTAINER" > /dev/null 2>&1
#     ./core/dockero net delete "$ALIAS_TEST_NET" > /dev/null 2>&1
#     exit 1
# fi

# # Clean up
# docker rm -f "$ALIAS_TEST_CONTAINER" > /dev/null 2>&1
# ./core/dockero net delete "$ALIAS_TEST_NET" > /dev/null 2>&1


echo "All tests passed! 🎉"