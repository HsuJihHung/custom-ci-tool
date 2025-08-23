#!/bin/bash
set -euo pipefail

# === Setup config ===
TOOL_NAME="ci-tool"
TOOL_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_BIN="$TOOL_SOURCE/$TOOL_NAME"
COMP_SCRIPT="$TOOL_SOURCE/${TOOL_NAME}-completion.bash"

# Install locations
LOCAL_BIN="$HOME/.local/bin"
COMPLETION_DIR="$HOME/.ci-tool"
BASHRC="$HOME/.bashrc"

mkdir -p "$LOCAL_BIN" "$COMPLETION_DIR"

# === 1. Symlink ci-tool to ~/.local/bin ===
mkdir -p "$LOCAL_BIN"

if [[ ! -x "$TOOL_BIN" ]]; then
  echo "Source script not found or not executable: $TOOL_BIN"
  exit 1
fi

ln -sf "$TOOL_BIN" "$LOCAL_BIN/$TOOL_NAME"
echo "Symlinked $TOOL_NAME to $LOCAL_BIN"

# === 2. Install auto-completion script ===
cp "$COMP_SCRIPT" "$COMPLETION_DIR/${TOOL_NAME}-completion.bash"
echo "Autocomplete script installed to $COMPLETION_DIR"

# === 3. Update ~/.bashrc ===
NEED_RELOAD=false

# Add ~/.local/bin to PATH if missing
if ! grep -qF "$LOCAL_BIN" "$BASHRC"; then
  echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >> "$BASHRC"
  echo "Added $LOCAL_BIN to PATH in $BASHRC"
  NEED_RELOAD=true
fi

# Add completion script sourcing
COMPLETION_LINE="source \"$COMPLETION_DIR/${TOOL_NAME}-completion.bash\""
if ! grep -Fxq "$COMPLETION_LINE" "$BASHRC"; then
  echo "" >> "$BASHRC"
  echo "# Enable $TOOL_NAME autocomplete" >> "$BASHRC"
  echo "$COMPLETION_LINE" >> "$BASHRC"
  echo "Added autocomplete source to $BASHRC"
  NEED_RELOAD=true
fi

# === 4. Final message ===
echo ""
echo "Setup complete!"

if [ "$NEED_RELOAD" = true ]; then
  echo "Please run the following to apply changes now:"
  echo ""
  echo "   source ~/.bashrc"
  echo ""
else
  echo "You're all set! Try:  ci-tool [TAB]"
fi
