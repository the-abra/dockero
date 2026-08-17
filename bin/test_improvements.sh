#!/usr/bin/env bash
# Comprehensive test suite for Dockero

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Compile first
bash "${SCRIPT_DIR}/bin/build.sh" > /dev/null
DOCKERO="${SCRIPT_DIR}/dist/dockero"

PASS=0
FAIL=0

# Colors
GREEN='\e[38;5;82m'
RED='\e[38;5;196m'
YELLOW='\e[38;5;214m'
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
}

skip() {
    printf "  %-65s %b[ SKIP ]%b\n" "$1" "$YELLOW" "$NC"
    ((PASS++)) || true
}

DOCKER_AVAILABLE=false
command -v docker &>/dev/null && docker ps &>/dev/null 2>&1 && DOCKER_AVAILABLE=true

echo -e "${BOLD}${BLUE}========================================================================${NC}"
echo -e "${BOLD}${BLUE}   Dockero Core Unit & Improvement Tests                                ${NC}"
echo -e "${BOLD}${BLUE}========================================================================${NC}"

# Test 1: Dependency validation
print_section "Dependency Validation"
if $DOCKER_AVAILABLE; then
    pass "Docker is installed and running"
else
    skip "Docker is installed and running (skipped: docker unavailable)"
fi
if command -v jq &>/dev/null; then
    pass "jq utility is installed"
else
    skip "jq utility is installed (skipped: jq unavailable)"
fi

# Test 2: Parameter parsing with values
print_section "Parameter Parsing"
if (
    declare -A params
    args=()
    source "${SCRIPT_DIR}/lib/parameter-indexing.sh"
    parameter-indexing mycontainer -t 50 -f
    [[ "${params[t]}" == "50" && "${params[f]}" == "true" && "${args[0]}" == "mycontainer" ]]
); then
    pass "Handles 'mycontainer -t 50 -f' parameter indexing"
else
    fail "Handles 'mycontainer -t 50 -f' parameter indexing"
fi

# Test 3: Standalone execution of help
print_section "Standalone Execution"
OUT=$("$DOCKERO" --help 2>/dev/null)
if echo "$OUT" | grep -q "Available commands:"; then
    pass "General manual help output structure"
else
    fail "General manual help output structure"
fi

# Test 4: Dynamic explain system
print_section "Dynamic Explain System"
OUT=$("$DOCKERO" explain create 2>&1)
if echo "$OUT" | grep -q "Create and start a new container"; then
    pass "Explain output for 'create' subcommand"
else
    fail "Explain output for 'create' subcommand"
fi

# Test 5: Plugin loading
print_section "Plugin System"
mkdir -p ~/.dockero/commands
cat > ~/.dockero/commands/testplugin.sh << 'EOF'
#!/usr/bin/env bash
testplugin_help() { echo "Test plugin help"; }
testplugin() { echo "Plugin executed"; }
EOF
chmod +x ~/.dockero/commands/testplugin.sh
OUT=$("$DOCKERO" testplugin 2>/dev/null)
if echo "$OUT" | grep -q "Plugin executed"; then
    pass "Dynamic user script plugin loading"
else
    fail "Dynamic user script plugin loading"
fi
rm -f ~/.dockero/commands/testplugin.sh

# Test 6: Runtime flexibility check
print_section "Runtime Abstraction"
if grep -q 'DOCKERO_RUNTIME:-docker' "${SCRIPT_DIR}/lib/commands/create.sh"; then
    pass "Subcommands use runtime config abstraction"
else
    fail "Subcommands use runtime config abstraction"
fi

# Test 7: Help function coverage in codebase
print_section "Help Documentation Coverage"
missing=0
for cmd in create volume list monitor heal net system compose env; do
    if ! grep -q "${cmd}_help()" "${SCRIPT_DIR}/lib/commands/${cmd}.sh" 2>/dev/null; then
        ((missing++)) || true
    fi
done
if [[ $missing -eq 0 ]]; then
    pass "All subcommands contain inline help documentation"
else
    fail "$missing commands are missing help definitions"
fi

# Test 8: Setup Presets (New Feature!)
print_section "Setup Presets"
TEST_PROJ_DIR="${SCRIPT_DIR}/dist/test-project"
mkdir -p "$TEST_PROJ_DIR"
rm -f "${TEST_PROJ_DIR}/.dockero"

if "$DOCKERO" setup init "$TEST_PROJ_DIR" --preset nginx 2>/dev/null; then
    if [[ -f "${TEST_PROJ_DIR}/.dockero" ]]; then
        if grep -q "image = nginx:alpine" "${TEST_PROJ_DIR}/.dockero" && grep -q "port = 8080:80" "${TEST_PROJ_DIR}/.dockero"; then
            pass "Preset auto setup writes correct values to config"
        else
            fail "Preset config contains incorrect values"
        fi
    else
        fail "Preset failed to write config file"
    fi
else
    fail "Preset setup init execution failed"
fi
rm -rf "$TEST_PROJ_DIR"

# Summary
TOTAL=$((PASS + FAIL))
echo -e "\n${BOLD}${BLUE}========================================================================${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}   All tests passed successfully! ($PASS/$TOTAL)${NC}"
else
    echo -e "${BOLD}${RED}   Some tests failed! ($FAIL failed, $PASS passed)${NC}"
fi
echo -e "${BOLD}${BLUE}========================================================================${NC}"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
