#!/usr/bin/env bash
# =============================================================================
# install.sh -- Cross-Platform Auto-Installer for R-TRCE (Linux & macOS)
# =============================================================================
# USAGE:
#   curl -fsSL https://raw.githubusercontent.com/AsterovLabs/R-TRCE/main/install.sh | bash
#   OR locally:
#   ./install.sh
# =============================================================================

set -e

REPO_URL="https://github.com/AsterovLabs/R-TRCE.git"
INSTALL_DIR="${R_TRCE_HOME:-$HOME/.r-trce}"
BIN_DIR="$HOME/.local/bin"

# Styling
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}"
echo "  ____        _____ ____   ____ _____ "
echo " |  _ \      |_   _|  _ \ / ___| ____|"
echo " | |_) |____   | | | |_) | |   |  _|  "
echo " |  _ <|____|  | | |  _ <| |___| |___ "
echo " |_| \_\       |_| |_| \_\\____|_____|"
echo -e "${NC}"
echo -e "${BOLD}R-TRCE: Architectural Comprehension & Student Tutor Suite${NC}"
echo -e "Installing to: ${YELLOW}${INSTALL_DIR}${NC}\n"

# 1. Detect Operating System
OS="$(uname -s)"
case "$OS" in
  Linux*)   PLATFORM="Linux" ;;
  Darwin*)  PLATFORM="macOS" ;;
  *)        PLATFORM="Unknown ($OS)" ;;
esac
echo -e "Detected OS: ${GREEN}${PLATFORM}${NC}"

# 2. Locate R / Rscript
echo -n "Checking for R / Rscript... "
RSCRIPT_BIN=""

if [ -n "$R_ENV" ] && [ -x "$R_ENV/bin/Rscript" ]; then
  RSCRIPT_BIN="$R_ENV/bin/Rscript"
elif [ -x "$HOME/.r-env/bin/Rscript" ]; then
  RSCRIPT_BIN="$HOME/.r-env/bin/Rscript"
elif command -v Rscript >/dev/null 2>&1; then
  RSCRIPT_BIN="$(command -v Rscript)"
fi

if [ -n "$RSCRIPT_BIN" ]; then
  R_VER="$("$RSCRIPT_BIN" --version 2>&1 | head -n 1)"
  echo -e "${GREEN}Found!${NC} ($R_VER at $RSCRIPT_BIN)"
else
  echo -e "${YELLOW}Not detected.${NC}"
  echo -e "\n${YELLOW}[!] R is required for R-TRCE to execute.${NC}"
  echo "Please install R using your system package manager:"
  if [ "$PLATFORM" = "macOS" ]; then
    echo "  brew install r"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "  sudo apt update && sudo apt install -y r-base"
  elif command -v dnf >/dev/null 2>&1; then
    echo "  sudo dnf install -y R"
  elif command -v pacman >/dev/null 2>&1; then
    echo "  sudo pacman -S r"
  elif command -v apk >/dev/null 2>&1; then
    echo "  sudo apk add R R-dev"
  else
    echo "  Visit https://cran.r-project.org to download R for your system."
  fi
  echo ""
  read -p "Continue installation anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
  RSCRIPT_BIN="Rscript"
fi

# 3. Download or Copy Repository
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if [ -f "$SCRIPT_DIR/r_trce.R" ] && [ -d "$SCRIPT_DIR/R" ]; then
  echo "Installing from local directory: $SCRIPT_DIR"
  cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"
else
  echo "Fetching latest R-TRCE release from GitHub..."
  if command -v git >/dev/null 2>&1; then
    if [ -d "$INSTALL_DIR/.git" ]; then
      echo "Updating existing installation in $INSTALL_DIR..."
      cd "$INSTALL_DIR" && git pull --quiet
    else
      git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
    fi
  else
    TAR_URL="https://github.com/AsterovLabs/R-TRCE/archive/refs/heads/main.tar.gz"
    echo "Downloading archive via curl/tar..."
    curl -fsSL "$TAR_URL" | tar -xz --strip-components=1 -C "$INSTALL_DIR"
  fi
fi

