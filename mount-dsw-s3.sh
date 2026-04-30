#!/bin/bash
# Mount s3://dsw-sagemaker-dev-s3 via rclone using AWS profile credentials
# Usage: mount-dsw-s3.sh [--unmount]

PROFILE="314146307595_DSWDevelopment-DataScientists"
BUCKET="dsw-sagemaker-dev-s3"
REMOTE="dsw-s3"
MOUNT_POINT="$HOME/dsw-sagemaker-dev-s3"
AWS_CREDENTIALS_FILE="$HOME/.aws/credentials"
RCLONE_CONF="$HOME/.config/rclone/rclone.conf"

# --- Unmount mode ---
if [ "$1" == "--unmount" ]; then
    rclone umount "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null
    echo "Unmounted $MOUNT_POINT"
    exit 0
fi

# --- Check prerequisites ---
if ! command -v rclone &>/dev/null; then
    echo "Error: rclone is not installed."
    exit 1
fi

if [ ! -f "$AWS_CREDENTIALS_FILE" ]; then
    echo "Error: AWS credentials file not found at $AWS_CREDENTIALS_FILE"
    exit 1
fi

# --- Read credentials from profile ---
AWS_ACCESS_KEY_ID=$(sed -n "/\[$PROFILE\]/,/\[/p" "$AWS_CREDENTIALS_FILE" | grep 'aws_access_key_id' | cut -d'=' -f2-)
AWS_SECRET_ACCESS_KEY=$(sed -n "/\[$PROFILE\]/,/\[/p" "$AWS_CREDENTIALS_FILE" | grep 'aws_secret_access_key' | cut -d'=' -f2-)
AWS_SESSION_TOKEN=$(sed -n "/\[$PROFILE\]/,/\[/p" "$AWS_CREDENTIALS_FILE" | grep 'aws_session_token' | cut -d'=' -f2-)

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "Error: Could not find profile '$PROFILE' in $AWS_CREDENTIALS_FILE"
    exit 1
fi

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

# --- Write rclone config (env_auth mode for safe token handling) ---
mkdir -p "$(dirname "$RCLONE_CONF")"
cat > "$RCLONE_CONF" << EOF
[$REMOTE]
type = s3
provider = AWS
env_auth = true
region = us-east-1
acl = private
EOF

# --- Unmount if already mounted ---
if mount | grep -q "$MOUNT_POINT"; then
    echo "Already mounted at $MOUNT_POINT. Unmounting first..."
    rclone umount "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT" 2>/dev/null
fi

# --- Verify credentials work ---
echo "Verifying credentials..."
if ! rclone ls "${REMOTE}:${BUCKET}" --max-depth 1 &>/dev/null; then
    echo "Error: Credentials failed. Check your AWS session token is still valid."
    exit 1
fi

# --- Create mount point and mount ---
mkdir -p "$MOUNT_POINT"

echo "Mounting s3://${BUCKET} -> ${MOUNT_POINT}"
nohup rclone mount "${REMOTE}:${BUCKET}" "$MOUNT_POINT" \
    --vfs-cache-mode full \
    --vfs-cache-max-age 1h0m0s \
    --vfs-read-chunk-size 128M \
    --buffer-size 128M \
    --daemon \
    2>&1

sleep 3

# --- Verify mount ---
if ls "$MOUNT_POINT" &>/dev/null; then
    echo "✅ Mounted successfully at $MOUNT_POINT"
else
    echo "❌ Mount failed. Check rclone logs."
    exit 1
fi
