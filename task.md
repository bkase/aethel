# Use makefile and ci

**Status:** InProgress
**Agent PID:** 51736

## Original Todo

Use a makefile instead and make the GitHub Actions workflow ignore running when Markdown files change or you know, stuff in docs. Basically, you can look at the ~/Documents/momentum/ GitHub Actions workflow for example. Include make build, make lint, make test (for now if there are no tests, just return true)

## Description

Create a Makefile for common development tasks and set up a GitHub Actions CI workflow that ignores documentation changes. This will standardize the build process and ensure CI runs only when code changes are made.

## Implementation Plan

- [ ] Create Makefile with standard Rust targets (Makefile)
- [ ] Create .github/workflows/ci.yml with paths-ignore configuration (.github/workflows/ci.yml)
- [ ] Add make targets: build, test, lint (includes fmt check and clippy)
- [ ] Configure CI to use Makefile targets and cache Cargo dependencies
- [ ] Verify CI workflow syntax and Makefile functionality

## Notes

Based on momentum project's CI setup, implementing paths-ignore for docs and using standard Rust tooling through Make targets.