#!/bin/bash
# WP Sync from Construkt server - local version for Claude Code hooks
# Usage: wp-sync-local.sh <repo_dir> <server_user> <domain> [subdirectory]
#
# Example:
#   wp-sync-local.sh ~/projects/ciab/cheeseinabox ciab cheeseinabox.nl
#   wp-sync-local.sh ~/projects/katama/wp-katama katama katama.nl

set -euo pipefail

REPO_DIR="${1:?Usage: wp-sync-local.sh <repo_dir> <server_user> <domain> [subdirectory]}"
SERVER_USER="${2:?Missing server_user}"
DOMAIN="${3:?Missing domain}"
SUBDIR="${4:-}"

# Load Cloudflare Access credentials
eval "$(grep "^CF_ACCESS" "$HOME/.secrets/cloudflare-tunnel-token")"

REMOTE_BASE="/home/${SERVER_USER}/domains/${DOMAIN}/public_html/${SUBDIR}"
SSH_CMD="ssh -o StrictHostKeyChecking=no -i $HOME/.secrets/deploy-key-construkt -o ProxyCommand=\"cloudflared access ssh --hostname deploy.katama.nl --id $CF_ACCESS_CLIENT_ID --secret $CF_ACCESS_CLIENT_SECRET\""

cd "$REPO_DIR"

rsync -rlz --checksum \
  -e "$SSH_CMD" \
  --exclude='uploads' \
  --exclude='cache' \
  --exclude='flying-press-cache' \
  --exclude='flyingpress' \
  --exclude='object-cache.php' \
  --exclude='db.php' \
  --exclude='advanced-cache.php' \
  --exclude='debug.log' \
  --exclude='*.log' \
  "deploy@deploy.katama.nl:${REMOTE_BASE}wp-content/" \
  "./wp-content/"

# Auto-commit als er changes zijn
git add -A
if ! git diff --staged --quiet 2>/dev/null; then
  git commit -m "Auto: synced from server ($(date -u '+%Y-%m-%d %H:%M'))" --quiet
  echo "Changes synced and committed"
else
  echo "Server sync complete (no changes)"
fi
