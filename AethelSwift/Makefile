.PHONY: build release check fmt fmt-fix lint test clean format format-check

# Build commands
build:
	swift build

release:
	swift build -c release

check:
	swift build --build-tests

# Formatting
format:
	./scripts/run-swift-format.sh format --in-place --recursive Sources/ Tests/

format-check:
	./scripts/run-swift-format.sh lint --recursive Sources/ Tests/

fmt: format-check

fmt-fix: format

# Testing
test:
	swift test

# Clean
clean:
	swift package clean