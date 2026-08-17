#!/usr/bin/env bash
# Integration test suite for Dockero commands

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERO="${SCRIPT_DIR}/dist/dockero"

PASS=0
FAIL=0

# Colors
GREEN='\e[38;5;82m'
RED='\e[38;5;196m'
BLUE='\e[38;5;75m'
NC='\e[0m'
BOLD='\e[1m'

print_section() {
    echo -e "\n${BOLD}${BLUE}$1${NC}"
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

echo -e "${BOLD}${BLUE}========================================================================${NC}"
echo -e "${BOLD}${BLUE}   Dockero Comprehensive Integration Command Tests                     ${NC}"
echo -e "${BOLD}${BLUE}========================================================================${NC}"

# Test basic help command
print_section "Help CLI Manual"
if "$DOCKERO" -h > /dev/null 2>&1; then
    pass "Basic help command execution (-h)"
else
    fail "Basic help command execution (-h)"
fi

# Test new commands exist in help
print_section "Subcommand Discovery"
for cmd in registry secrets monitor wizard setup compose env validate system heal volume; do
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

# Test native Docker aliases
print_section "Docker Native Aliases"
if "$DOCKERO" explain run > /dev/null 2>&1; then
    pass "Alias 'run' explained correctly"
else
    fail "Alias 'run' explained correctly"
fi

if "$DOCKERO" ps > /dev/null 2>&1; then
    pass "Alias 'ps' lists containers cleanly without error"
else
    fail "Alias 'ps' lists containers cleanly without error"
fi

if "$DOCKERO" ls > /dev/null 2>&1; then
    pass "Alias 'ls' lists containers cleanly without error"
else
    fail "Alias 'ls' lists containers cleanly without error"
fi

# Test dashboard and show command
print_section "Dashboard & Show Display"
if "$DOCKERO" show dashboard > /dev/null 2>&1; then
    pass "Show dashboard layout render"
else
    fail "Show dashboard layout render"
fi

if "$DOCKERO" dashboard > /dev/null 2>&1; then
    pass "Direct dashboard command execution"
else
    fail "Direct dashboard command execution"
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

# Volume subcommand tests
print_section "Docker Volume Management"
TEST_VOL_NAME="test_vol_$(date +%s)"
if "$DOCKERO" volume create "$TEST_VOL_NAME" > /dev/null 2>&1; then
    pass "Create named volume"
else
    fail "Create named volume"
fi

if "$DOCKERO" volume inspect "$TEST_VOL_NAME" > /dev/null 2>&1; then
    pass "Inspect named volume"
else
    fail "Inspect named volume"
fi

if "$DOCKERO" volume rm "$TEST_VOL_NAME" > /dev/null 2>&1; then
    pass "Remove named volume"
else
    fail "Remove named volume"
fi

# Preset validation tests
print_section "Setup Presets & Validation"
PRESET_PROJ="${SCRIPT_DIR}/dist/preset-test"
mkdir -p "$PRESET_PROJ"
rm -f "${PRESET_PROJ}/.dockero"

if "$DOCKERO" setup init "$PRESET_PROJ" --preset python > /dev/null 2>&1; then
    if [[ -f "${PRESET_PROJ}/.dockero" ]] && grep -q "image = python:3.11-alpine" "${PRESET_PROJ}/.dockero"; then
        pass "Initialize Python preset configuration"
    else
        fail "Initialize Python preset configuration (incorrect config content)"
    fi
else
    fail "Initialize Python preset configuration (execution failed)"
fi

# Test project validation on generated config
if "$DOCKERO" validate "$PRESET_PROJ" > /dev/null 2>&1; then
    pass "Validate generated project .dockero config"
else
    fail "Validate generated project .dockero config"
fi

rm -rf "$PRESET_PROJ"

# Summary
TOTAL=$((PASS + FAIL))
echo -e "\n${BOLD}${BLUE}========================================================================${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}   All integration tests passed successfully! ($PASS/$TOTAL)${NC}"
else
    echo -e "${BOLD}${RED}   Some integration tests failed! ($FAIL failed, $PASS passed)${NC}"
fi
echo -e "${BOLD}${BLUE}========================================================================${NC}"

exit 0
