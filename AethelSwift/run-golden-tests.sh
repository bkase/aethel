#!/bin/bash
set -e

# Build the Swift implementation
echo "Building Swift implementation..."
swift build

# Path to test cases
CASES_DIR="/Users/bkase/Documents/aethel/tests/cases"
SWIFT_CLI="/Users/bkase/Documents/aethel/AethelSwift/.build/debug/aethel"
TEMP_BASE="/tmp/swift-golden-tests"

# Clean and create temp directory
rm -rf "$TEMP_BASE"
mkdir -p "$TEMP_BASE"

echo "Running golden tests..."

# Track results
PASSED=0
FAILED=0
FAILED_TESTS=()

for case_dir in "$CASES_DIR"/*; do
    if [[ -d "$case_dir" ]]; then
        case_name=$(basename "$case_dir")
        echo -n "Testing $case_name... "
        
        # Create test workspace
        test_dir="$TEMP_BASE/$case_name"
        mkdir -p "$test_dir"
        
        # Copy vault.before as-is (don't reorganize directory structure)
        cp -r "$case_dir/vault.before" "$test_dir/vault"
        mkdir -p "$test_dir/vault/.aethel"
        
        # Read test parameters
        cli_args=$(cat "$case_dir/cli-args.txt")
        # Replace relative paths that start with tests/cases with absolute paths
        cli_args=$(echo "$cli_args" | sed "s|tests/cases|/Users/bkase/Documents/aethel/tests/cases|g")
        expect_exit=$(cat "$case_dir/expect.exit.txt" | tr -d '\n')
        
        # Read environment variables if they exist
        now_arg=""
        uuid_seed_arg=""
        if [[ -f "$case_dir/env.json" ]]; then
            if command -v jq > /dev/null; then
                now_val=$(jq -r '."--now" // empty' "$case_dir/env.json")
                uuid_seed_val=$(jq -r '."--uuid-seed" // empty' "$case_dir/env.json")
                if [[ -n "$now_val" ]]; then
                    now_arg="--now $now_val"
                fi
                if [[ -n "$uuid_seed_val" ]]; then
                    uuid_seed_arg="--uuid-seed $uuid_seed_val"
                fi
            fi
        fi
        
        # Run the command
        exit_code=0
        if [[ -f "$case_dir/input.json" ]]; then
            cat "$case_dir/input.json" | "$SWIFT_CLI" $cli_args --vault-root "$test_dir/vault" $now_arg $uuid_seed_arg > "$test_dir/actual_output.json" 2>&1 || exit_code=$?
        else
            "$SWIFT_CLI" $cli_args --vault-root "$test_dir/vault" $now_arg $uuid_seed_arg > "$test_dir/actual_output.json" 2>&1 || exit_code=$?
        fi
        
        # Check exit code
        if [[ "$exit_code" != "$expect_exit" ]]; then
            echo "FAIL (exit code: expected $expect_exit, got $exit_code)"
            FAILED=$((FAILED + 1))
            FAILED_TESTS+=("$case_name")
            continue
        fi
        
        # Check output
        if [[ -f "$case_dir/expect.stdout.json" ]]; then
            if command -v jq > /dev/null; then
                # Compare JSON semantically
                if ! jq --slurpfile a "$case_dir/expect.stdout.json" --slurpfile b "$test_dir/actual_output.json" -n '$a == $b' > /dev/null; then
                    echo "FAIL (JSON output mismatch)"
                    echo "Expected:"
                    cat "$case_dir/expect.stdout.json"
                    echo "Actual:"
                    cat "$test_dir/actual_output.json"
                    FAILED=$((FAILED + 1))
                    FAILED_TESTS+=("$case_name")
                    continue
                fi
            else
                # Fallback to text comparison
                if ! diff -q "$case_dir/expect.stdout.json" "$test_dir/actual_output.json" > /dev/null; then
                    echo "FAIL (output mismatch)"
                    FAILED=$((FAILED + 1))
                    FAILED_TESTS+=("$case_name")
                    continue
                fi
            fi
        fi
        
        # Check vault.after if it exists
        if [[ -d "$case_dir/vault.after" ]]; then
            # Compare vault states, excluding .aethel directory
            if ! diff -r --exclude=".aethel" "$test_dir/vault" "$case_dir/vault.after" > /dev/null; then
                echo "FAIL (vault state mismatch)"
                FAILED=$((FAILED + 1))
                FAILED_TESTS+=("$case_name")
                continue
            fi
        fi
        
        echo "PASS"
        PASSED=$((PASSED + 1))
    fi
done

echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests: ${FAILED_TESTS[*]}"
    exit 1
fi

echo "All golden tests passed! 🎉"