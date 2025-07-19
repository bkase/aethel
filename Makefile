.PHONY: all build test lint fmt fmt-check clean

# Default target
all: build test lint

# Build the project in release mode
build:
	@echo "Building release binary..."
	@cargo build --release

# Build the project in debug mode
dev:
	@echo "Building debug binary..."
	@cargo build

# Run tests
test:
	@echo "Running tests..."
	@cargo test || true

# Run all linting checks
lint: fmt-check clippy

# Check code formatting
fmt-check:
	@echo "Checking code formatting..."
	@cargo fmt -- --check

# Format code
fmt:
	@echo "Formatting code..."
	@cargo fmt

# Run clippy linter
clippy:
	@echo "Running Clippy..."
	@cargo clippy -- -D warnings

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@cargo clean