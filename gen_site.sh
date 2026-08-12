#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SITE_DIR/_site"
GAME_REPO="${GAME_REPO:-isakvik/inso}"
RELEASE_TAG="${RELEASE_TAG:-}"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/downloads" "$OUT_DIR/docs"

if [[ -z "$RELEASE_TAG" ]]; then
    RELEASE_TAG=$(curl -fsSL "https://api.github.com/repos/$GAME_REPO/releases/latest" \
        | sed -n 's/.*"tag_name" *: *"\([^"]*\)".*/\1/p' | head -1 || true)
fi

VERSION="${RELEASE_TAG#v}"

if [[ -n "$RELEASE_TAG" ]]; then
    LINUX_ZIP="inso-${VERSION}-linux-x64.zip"
    WINDOWS_ZIP="inso-${VERSION}-windows-x64.zip"
    for zip in "$LINUX_ZIP" "$WINDOWS_ZIP"; do
        if curl -fsSL -o "$OUT_DIR/downloads/$zip" \
            "https://github.com/$GAME_REPO/releases/download/$RELEASE_TAG/$zip"; then
            unzip -j -o "$OUT_DIR/downloads/$zip" "docs/lua_api.html" -d "$OUT_DIR/docs" >/dev/null 2>&1 || true
        else
            echo "[gen] skipping unavailable asset: $zip"
        fi
    done
else
    echo "[gen] warning: no release found on $GAME_REPO, downloads stay placeholders"
fi

for f in index.html CNAME; do
    [[ -f "$SITE_DIR/$f" ]] && cp "$SITE_DIR/$f" "$OUT_DIR/"
done

for d in css js images; do
    [[ -d "$SITE_DIR/$d" ]] && cp -r "$SITE_DIR/$d"/. "$OUT_DIR/$d"/
done

if [[ -d "$SITE_DIR/downloads/maps" ]]; then
    cp -r "$SITE_DIR/downloads/maps" "$OUT_DIR/downloads/maps"
fi

if [[ -n "$VERSION" ]]; then
    find "$OUT_DIR" -maxdepth 2 -name "*.html" -exec sed -i "s/{{VERSION}}/$VERSION/g" {} +
fi

echo "[gen] leftover {{VERSION}} placeholders:"
grep -rl "{{VERSION}}" "$OUT_DIR" 2>/dev/null || true

echo "[gen] -------- artifacts --------"
du -sh "$OUT_DIR"
find "$OUT_DIR" -type f -size +100M -print -exec echo "  over 100MB github limit" \;
echo "[gen] done: $OUT_DIR"