#!/bin/bash

# Build and serve the Sphinx RST documentation locally with full CSS/theme support.
# Uses uv to create an isolated venv with all required dependencies.
# Usage: ./serve_docs.sh [port]
#   port  TCP port for the web server (default: 8080)

set -e

PORT="${1:-8080}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC_SRC="$SCRIPT_DIR/doc/src"
BUILD_DIR="$DOC_SRC/_build/html"
VENV_DIR="$SCRIPT_DIR/.docs-venv"

# Ensure uv is available
if ! command -v uv &>/dev/null; then
    echo "ERROR: uv not found. Install with:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Create venv and install deps if sphinx-build is missing
if [ ! -x "$VENV_DIR/bin/sphinx-build" ]; then
    echo "==> Setting up docs venv in $VENV_DIR ..."
    uv venv "$VENV_DIR" --python python3
    uv pip install \
        --python "$VENV_DIR/bin/python" \
        sphinx \
        sphinx-rtd-theme \
        "sphinxcontrib-jquery" \
        mock \
        breathe \
        rst2pdf \
        "sphinxcontrib-httpdomain"
    echo ""
fi

SPHINX_BUILD="$VENV_DIR/bin/sphinx-build"

echo "==> Building docs in $DOC_SRC ..."
PYTHON_SKIP_SWAGGERDOC=1 \
    "$SPHINX_BUILD" -b html \
    -d "$DOC_SRC/_build/doctrees" \
    -D "extensions=sphinxcontrib.jquery,sphinx.ext.intersphinx,sphinx.ext.autodoc,rst2pdf.pdfbuilder" \
    "$DOC_SRC" "$BUILD_DIR"

echo ""
echo "==> Docs built. Open: http://localhost:$PORT"
echo "    Press Ctrl+C to stop."
echo ""

cd "$BUILD_DIR"
exec python3 -m http.server "$PORT"
