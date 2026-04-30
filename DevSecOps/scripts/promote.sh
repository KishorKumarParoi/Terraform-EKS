#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <source-env> <target-env>"
  echo "Example: $0 dev staging"
  exit 1
fi

SOURCE_ENV="$1"
TARGET_ENV="$2"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$ROOT_DIR/gitops/apps/demo-app/overlays/$SOURCE_ENV/kustomization.yaml"
TARGET_FILE="$ROOT_DIR/gitops/apps/demo-app/overlays/$TARGET_ENV/kustomization.yaml"

if [ ! -f "$SOURCE_FILE" ] || [ ! -f "$TARGET_FILE" ]; then
  echo "Source or target overlay file not found."
  exit 1
fi

TAG="$(awk '/newTag:/ {print $2; exit}' "$SOURCE_FILE")"
if [ -z "$TAG" ]; then
  echo "Could not determine tag from $SOURCE_FILE"
  exit 1
fi

sed -i.bak "s/^\([[:space:]]*newTag:[[:space:]]*\).*/\1$TAG/" "$TARGET_FILE"
rm -f "$TARGET_FILE.bak"

echo "Promoted image tag '$TAG' from $SOURCE_ENV to $TARGET_ENV"
