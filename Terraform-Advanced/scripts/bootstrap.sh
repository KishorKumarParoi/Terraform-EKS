#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'Project root: %s\n' "$project_root"
printf 'This scaffold is ready for cloud-specific entrypoints under clouds/\n'
printf 'Next: copy the environment you want and wire the modules you need.\n'
