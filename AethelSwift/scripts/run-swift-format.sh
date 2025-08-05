#!/bin/bash
set -e

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Run swift-format using Swift Package Manager
cd "$PROJECT_ROOT/BuildTools"
swift run swift-format "$@"