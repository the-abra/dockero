# ==========================================================================
# Dockero Makefile
# Used to compile, run tests, and manage the distribution build.
# ==========================================================================

.PHONY: all build test clean dist lint

all: build test

build:
	@chmod +x bin/build.sh
	@./bin/build.sh

test: build
	@chmod +x bin/test_improvements.sh bin/test_commands.sh
	@./bin/test_improvements.sh
	@./bin/test_commands.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "Running ShellCheck..."; \
		find . \( -name "*.sh" -o -name "dockero" \) -type f -not -path "./.git/*" -not -path "./dist/*" -exec shellcheck --severity=error {} +; \
	else \
		echo "shellcheck is not installed. Skipping lint."; \
	fi

clean:
	@rm -rf dist/

dist: clean build test lint
	@echo "Standalone executable has been built and verified successfully inside dist/dockero"
