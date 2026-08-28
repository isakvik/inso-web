#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SITE_DIR/_site"
GAME_REPO="${GAME_REPO:-isakvik/inso}"
RELEASE_TAG="${RELEASE_TAG:-}"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/downloads"

if [[ -z "$RELEASE_TAG" ]]; then
    RELEASE_TAG=$(curl -fsSL "https://api.github.com/repos/$GAME_REPO/releases/latest" \
        | sed -n 's/.*"tag_name" *: *"\([^"]*\)".*/\1/p' | head -1 || true)
fi

VERSION="${RELEASE_TAG#[vV]}"
LINUX_DOWNLOAD_URL=
WINDOWS_DOWNLOAD_URL=
RELEASE_PAGE_URL=

if [[ -n "$RELEASE_TAG" ]]; then
    RELEASE_BASE="https://github.com/$GAME_REPO/releases/download/$RELEASE_TAG"
    LINUX_DOWNLOAD_URL="$RELEASE_BASE/inso-${VERSION}-linux-x64.zip"
    WINDOWS_DOWNLOAD_URL="$RELEASE_BASE/inso-${VERSION}-windows-x64.zip"
    RELEASE_PAGE_URL="https://github.com/$GAME_REPO/releases/tag/$RELEASE_TAG"
else
    echo "[gen] warning: no release found on $GAME_REPO, downloads stay placeholders"
fi

for f in index.html CNAME; do
    [[ -f "$SITE_DIR/$f" ]] && cp "$SITE_DIR/$f" "$OUT_DIR/"
done

for d in res images; do
    [[ -d "$SITE_DIR/$d" ]] && cp -r "$SITE_DIR/$d"/. "$OUT_DIR/$d"/
done

if [[ -d "$SITE_DIR/downloads/maps" ]]; then
    cp -r "$SITE_DIR/downloads/maps" "$OUT_DIR/downloads/maps"
fi

replace_placeholder() {
    local file="$1"
    local placeholder="$2"
    local value="$3"

    value="${value//\\/\\\\}"
    value="${value//&/\\&}"
    value="${value//|/\\|}"
    sed -i "s|$placeholder|$value|g" "$file"
}

if [[ -n "$RELEASE_TAG" ]]; then
    while IFS= read -r -d '' file; do
        replace_placeholder "$file" "{{VERSION}}" "$VERSION"
        replace_placeholder "$file" "{{LINUX_DOWNLOAD_URL}}" "$LINUX_DOWNLOAD_URL"
        replace_placeholder "$file" "{{WINDOWS_DOWNLOAD_URL}}" "$WINDOWS_DOWNLOAD_URL"
        replace_placeholder "$file" "{{RELEASE_PAGE_URL}}" "$RELEASE_PAGE_URL"
    done < <(find "$OUT_DIR" -type f -name "*.html" -print0)
fi

echo "[gen] leftover template placeholders:"
grep -rIlE '\{\{[A-Z_]+\}\}' "$OUT_DIR" 2>/dev/null || true

echo "[gen] -------- artifacts --------"
du -sh "$OUT_DIR"
find "$OUT_DIR" -type f -size +100M -print -exec echo "  over 100MB github limit" \;
echo "[gen] done: $OUT_DIR"
