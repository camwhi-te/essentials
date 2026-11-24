#!/usr/bin/env bash
#
# Debian (WSL) developer bootstrap
#   - System tools (curl, unzip, git, build-essential, htop, ...)
#   - PHP + Composer via php.new
#   - Laravel installer via Composer
#   - Node.js (LTS) via nvm, pnpm via corepack
#
# Usage:  chmod +x setup-dev.sh && ./setup-dev.sh
# Run as your normal user (NOT root) - sudo is used where needed.

set -euo pipefail

PHP_VERSION="8.5"
LOCALE="en_US.UTF-8"        # change to your preferred locale
NVM_FALLBACK_VERSION="v0.40.3"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*"; }

# Append a line to ~/.bashrc only if it isn't already there
add_to_bashrc() {
  grep -qxF "$1" "$HOME/.bashrc" 2>/dev/null || echo "$1" >> "$HOME/.bashrc"
}

if [[ $EUID -eq 0 ]]; then
  echo "Please run this as your normal user, not root. It will call sudo when needed." >&2
  exit 1
fi

sudo -v   # prompt for the password once, up front

# ---------------------------------------------------------------------------
log "Updating system packages"
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get update
sudo -E apt-get -y upgrade

# ---------------------------------------------------------------------------
log "Installing essential packages"
sudo -E apt-get install -y \
  ca-certificates curl wget gnupg \
  unzip zip tar xz-utils file \
  build-essential pkg-config make \
  git git-lfs gh openssh-client \
  htop btop tmux \
  vim nano less man-db bash-completion \
  jq tree ripgrep fd-find bat \
  rsync lsof psmisc procps \
  dnsutils iputils-ping iproute2 \
  sqlite3 \
  locales

# ---------------------------------------------------------------------------
log "Configuring locale ($LOCALE)"
sudo sed -i "s/^# *\(${LOCALE//./\\.}\)/\1/" /etc/locale.gen
sudo locale-gen
sudo update-locale LANG="$LOCALE"

# ---------------------------------------------------------------------------
log "Setting up ~/.local/bin and friendly command names"
mkdir -p "$HOME/.local/bin"
add_to_bashrc 'export PATH="$HOME/.local/bin:$PATH"'
export PATH="$HOME/.local/bin:$PATH"
# Debian renames these binaries to avoid name clashes
command -v fdfind >/dev/null && ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
command -v batcat >/dev/null && ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"

git config --global init.defaultBranch main 2>/dev/null || true

# ---------------------------------------------------------------------------
log "Installing PHP ${PHP_VERSION} + Composer via php.new"
/bin/bash -c "$(curl -fsSL "https://php.new/install/linux/${PHP_VERSION}")"
export PATH="$HOME/.config/herd-lite/bin:$PATH"
add_to_bashrc 'export PATH="$HOME/.config/herd-lite/bin:$PATH"'

php -v
composer --version

# ---------------------------------------------------------------------------
log "Installing Laravel installer via Composer"
composer global require laravel/installer --no-interaction
COMPOSER_BIN="$(composer global config bin-dir --absolute --quiet)"
add_to_bashrc "export PATH=\"$COMPOSER_BIN:\$PATH\""
export PATH="$COMPOSER_BIN:$PATH"

# ---------------------------------------------------------------------------
log "Installing nvm"
NVM_VERSION="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest 2>/dev/null \
  | jq -r '.tag_name // empty' 2>/dev/null || true)"
if [[ -z "$NVM_VERSION" ]]; then
  warn "Couldn't look up the latest nvm release; using $NVM_FALLBACK_VERSION"
  NVM_VERSION="$NVM_FALLBACK_VERSION"
fi
curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

export NVM_DIR="$HOME/.nvm"
set +u                          # nvm.sh is not 'set -u' safe
# shellcheck source=/dev/null
. "$NVM_DIR/nvm.sh"

log "Installing Node.js LTS"
nvm install --lts
nvm alias default 'lts/*'
nvm use default

# ---------------------------------------------------------------------------
log "Enabling corepack + pnpm"
# Newer Node releases (25+) no longer bundle corepack, so install it if missing
if ! command -v corepack >/dev/null; then
  npm install -g corepack
fi
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
add_to_bashrc 'export COREPACK_ENABLE_DOWNLOAD_PROMPT=0'
corepack enable
corepack prepare pnpm@latest --activate
set -u

# ---------------------------------------------------------------------------
log "Cleaning up"
sudo apt-get autoremove -y
sudo apt-get clean

# ---------------------------------------------------------------------------
log "Done! Installed versions:"
echo "  PHP:      $(php -r 'echo PHP_VERSION;')"
echo "  Composer: $(composer --version 2>/dev/null | awk '{print $3}')"
echo "  Laravel:  $(laravel --version 2>/dev/null || echo 'n/a')"
echo "  Node:     $(node -v)"
echo "  npm:      $(npm -v)"
echo "  pnpm:     $(pnpm -v)"
echo "  Git:      $(git --version | awk '{print $3}')"
echo
echo "Restart your terminal (or run: source ~/.bashrc) to pick up the new PATH."
