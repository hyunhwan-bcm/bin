#!/bin/bash
# Wrapper that fetches SSO credentials for Bedrock, auto-triggers login if expired.

PROFILE="${1:-default}"

# Try to get credentials
CREDS=$(aws sso get-role-credentials \
  --profile "$PROFILE" \
  --output json 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "AWS SSO session expired — logging in..." >&2
    aws sso login --profile "$PROFILE" >&2
    CREDS=$(aws sso get-role-credentials \
      --profile "$PROFILE" \
      --output json 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "ERROR: SSO login failed" >&2
        exit 1
    fi
fi

# Output in credential_process format
python3 -c "
import json, sys
from datetime import datetime, timezone
creds = json.loads(sys.stdin.read())['roleCredentials']
print(json.dumps({
    'Version': 1,
    'AccessKeyId': creds['accessKeyId'],
    'SecretAccessKey': creds['secretAccessKey'],
    'SessionToken': creds['sessionToken'],
    'Expiration': datetime.fromtimestamp(creds['expiration']/1000, tz=timezone.utc).isoformat()
}))
" <<< "$CREDS"
