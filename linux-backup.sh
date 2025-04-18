#!/bin/bash

# === CONFIGURATION ===
DATE=$(date +%Y-%m-%d)
BACKUP_DIR=~/arch-backup-$DATE
CHEZMOI_REPO=~/.local/share/chezmoi
ENCRYPT_ZIP=false         # Set to true for zip encryption (prompted)
INCLUDE_ETC=true
INCLUDE_SENSITIVE_ETC=false
EXCLUDE_SECRETS=false     # Set to true to skip .ssh and .gnupg backups

# SSH TOGGLES
SEND_SSH=true
SSH_USER=SSH_USER
SSH_HOST=SSH_HOSTNAME
SSH_DEST_PATH=DIR_PATH

echo "[+] Starting full system backup for $DATE..."
mkdir -p "$BACKUP_DIR"/{pkglist,dotfiles,local,configs,services,crontabs,network,secrets,system,tools,extras,etc}

# === 1. PACKAGE LISTS ===
echo "[+] Saving installed packages..."
pacman -Qqe > "$BACKUP_DIR/pkglist/pacman-packages.txt" 2>/dev/null
pacman -Qqm > "$BACKUP_DIR/pkglist/aur-packages.txt" 2>/dev/null

# === 2. ETC ===
if [ "$INCLUDE_ETC" = true ]; then
  echo "[+] Backing up /etc configs..."

  ETC_EXCLUDES=(
    "--exclude=passwd-"
    "--exclude=group-"
  )

  if [ "$INCLUDE_SENSITIVE_ETC" = false ]; then
    echo "[*] Skipping sensitive files from /etc..."
    ETC_EXCLUDES+=(
      "--exclude=shadow"
      "--exclude=gshadow"
      "--exclude=ssl"
      "--exclude=*.key"
      "--exclude=*.pem"
    )
  else
    echo "[!] Including sensitive files from /etc — be cautious!"
  fi

  sudo rsync -a "${ETC_EXCLUDES[@]}" /etc "$BACKUP_DIR/etc"
fi

# === 3. DOTFILES WITH CHEZMOI ===
if command -v chezmoi &>/dev/null && [ -d "$CHEZMOI_REPO" ]; then
    echo "[+] Exporting dotfiles with chezmoi..."
    chezmoi apply
    git -C "$CHEZMOI_REPO" add .
    git -C "$CHEZMOI_REPO" commit -m "Update dotfiles on $DATE"
    git -C "$CHEZMOI_REPO" push
    rsync -a --exclude='.git' "$CHEZMOI_REPO" "$BACKUP_DIR/dotfiles"
else
    echo "[!] Skipping chezmoi: not found or repo missing"
fi

# === 4. .local BIN & SHARE ===
echo "[+] Backing up .local..."
[ -d ~/.local/bin ] && rsync -a ~/.local/bin "$BACKUP_DIR/local/" 2>/dev/null
[ -d ~/.local/share ] && rsync -a ~/.local/share "$BACKUP_DIR/local/" \
    --exclude="Trash" --exclude="recently-used.xbel" 2>/dev/null

# === 5. CONFIG FILES ===
echo "[+] Backing up system configs..."
for file in /etc/pacman.conf /etc/mkinitcpio.conf /etc/fstab; do
    [ -f "$file" ] && cp --parents "$file" "$BACKUP_DIR/configs"
done
[ -f /etc/pacman.d/mirrorlist ] && cp --parents /etc/pacman.d/mirrorlist "$BACKUP_DIR/configs"

# === 6. SYSTEMD UNITS ===
echo "[+] Backing up systemd units..."
[ -d ~/.config/systemd/user ] && cp -r --parents ~/.config/systemd/user "$BACKUP_DIR/services"
[ -d /etc/systemd/system ] && sudo cp -r --parents /etc/systemd/system "$BACKUP_DIR/services" 2>/dev/null

# === 7. CRONTABS ===
echo "[+] Backing up crontabs..."
crontab -l > "$BACKUP_DIR/crontabs/user-crontab.txt" 2>/dev/null
sudo crontab -l -u root > "$BACKUP_DIR/crontabs/root-crontab.txt" 2>/dev/null

