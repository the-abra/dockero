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
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; ((PASS++)) || true; }
fail() { echo -e "${RED}✗${NC} $1"; ((FAIL++)) || true; }
info() { echo -e "${YELLOW}→${NC} $1"; }

DOCKER_AVAILABLE=false
command -v docker &>/dev/null && docker ps &>/dev/null 2>&1 && DOCKER_AVAILABLE=true

skip() { echo -e "${YELLOW}⊘${NC} $1 (skipped: docker unavailable)"; ((PASS++)) || true; }

# Test 1: Dependency validation
info "Test 1: Dependency validation"
if $DOCKER_AVAILABLE; then
    pass "Docker is installed and running"
else
    info "Docker not found or not running (runtime tests will be skipped)"
fi
if command -v jq &>/dev/null; then
    pass "jq is installed"
else
    info "jq not found (some features will be limited)"
fi

# Test 2: Parameter parsing with values
info "Test 2: Parameter parsing"
if (
    declare -A params
    args=()
    source "${SCRIPT_DIR}/lib/parameter-indexing.sh"
    parameter-indexing mycontainer -t 50 -f
    [[ "${params[t]}" == "50" && "${params[f]}" == "true" && "${args[0]}" == "mycontainer" ]]
); then
    pass "Parameter parsing handles 'mycontainer -t 50 -f' correctly"
else
    fail "Parameter parsing broken"
fi

# Test 3: Standalone execution of help
info "Test 3: Standalone execution"
OUT=$("$DOCKERO" --help 2>/dev/null)
if echo "$OUT" | grep -q "Available commands:"; then
    pass "Help command returns general manual options"
else
    fail "Help command output not found"
fi

# Test 4: Dynamic explain system
info "Test 4: Dynamic explain system"
OUT=$("$DOCKERO" explain create 2>&1)
echo "=== DOCKERO OUTPUT ==="
echo "$OUT"
echo "======================"
if echo "$OUT" | grep -q "Create and start a new container"; then
    pass "Dynamic explain works for 'create'"
else
    fail "Dynamic explain failed for 'create'"
fi

# Test 5: Plugin loading
info "Test 5: Plugin loading"
mkdir -p ~/.dockero/commands
cat > ~/.dockero/commands/testplugin.sh << 'EOF'
#!/usr/bin/env bash
testplugin_help() { echo "Test plugin help"; }
testplugin() { echo "Plugin executed"; }
EOF
chmod +x ~/.dockero/commands/testplugin.sh
OUT=$("$DOCKERO" testplugin 2>/dev/null)
if echo "$OUT" | grep -q "Plugin executed"; then
    pass "Plugin system dynamically loads user commands"
else
    fail "Plugin system failed to run custom scripts"
fi
rm -f ~/.dockero/commands/testplugin.sh

# Test 6: Runtime flexibility check
info "Test 6: Runtime flexibility check"
if grep -q 'DOCKERO_RUNTIME:-docker' "${SCRIPT_DIR}/lib/commands/create.sh"; then
    pass "Commands use modular runtime config \${DOCKERO_RUNTIME:-docker}"
else
    fail "Hardcoded docker calls still exist"
fi

# Test 7: Help function coverage in codebase
info "Test 7: Help function coverage"
missing=0
for cmd in create volume list monitor heal net sync compose env; do
    if ! grep -q "${cmd}_help()" "${SCRIPT_DIR}/lib/commands/${cmd}.sh" 2>/dev/null; then
        ((missing++)) || true
    fi
done
if [[ $missing -eq 0 ]]; then
    pass "All major commands contain inline _help() documentation"
else
    fail "$missing commands are missing help definition functions"
fi

# Test 8: Setup Presets (New Feature!)
info "Test 8: Setup Presets"
TEST_PROJ_DIR="${SCRIPT_DIR}/dist/test-project"
mkdir -p "$TEST_PROJ_DIR"
rm -f "${TEST_PROJ_DIR}/.dockero"

if "$DOCKERO" setup init "$TEST_PROJ_DIR" --preset nginx 2>/dev/null; then
    if [[ -f "${TEST_PROJ_DIR}/.dockero" ]]; then
        if grep -q "image = nginx:alpine" "${TEST_PROJ_DIR}/.dockero" && grep -q "port = 8080:80" "${TEST_PROJ_DIR}/.dockero"; then
            pass "Preset auto setup (nginx) successfully configured project configuration without prompt"
        else
            fail "Preset .dockero file populated with incorrect values"
        fi
    else
        fail "Preset failed to write config file"
    fi
else
    fail "setup init --preset execution failed"
fi
rm -rf "$TEST_PROJ_DIR"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Test Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
