#!/usr/bin/env bash
# Integration test suite for Dockero commands

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERO="${SCRIPT_DIR}/dist/dockero"

PASS=0
FAIL=0

# Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'
BOLD='\033[1m'

print_section() {
    echo -e "\n${BOLD}${CYAN}🔹 $1${NC}"
}

pass() {
    printf "  %-65s %b[ PASS ]%b\n" "$1" "$GREEN" "$NC"
    ((PASS++)) || true
}

fail() {
    printf "  %-65s %b[ FAIL ]%b\n" "$1" "$RED" "$NC"
    ((FAIL++)) || true
    exit 1
}

echo -e "${BOLD}${CYAN}========================================================================${NC}"
echo -e "${BOLD}${CYAN}   Dockero Integration Command Tests                                   ${NC}"
echo -e "${BOLD}${CYAN}========================================================================${NC}"

# Test basic help command
print_section "Help CLI Manual"
if "$DOCKERO" -h > /dev/null 2>&1; then
    pass "Basic help command execution"
else
    fail "Basic help command execution"
fi

# Test new commands exist in help
print_section "Subcommand Discovery"
for cmd in registry secrets monitor wizard; do
    if "$DOCKERO" -h | grep -q "$cmd"; then
        pass "Subcommand '$cmd' listed in help manual"
    else
        fail "Subcommand '$cmd' listed in help manual"
    fi
done

# Test version command
print_section "Version and Metadata Check"
if "$DOCKERO" version > /dev/null 2>&1; then
    pass "Version command execution"
else
    fail "Version command execution"
fi

if "$DOCKERO" version | grep -q "Dockero CLI"; then
    pass "Version output format conforms to spec"
else
    fail "Version output format conforms to spec"
fi

# Test show command
print_section "Dashboard Display"
if "$DOCKERO" show dashboard > /dev/null 2>&1; then
    pass "Show dashboard layout render"
else
    fail "Show dashboard layout render"
fi

# Test validation functions
print_section "Safety Input Validation"
if ! "$DOCKERO" create "invalid name with spaces" 2>/dev/null; then
    pass "Rejection of invalid container names containing spaces"
else
    fail "Rejection of invalid container names containing spaces"
fi

# Network subcommand tests
print_section "Docker Network Aliases"
TEST_NETWORK_NAME="test_net_$(date +%s)"
if "$DOCKERO" net new "$TEST_NETWORK_NAME" > /dev/null 2>&1; then
    pass "Create net new alias network"
else
    fail "Create net new alias network"
fi

INSPECT_OUTPUT=$("$DOCKERO" net inspect "$TEST_NETWORK_NAME" 2>/dev/null || true)
if [[ -n "$INSPECT_OUTPUT" ]]; then
    pass "Inspect alias network state"
else
    fail "Inspect alias network state"
fi

if "$DOCKERO" net delete "$TEST_NETWORK_NAME" > /dev/null 2>&1; then
    pass "Delete alias network"
else
    fail "Delete alias network"
fi

# Preset validation tests
print_section "Setup Presets"
PRESET_PROJ="${SCRIPT_DIR}/dist/preset-test"
mkdir -p "$PRESET_PROJ"
rm -f "${PRESET_PROJ}/.dockero"

if "$DOCKERO" setup init "$PRESET_PROJ" --preset python > /dev/null 2>&1; then
    if [[ -f "${PRESET_PROJ}/.dockero" ]] && grep -q "image = python:3.10-alpine" "${PRESET_PROJ}/.dockero"; then
        pass "Initialize Python preset configuration"
    else
        fail "Initialize Python preset configuration (incorrect config content)"
    fi
else
    fail "Initialize Python preset configuration (execution failed)"
fi
rm -rf "$PRESET_PROJ"

# Summary
TOTAL=$((PASS + FAIL))
echo -e "\n${BOLD}${CYAN}========================================================================${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}   All integration tests passed successfully! ($PASS/$TOTAL)${NC}"
else
    echo -e "${BOLD}${RED}   Some integration tests failed! ($FAIL failed, $PASS passed)${NC}"
fi
echo -e "${BOLD}${CYAN}========================================================================${NC}"

exit 0
