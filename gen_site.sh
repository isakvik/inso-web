#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SITE_DIR/_site"
GAME_REPO="${GAME_REPO:-isakvik/inso}"
RELEASE_TAG="${RELEASE_TAG:-}"
DOCS_GENERATOR="${DOCS_GENERATOR:-$SITE_DIR/.build/docsgen}"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/downloads"

if [[ -z "$RELEASE_TAG" ]]; then
    echo "[gen] resolving latest release for $GAME_REPO"
    if ! RELEASE_TAG=$(curl -fsSL --retry 3 --retry-delay 1 "https://api.github.com/repos/$GAME_REPO/releases/latest" \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'); then
        echo "[gen] error: could not resolve the latest release for $GAME_REPO" >&2
        exit 1
    fi
fi

if [[ -z "$RELEASE_TAG" ]]; then
    echo "[gen] error: no release tag was provided or found for $GAME_REPO" >&2
    exit 1
fi

VERSION="${RELEASE_TAG#[vV]}"
if [[ -z "$VERSION" ]]; then
    echo "[gen] error: release tag $RELEASE_TAG has no version" >&2
    exit 1
fi

LINUX_DOWNLOAD_URL=
WINDOWS_DOWNLOAD_URL=
RELEASE_PAGE_URL=
LUA_API_ARCHIVE_URL=

RELEASE_BASE="https://github.com/$GAME_REPO/releases/download/$RELEASE_TAG"
LINUX_DOWNLOAD_URL="$RELEASE_BASE/inso-${VERSION}-linux-x64.zip"
WINDOWS_DOWNLOAD_URL="$RELEASE_BASE/inso-${VERSION}-windows-x64.zip"
RELEASE_PAGE_URL="https://github.com/$GAME_REPO/releases/tag/$RELEASE_TAG"
LUA_API_ARCHIVE_URL="$LINUX_DOWNLOAD_URL"

check_release_asset() {
    local platform="$1"
    local url="$2"

    echo "[gen] checking $platform release asset"
    if ! curl -fsSLI --retry 3 --retry-delay 1 --max-time 30 "$url" >/dev/null; then
        echo "[gen] error: $platform release asset is unavailable: $url" >&2
        exit 1
    fi
}

check_release_asset "linux" "$LINUX_DOWNLOAD_URL"
check_release_asset "windows" "$WINDOWS_DOWNLOAD_URL"

for f in index.html CNAME; do
    [[ -f "$SITE_DIR/$f" ]] && cp "$SITE_DIR/$f" "$OUT_DIR/"
done

for d in res images; do
    [[ -d "$SITE_DIR/$d" ]] && cp -r "$SITE_DIR/$d"/. "$OUT_DIR/$d"/
done

if [[ ! -x "$DOCS_GENERATOR" || "$SITE_DIR/tools/docsgen/main.odin" -nt "$DOCS_GENERATOR" ]]; then
    command -v odin >/dev/null || {
        echo "[gen] error: odin is required to build the docs generator" >&2
        exit 1
    }
    mkdir -p "$(dirname "$DOCS_GENERATOR")"
    echo "[gen] building docs generator"
    odin build "$SITE_DIR/tools/docsgen" -out:"$DOCS_GENERATOR" -o:speed
fi

"$DOCS_GENERATOR" "$SITE_DIR/content/docs" "$OUT_DIR"

if [[ -n "$LUA_API_ARCHIVE_URL" ]]; then
    release_archive=$(mktemp)
    trap 'rm -f "$release_archive"' EXIT
    echo "[gen] fetching generated lua docs"
    curl -fsSL "$LUA_API_ARCHIVE_URL" -o "$release_archive"
    if ! unzip -Z1 "$release_archive" | grep -Fx 'docs/lua_api.html' >/dev/null; then
        echo "[gen] error: release archive does not contain docs/lua_api.html" >&2
        exit 1
    fi
    if ! unzip -p "$release_archive" docs/lua_api.html > "$OUT_DIR/docs/lua_api.html"; then
        echo "[gen] error: could not extract docs/lua_api.html" >&2
        exit 1
    fi
    if [[ ! -s "$OUT_DIR/docs/lua_api.html" ]]; then
        echo "[gen] error: extracted docs/lua_api.html is empty" >&2
        exit 1
    fi
fi

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

leftover_placeholders=$(grep -rIlE '\{\{[A-Z_]+\}\}' "$OUT_DIR" 2>/dev/null || true)
if [[ -n "$leftover_placeholders" ]]; then
    echo "[gen] error: leftover template placeholders:" >&2
    printf '%s\n' "$leftover_placeholders" >&2
    exit 1
fi

echo "[gen] -------- artifacts --------"
du -sh "$OUT_DIR"
find "$OUT_DIR" -type f -size +100M -print -exec echo "  over 100MB github limit" \;
echo "[gen] done: $OUT_DIR"