# === 8. NETWORK SETTINGS ===
echo "[+] Backing up network settings..."
[ -d /etc/NetworkManager/system-connections ] && sudo cp -r /etc/NetworkManager/system-connections "$BACKUP_DIR/network" 2>/dev/null

# === 9. SECRETS: SSH & GPG ===
if [ "$EXCLUDE_SECRETS" = false ]; then
    echo "[+] Backing up secrets..."
    [ -d ~/.ssh ] && cp -r ~/.ssh "$BACKUP_DIR/secrets"
    [ -d ~/.gnupg ] && cp -r ~/.gnupg "$BACKUP_DIR/secrets"
else
    echo "[*] Skipping secrets backup."
fi

# === 10. SYSTEM BOOT INFO ===
echo "[+] Backing up system boot info..."
lsblk -f > "$BACKUP_DIR/system/lsblk.txt" 2>/dev/null
[ -d /boot/loader ] && sudo cp -r /boot/loader "$BACKUP_DIR/system/" 2>/dev/null
[ -d /boot/grub ] && sudo cp -r /boot/grub "$BACKUP_DIR/system/" 2>/dev/null
[ -d /etc/snapper ] && sudo cp -r /etc/snapper "$BACKUP_DIR/system/snapper" 2>/dev/null

# === 11. DEVELOPER TOOLS ===
echo "[+] Backing up dev tools..."
[ -d ~/.npm ] && cp -r ~/.npm "$BACKUP_DIR/tools/" 2>/dev/null
[ -d ~/.cargo ] && cp -r ~/.cargo "$BACKUP_DIR/tools/" 2>/dev/null
[ -d ~/.var ] && cp -r ~/.var "$BACKUP_DIR/tools/" 2>/dev/null

# === 12. EXTRAS ===
echo "[+] Backing up extras..."
[ -d ~/Pictures/Wallpapers ] && cp -r ~/Pictures/Wallpapers "$BACKUP_DIR/extras/"
[ -d ~/.fonts ] && cp -r ~/.fonts "$BACKUP_DIR/extras/"
[ -d ~/.themes ] && cp -r ~/.themes "$BACKUP_DIR/extras/"
[ -d ~/.local/share/fonts ] && cp -r ~/.local/share/fonts "$BACKUP_DIR/extras/"

# === 13. ZIP & CLEANUP ===
echo "[+] Creating zip archive..."
ZIP_NAME="$BACKUP_DIR.zip"  # Ensure this is defined

# Check if sudo is needed to read some files
if [ ! -r "$BACKUP_DIR" ]; then
    echo "[!] Some files require sudo to read. Retrying zip with sudo..."
    sudo zip -r "$ZIP_NAME" "$BACKUP_DIR"
else
    zip -r "$ZIP_NAME" "$BACKUP_DIR"
fi

# Check if BACKUP_DIR was set and has contents
if [ ! -d "$BACKUP_DIR" ]; then
    echo "[!] Backup directory doesn't exist. Aborting backup."
    exit 1
fi

if [ "$ENCRYPT_ZIP" = true ]; then
    zip -er "$ZIP_NAME" "$BACKUP_DIR" && rm -rf "$BACKUP_DIR"
else
    zip -r "$ZIP_NAME" "$BACKUP_DIR" && rm -rf "$BACKUP_DIR"
fi

# Double-check ZIP_NAME is set correctly
if [ ! -f "$ZIP_NAME" ]; then
    echo "[!] Failed to create zip: $ZIP_NAME"
    exit 1
fi

echo "[✓] Backup archive created: $ZIP_NAME"

# === 14. SSH UPLOAD ===
if [ "$SEND_SSH" = true ]; then
    if [ -f "$ZIP_NAME" ]; then
        echo "[+] Sending backup over SSH to $SSH_USER@$SSH_HOST..."
        scp "$ZIP_NAME" "$SSH_USER@$SSH_HOST:$SSH_DEST_PATH/"
        if [ $? -eq 0 ]; then
            echo "[✓] Backup successfully transferred to $SSH_HOST"
        else
            echo "[!] SSH transfer failed. Check SSH access and remote path."
        fi
    else
        echo "[!] Backup zip does not exist: $ZIP_NAME"
    fi
else
    echo "[*] Skipping SSH transfer."
fi
