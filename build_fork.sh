#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <fork-name>" >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fork_dir="$repo_root/forks/$1"

if [[ ! -d "$fork_dir" ]]; then
    "$repo_root"/fork_dub_package "$1"
fi

if [[ ! -d "$fork_dir" ]]; then
    echo "Fork not found: $fork_dir" >&2
    exit 1
fi

export DFLAGS="-preview=dip1000"

dub build --root="$fork_dir" --build=unittest