# 4. Check & Install Required R Packages (jsonlite, shiny)
if [ -x "$RSCRIPT_BIN" ] || command -v "$RSCRIPT_BIN" >/dev/null 2>&1; then
  echo -n "Checking required R packages (jsonlite, shiny)... "
  MISSING_PKGS="$("$RSCRIPT_BIN" -e '
    pkgs <- c("jsonlite", "shiny")
    missing <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
    cat(paste(missing, collapse = " "))
  ' 2>/dev/null || true)"

  if [ -z "$MISSING_PKGS" ]; then
    echo -e "${GREEN}All installed!${NC}"
  else
    echo -e "${YELLOW}Missing: $MISSING_PKGS${NC}"
    echo "Installing missing packages ($MISSING_PKGS) from CRAN..."
    "$RSCRIPT_BIN" -e "install.packages(strsplit('$MISSING_PKGS', ' ')[[1]], repos='https://cloud.r-project.org', quiet=TRUE)" || {
      echo -e "${YELLOW}[!] Warning: Automatic package install failed. You may need to run: install.packages(c('jsonlite', 'shiny')) manually inside R.${NC}"
    }
  fi
fi

# 5. Create Executable Wrappers in ~/.local/bin
echo "Creating CLI and Studio executable wrappers..."

# r-trce wrapper
cat << 'EOF' > "$BIN_DIR/r-trce"
#!/usr/bin/env bash
INSTALL_DIR="__INSTALL_DIR__"
R_BIN="__RSCRIPT_BIN__"

if [ ! -x "$R_BIN" ] && command -v Rscript >/dev/null 2>&1; then
  R_BIN="$(command -v Rscript)"
fi

if [ ! -x "$R_BIN" ]; then
  echo "Error: Rscript not found. Please install R or ensure it is on your PATH." >&2
  exit 1
fi

exec "$R_BIN" "$INSTALL_DIR/r_trce.R" "$@"
EOF

# r-trce-studio wrapper
cat << 'EOF' > "$BIN_DIR/r-trce-studio"
#!/usr/bin/env bash
INSTALL_DIR="__INSTALL_DIR__"
R_BIN="__RSCRIPT_BIN__"

if [ ! -x "$R_BIN" ] && command -v Rscript >/dev/null 2>&1; then
  R_BIN="$(command -v Rscript)"
fi

if [ ! -x "$R_BIN" ]; then
  echo "Error: Rscript not found. Please install R or ensure it is on your PATH." >&2
  exit 1
fi

PORT="${PORT:-8083}"
HOST="${HOST:-127.0.0.1}"

echo "Starting R-TRCE Interactive Studio on http://${HOST}:${PORT} ..."
# Try opening browser in background
(sleep 1.5 && (xdg-open "http://${HOST}:${PORT}" >/dev/null 2>&1 || open "http://${HOST}:${PORT}" >/dev/null 2>&1 || true)) &

exec "$R_BIN" "$INSTALL_DIR/app.R"
EOF

# Substitute actual paths
sed -i "s|__INSTALL_DIR__|$INSTALL_DIR|g" "$BIN_DIR/r-trce" "$BIN_DIR/r-trce-studio"
sed -i "s|__RSCRIPT_BIN__|$RSCRIPT_BIN|g" "$BIN_DIR/r-trce" "$BIN_DIR/r-trce-studio"

chmod +x "$BIN_DIR/r-trce" "$BIN_DIR/r-trce-studio"

# 6. Verify PATH integration
PATH_CONFIGURED=false
if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
  PATH_CONFIGURED=true
fi

if [ "$PATH_CONFIGURED" = false ]; then
  SHELL_PROFILE=""
  if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    SHELL_PROFILE="$HOME/.bashrc"
  elif [ -n "$ZSH_VERSION" ] && [ -f "$HOME/.zshrc" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
  elif [ -f "$HOME/.profile" ]; then
    SHELL_PROFILE="$HOME/.profile"
  fi

  if [ -n "$SHELL_PROFILE" ]; then
    if ! grep -q "$BIN_DIR" "$SHELL_PROFILE" 2>/dev/null; then
      echo -e "\nexport PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_PROFILE"
      echo -e "${GREEN}Added ~/.local/bin to $SHELL_PROFILE${NC}"
    fi
  fi
fi

echo -e "\n${GREEN}=================================================================="
echo -e "  R-TRCE installed successfully!"
echo -e "==================================================================${NC}\n"
echo -e "Quick Start Commands:"
echo -e "  ${BOLD}r-trce tutor script.R${NC}       Student walkthrough & pitfall audit"
echo -e "  ${BOLD}r-trce pitfalls script.R${NC}    Quick beginner pitfall sentinel"
echo -e "  ${BOLD}r-trce quiz script.R${NC}        Generate student comprehension quiz"
echo -e "  ${BOLD}r-trce explain script.R${NC}     Full architectural explanation"
echo -e "  ${BOLD}r-trce-studio${NC}               Launch interactive web studio"
echo ""
if [ "$PATH_CONFIGURED" = false ]; then
  echo -e "${YELLOW}Note: To use commands immediately in this terminal, run:${NC}"
  echo -e "  ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}\n"
fi
