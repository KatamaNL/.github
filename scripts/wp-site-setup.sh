#!/bin/bash
# Setup a new WP site for GitHub deploy
# Usage: wp-site-setup.sh <server_user> <domain> <repo_name>
#
# Example:
#   wp-site-setup.sh ciab cheeseinabox.nl cheeseinabox
#   wp-site-setup.sh cocobe frietzakjes.nl wp-cocobe-frietzakjes
#
# Prerequisites:
# - KatamaNL org secrets set (DEPLOY_SSH_KEY, CF_ACCESS_CLIENT_ID, CF_ACCESS_CLIENT_SECRET)
# - cloudflared tunnel running on server
# - deploy user exists on server

set -euo pipefail

SERVER_USER="${1:?Usage: wp-site-setup.sh <server_user> <domain> <repo_name>}"
DOMAIN="${2:?Missing domain}"
REPO_NAME="${3:?Missing repo_name}"

echo "=== Setting up $DOMAIN (user: $SERVER_USER, repo: KatamaNL/$REPO_NAME) ==="

# 1. ACL op server
echo "1. Setting ACL on server..."
eval "$(grep "^CF_ACCESS" "$HOME/.secrets/cloudflare-tunnel-token")"
SSH_CMD="ssh -o StrictHostKeyChecking=no -i $HOME/.secrets/deploy-key-construkt -o ProxyCommand=\"cloudflared access ssh --hostname deploy.katama.nl --id $CF_ACCESS_CLIENT_ID --secret $CF_ACCESS_CLIENT_SECRET\""

# ACL via katama user (deploy user kan geen ACLs zetten)
ssh -o StrictHostKeyChecking=no -o "ProxyCommand=cloudflared access ssh --hostname deploy.katama.nl --id $CF_ACCESS_CLIENT_ID --secret $CF_ACCESS_CLIENT_SECRET" katama@deploy.katama.nl "
  printf '%s\n' \"\$(cat ~/.secrets/construkt_root_pw 2>/dev/null || echo 'NEED_ROOT_PW')\" | su -c \"
    setfacl -R -m u:deploy:rwX /home/$SERVER_USER/domains/$DOMAIN/public_html
    setfacl -d -R -m u:deploy:rwX /home/$SERVER_USER/domains/$DOMAIN/public_html
    echo 'ACL set for /home/$SERVER_USER/domains/$DOMAIN/public_html'
  \" 2>&1
"

echo ""
echo "2. Verify deploy user access..."
eval "$(grep "^CF_ACCESS" "$HOME/.secrets/cloudflare-tunnel-token")"
ssh -o StrictHostKeyChecking=no -i "$HOME/.secrets/deploy-key-construkt" -o "ProxyCommand=cloudflared access ssh --hostname deploy.katama.nl --id $CF_ACCESS_CLIENT_ID --secret $CF_ACCESS_CLIENT_SECRET" deploy@deploy.katama.nl "ls /home/$SERVER_USER/domains/$DOMAIN/public_html/wp-content/ | head -5 && echo 'Access OK'"

echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  1. Create repo workflows (copy from KatamaNL/.github examples)"
echo "  2. Set server_user=$SERVER_USER and domain=$DOMAIN in workflow files"
echo "  3. Push to main to trigger first deploy"
