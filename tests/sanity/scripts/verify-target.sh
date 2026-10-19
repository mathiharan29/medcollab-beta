#!/usr/bin/env bash
set -euo pipefail

target_dir=${1:?target directory is required}
expected_sha=${2:?expected SHA is required}

test "$(git -C "$target_dir" rev-parse HEAD)" = "$expected_sha"
test -z "$(git -C "$target_dir" status --porcelain)"
git -C "$target_dir" diff --quiet
printf 'target_tree=%s\n' "$(git -C "$target_dir" rev-parse HEAD^{tree})"
printf 'backend_lock_sha256=%s\n' "$(sha256sum "$target_dir/medcollab-backend/package-lock.json" | awk '{print $1}')"
