# CI/CD Documentation

This repository uses GitHub Actions for continuous integration and deployment, with workflows optimized for concurrent execution of Rust and Swift builds.

## Workflows

### Main CI (`ci.yml`)
Runs on pushes to `main` and all pull requests.

**Jobs run in parallel:**

1. **Format & Lint** (Parallel matrix)
   - Rust: Runs on Ubuntu with `make fmt-rust` and `make lint-rust`
   - Swift: Runs on macOS with `make fmt-swift` and `make lint-swift`

2. **Test** (Parallel matrix)
   - Rust: Builds and tests on Ubuntu
   - Swift: Builds and tests on macOS

3. **Cross-Platform Testing**
   - Rust: Tests on Ubuntu, macOS, and Windows
   - Swift: Tests on macOS and iOS Simulator

4. **CI Success Gate**
   - Ensures all required jobs pass before marking CI as successful

### PR Quick Check (`pr-quick.yml`)
Lightweight checks for pull requests.

- Runs `make all` on macOS (both Rust and Swift)
- Runs Rust-only checks on Ubuntu
- Faster feedback for PR authors

### Release Build (`release.yml`)
Triggered by version tags (`v*`) or manual workflow dispatch.

**Parallel builds for:**
- Rust binaries: Linux x86_64, macOS x86_64, macOS ARM64, Windows x86_64
- Swift frameworks: macOS Universal, iOS

Creates a draft GitHub release with all artifacts.

## Parallelization Strategy

The workflows leverage GitHub Actions' matrix strategy to run jobs concurrently:

```yaml
strategy:
  matrix:
    include:
      - name: Rust
        os: ubuntu-latest
        # ... commands
      - name: Swift
        os: macos-latest
        # ... commands
```

This means:
- Rust and Swift checks run simultaneously
- Different platforms are tested in parallel
- Total CI time is the maximum of any single job, not the sum

## Local Development

The same commands used in CI can be run locally:

```bash
# Run everything (build, format, lint, test)
make all

# Run tests in parallel
make test-parallel

# Language-specific commands
make rust-test
make swift-test
```

## Performance Optimizations

1. **Matrix builds**: Rust and Swift run concurrently
2. **OS-specific runners**: Rust primarily on Linux (faster), Swift on macOS (required)
3. **Cached dependencies**: mise and cargo caches persist between runs
4. **Parallel tests**: Both `cargo test` and `swift test --parallel` utilize multiple cores

## Required Secrets

No additional secrets needed beyond the default `GITHUB_TOKEN` for releases.

## Branch Protection

Recommended settings for `main`:
- Require status checks: `CI Success`
- Require branches to be up to date
- Require conversation resolution
- Require signed commits (optional)