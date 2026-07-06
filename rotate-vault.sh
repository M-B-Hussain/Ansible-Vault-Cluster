#!/bin/bash

# Exit immediately if any command fails
set -e

VAULT_FILE="vars.yml"
OLD_PASS_FILE=".vault_pass"
NEW_PASS_FILE=".vault_pass_new"

# Step 1: Safety checks
if [ ! -f "$OLD_PASS_FILE" ]; then
    echo "Error: Old password file '$OLD_PASS_FILE' not found!"
    exit 1
fi

if [ ! -f "$VAULT_FILE" ]; then
    echo "Error: Target vault file '$VAULT_FILE' not found!"
    exit 1
fi

echo "Generating a new secure, random password..."
# Step 2: Generate a secure 32-character random string (stripping newlines)
openssl rand -base64 32 | tr -d '\n' > "$NEW_PASS_FILE"
chmod 600 "$NEW_PASS_FILE"

echo "Rekeying $VAULT_FILE seamlessly..."
# Step 3: Rekey using the old and new pass files to bypass terminal prompts
ansible-vault rekey \
    --vault-password-file="$OLD_PASS_FILE" \
    --new-vault-password-file="$NEW_PASS_FILE" \
    "$VAULT_FILE"

echo "Finalizing password rotation and file cleanup..."
# Step 4: Overwrite the old password file with the new one atomically
mv "$NEW_PASS_FILE" "$OLD_PASS_FILE"
chmod 600 "$OLD_PASS_FILE"

echo "Success! Vault password rotated and '$VAULT_FILE' re-encrypted."