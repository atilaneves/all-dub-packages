#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures_file="$repo_root/new-test-failures.txt"
build_script="$repo_root/build_fork.sh"

if [[ ! -x "$build_script" ]]; then
    echo "Required script not found or not executable: $build_script" >&2
    exit 1
fi

if [[ ! -f "$failures_file" ]]; then
    echo "Fork list not found: $failures_file" >&2
    exit 1
fi

while IFS= read -r fork_name; do
    [[ -z "$fork_name" ]] && continue
    echo "Building fork: $fork_name"
    if ! "$build_script" "$fork_name"; then
        echo "Failed to build $fork_name" >&2
    fi
done < "$failures_file"
