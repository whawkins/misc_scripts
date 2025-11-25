#!/bin/bash
set -euo pipefail

# ------------------------------
# PROFILE MENU
# ------------------------------

choose_profile() {
  echo ""
  echo "==========================="
  echo " AWS SSO Credential Refresh"
  echo "==========================="
  echo ""
  echo "Select an AWS SSO profile:"
  echo "  1) jem_non_prod"
  echo "  2) jem_prod"
  echo "  q) Quit"
  echo ""

  read -p "Enter choice: " choice

  case "$choice" in
    1) TARGET_PROFILE="jem_non_prod" ;;
    2) TARGET_PROFILE="jem_prod" ;;
    q|Q) echo "Bye."; exit 0 ;;
    *)
      echo "❌ Invalid choice"
      exit 1
      ;;
  esac
}

# If no argument passed → show menu
if [ $# -eq 0 ]; then
  choose_profile
else
  TARGET_PROFILE="$1"
fi


# ------------------------------
# SSO login profile = target
# ------------------------------

SSO_PROFILE="$TARGET_PROFILE"

echo ""
echo "🔐 Updating AWS credentials for: [$TARGET_PROFILE]"
echo "Using SSO login profile:       [$SSO_PROFILE]"
echo ""

# ------------------------------
# 1. SSO login
# ------------------------------
aws sso login --profile "$SSO_PROFILE"


# ------------------------------
# 2. Get this profile's SSO start URL
# ------------------------------
START_URL=$(aws configure get sso_start_url --profile "$SSO_PROFILE")

if [ -z "$START_URL" ]; then
  echo "❌ ERROR: Profile [$SSO_PROFILE] is not an SSO profile."
  exit 1
fi


# ------------------------------
# 3. Find correct SSO token file for this start URL
# ------------------------------
CACHE_DIR="$HOME/.aws/sso/cache"
TOKEN_FILE=$(grep -l "$START_URL" "$CACHE_DIR"/*.json | head -n 1)

if [ ! -f "$TOKEN_FILE" ]; then
  echo "❌ Could not find SSO token for Start URL: $START_URL"
  exit 1
fi

ACCESS_TOKEN=$(jq -r '.accessToken' "$TOKEN_FILE")

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
  echo "❌ ERROR: No valid SSO access token found."
  exit 1
fi


# ------------------------------
# 4. Map CLI profile → SSO accountName (for your environment)
# ------------------------------
case "$TARGET_PROFILE" in
  jem_prod)
    ACCOUNT_NAME="app-gsmd-prod"
    ;;
  jem_non_prod)
    ACCOUNT_NAME="app-gsmd-nonprod"
    ;;
  *)
    echo "❌ Profile [$TARGET_PROFILE] does not map to an SSO account."
    exit 1
    ;;
esac

echo "➡️  AWS SSO accountName = $ACCOUNT_NAME"


# ------------------------------
# 5. Look up accountId from SSO
# ------------------------------
ACCOUNT_ID=$(aws sso list-accounts \
    --access-token "$ACCESS_TOKEN" \
    --query "accountList[?accountName=='$ACCOUNT_NAME'].accountId" \
    --output text)

if [ -z "$ACCOUNT_ID" ]; then
  echo "❌ ERROR: Cannot find accountId for accountName: $ACCOUNT_NAME"
  exit 1
fi

echo "➡️  accountId = $ACCOUNT_ID"


# ------------------------------
# 6. Find a roleName in this account
# ------------------------------
ROLE_NAME=$(aws sso list-account-roles \
    --access-token "$ACCESS_TOKEN" \
    --account-id "$ACCOUNT_ID" \
    --query "roleList[0].roleName" \
    --output text)

if [ -z "$ROLE_NAME" ]; then
  echo "❌ No roles available in SSO for account: $ACCOUNT_NAME"
  exit 1
fi

echo "➡️  roleName = $ROLE_NAME"


# ------------------------------
# 7. Fetch role credentials
# ------------------------------
CREDS_JSON=$(aws sso get-role-credentials \
    --access-token "$ACCESS_TOKEN" \
    --account-id "$ACCOUNT_ID" \
    --role-name "$ROLE_NAME")

AWS_ACCESS_KEY_ID=$(echo "$CREDS_JSON" | jq -r '.roleCredentials.accessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo "$CREDS_JSON" | jq -r '.roleCredentials.secretAccessKey')
AWS_SESSION_TOKEN=$(echo "$CREDS_JSON" | jq -r '.roleCredentials.sessionToken')


# ------------------------------
# 8. Write credentials
# ------------------------------
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"     --profile "$TARGET_PROFILE"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile "$TARGET_PROFILE"
aws configure set aws_session_token "$AWS_SESSION_TOKEN"     --profile "$TARGET_PROFILE"

echo ""
echo "🎉 SUCCESS — Updated credentials for [$TARGET_PROFILE]"
