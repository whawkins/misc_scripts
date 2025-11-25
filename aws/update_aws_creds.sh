#!/bin/bash
set -euo pipefail

TARGET_PROFILE="$1"

if [ -z "$TARGET_PROFILE" ]; then
  echo "Usage: $0 <profile>"
  exit 1
fi

# ------------------------------
# SSO login profile = target profile
# ------------------------------
SSO_PROFILE="$TARGET_PROFILE"

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
# 4. Map CLI profile → SSO accountName
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
# 6. Find roleName for this SSO account
# ------------------------------
ROLE_NAME=$(aws sso list-account-roles \
    --access-token "$ACCESS_TOKEN" \
    --account-id "$ACCOUNT_ID" \
    --query "roleList[?contains(roleName, 'gsmd')][0].roleName" \
    --output text)

if [ -z "$ROLE_NAME" ]; then
  ROLE_NAME=$(aws sso list-account-roles \
      --access-token "$ACCESS_TOKEN" \
      --account-id "$ACCOUNT_ID" \
      --query "roleList[0].roleName" \
      --output text)
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

#echo $AWS_ACCESS_KEY_ID
#echo $AWS_SECRET_ACCESS_KEY
#echo $AWS_SESSION_TOKEN

# ------------------------------
# 8. Write credentials
# ------------------------------
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"     --profile "$TARGET_PROFILE"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile "$TARGET_PROFILE"
aws configure set aws_session_token "$AWS_SESSION_TOKEN"     --profile "$TARGET_PROFILE"

echo ""
echo "🎉 SUCCESS — Updated credentials for profile [$TARGET_PROFILE]"

