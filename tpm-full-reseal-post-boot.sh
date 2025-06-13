#!/bin/bash
#
# TPM Auto-Reseal Script - Stage 2 (Post-Reboot)
# This script is executed by a systemd service on the first boot after a kernel update.
# It restores the TPM policy to the maximum security level.
#

echo "TPM Service: Post-reboot reseal process started."

# --- Configuration ---
LUKS_DEVICE="/dev/nvme0n1p4"
KEY_FILE="/root/.luks_unlock_key"
TRIGGER_FILE="/root/.tpm_reseal_needed"
CLEVIS_SLOT=`clevis luks list -d $LUKS_DEVICE | grep '"pcr_ids":"7' | cut -d : -f 1`

# --- Main Logic ---

# 1. Unbind the temporary PCR 7 token.
echo "Unbinding temporary PCR 7 token from slot ${CLEVIS_SLOT}..."
if ! clevis luks unbind -d "$LUKS_DEVICE" -s "$CLEVIS_SLOT" -f; then
    echo "ERROR: Failed to unbind the temporary token. Aborting." >&2
    exit 1
fi

# 2. Bind the final, high-security token using PCRs 7, 8, and 9.
#    This uses the new, correct PCR values from the current boot.
echo "Binding final, high-security token using PCRs 7, 8, and 9..."
if ! clevis luks bind -k "$KEY_FILE" -d "$LUKS_DEVICE" tpm2 '{"pcr_bank":"sha256", "pcr_ids":"7,8,9"}'; then
    echo "ERROR: Failed to bind the final high-security token. Manual intervention required." >&2
    exit 1
fi

# 3. Clean up by removing the trigger file. This is critical to prevent
#    this service from running again on the next boot.
echo "Cleaning up trigger file..."
rm -f "$TRIGGER_FILE"

echo "TPM Service: System restored to maximum security. Process complete."

exit 0
