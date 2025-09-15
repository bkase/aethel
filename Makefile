.PHONY: all build build-rust build-swift release release-rust release-swift \
	check check-rust check-swift fmt fmt-rust fmt-swift fmt-fix fmt-fix-rust \
	fmt-fix-swift lint lint-rust lint-swift test test-rust test-swift \
	clean clean-rust clean-swift

# Default target: build, format check, lint, test for both Rust and Swift
all: build fmt lint test

# Build both Rust and Swift
build: build-rust build-swift

# Build the Rust workspace
build-rust:
	cargo build --workspace

# Build the Swift package
build-swift:
	cd AethelSwift && swift build

# Build in release mode
release: release-rust release-swift

# Build the Rust workspace in release mode
release-rust:
	cargo build --workspace --release

# Build the Swift package in release mode
release-swift:
	cd AethelSwift && swift build -c release

# Check for compilation errors without building binaries
check: check-rust check-swift

# Check Rust for compilation errors
check-rust:
	cargo check --workspace

# Check Swift for compilation errors
check-swift:
	cd AethelSwift && swift build --build-tests

# Format code. `check` ensures no unformatted files, `fix` fixes them.
fmt: fmt-rust fmt-swift

# Check Rust formatting
fmt-rust:
	cargo fmt --all -- --check

# Check Swift formatting
fmt-swift:
	cd AethelSwift && ./scripts/run-swift-format.sh lint --recursive Sources/ Tests/

# Fix formatting issues
.PHONY: fmt-fix
fmt-fix: fmt-fix-rust fmt-fix-swift

# Fix Rust formatting
fmt-fix-rust:
	cargo fmt --all

# Fix Swift formatting
fmt-fix-swift:
	cd AethelSwift && ./scripts/run-swift-format.sh format --in-place --recursive Sources/ Tests/

# Run linting
lint: lint-rust lint-swift

# Run clippy for Rust linting. `-D warnings` treats warnings as errors.
lint-rust:
	cargo clippy --workspace --all-targets --all-features -- -D warnings

# Swift linting is handled by swift-format in fmt-swift target
lint-swift:
	@echo "Swift linting completed via swift-format"

# Run all tests
test: test-rust test-swift

# Run all Rust tests in the workspace
test-rust:
	cargo test --workspace

# Run all Swift tests
test-swift:
	cd AethelSwift && swift test

# Clean build artifacts
clean: clean-rust clean-swift

# Clean Rust build artifacts
clean-rust:
	cargo clean

# Clean Swift build artifacts
clean-swift:
	cd AethelSwift && swift package clean

# Run cargo-nextest (if installed via mise) for faster testing (optional but recommended)
.PHONY: nextest
nextest:
	cargo nextest run --workspace

# Run parallel tests for both Rust and Swift
.PHONY: test-parallel
test-parallel:
	@echo "Running Rust tests with nextest..."
	-cargo nextest run --workspace 2>/dev/null || cargo test --workspace
	@echo "Running Swift tests in parallel..."
	cd AethelSwift && swift test --parallel

# Run cargo audit for security vulnerabilities (if installed via mise)
.PHONY: audit
audit:
	cargo audit

# Run cargo udeps to find unused dependencies
.PHONY: udeps
udeps:
	cargo udeps --workspace

# Swift-only targets for convenience
.PHONY: swift-build swift-test swift-fmt swift-clean
swift-build:
	cd AethelSwift && swift build

swift-test:
	cd AethelSwift && swift test

swift-fmt:
	cd AethelSwift && ./scripts/run-swift-format.sh format --in-place --recursive Sources/ Tests/

swift-clean:
	cd AethelSwift && swift package clean

# Rust-only convenience aliases
.PHONY: rust-build rust-test rust-fmt rust-clean
rust-build: build-rust
rust-test: test-rust
rust-fmt: fmt-fix-rust
rust-clean: clean-rust