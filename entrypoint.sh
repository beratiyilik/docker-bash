#!/bin/sh

BASHRC_PATH="/root/.bashrc"
CUSTOM_BASHRC="/tmp/.bashrc_custom"
BACKUP_PATH="/root/.bashrc.bak"

# if the original .bashrc exists, back it up
if [ -f "$BASHRC_PATH" ]; then
    echo "Backing up: $BASHRC_PATH -> $BACKUP_PATH"
    cp "$BASHRC_PATH" "$BACKUP_PATH"
    echo "Backup completed."
fi

# copy the custom .bashrc into place
cp "$CUSTOM_BASHRC" "$BASHRC_PATH"
echo "Custom .bashrc has been successfully copied."

# change to home directory
cd ~

# start an interactive Bash shell
exec bash
