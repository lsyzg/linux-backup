#!/bin/bash

# ================================================================================
#  HOW TO RESTORE THIS SYSTEM FROM BACKUP
# ================================================================================

# 1. SET UP BASE ARCH INSTALL (with internet access and user account)
#    - Partition & format disks
#    - Mount root & boot
#    - pacstrap base base-devel linux linux-firmware networkmanager git
#    - arch-chroot into the new system
#    - Enable networking: `systemctl enable NetworkManager`

# 2. ⬇️ TRANSFER BACKUP ZIP
#    - Move or extract the backup zip to the new home directory (e.g., via USB):
#        scp arch-backup-YYYY-MM-DD.zip user@newhost:~
#    - Unzip it:
#        unzip arch-backup-YYYY-MM-DD.zip

# 3. INSTALL ESSENTIAL TOOLS
#    sudo pacman -S chezmoi rsync unzip git zsh vim

# 4. RESTORE PACKAGE LISTS
#    cd arch-backup-YYYY-MM-DD/pkglist
#    sudo pacman -S --needed - < pacman-packages.txt
#    yay -S --needed - < aur-packages.txt   # if using yay

# 5. RESTORE CONFIGS AND SYSTEM FILES
#    sudo cp -r ../configs/* /
#    sudo cp -r ../services/* /
#    sudo cp -r ../system/* /
#    sudo cp -r ../network/* /etc/NetworkManager/system-connections/
#    sudo systemctl daemon-reexec
#    sudo systemctl daemon-reload

# 6. RESTORE USER DATA
#    cp -r ../local/* ~/.local/
#    cp -r ../tools/* ~/
#    cp -r ../extras/* ~/

# 7. RESTORE SSH/GPG (IF INCLUDED)
#    cp -r ../secrets/.ssh ~/
#    cp -r ../secrets/.gnupg ~/

# 8. RESTORE DOTFILES (chezmoi)
#    chezmoi init --source=~/arch-backup-YYYY-MM-DD/dotfiles
#    chezmoi apply

# 9. RESTORE CRONTABS
#    crontab ../crontabs/user-crontab.txt
#    sudo crontab ../crontabs/root-crontab.txt

# 10. FINAL CHECKS
#    - Re-enable services you use: `systemctl enable --now <service>`
#    - Reboot and verify

# ================================================================================

# === CONFIGURATION ===
DATE=$(date +%Y-%m-%d)
BACKUP_DIR=~/arch-backup-$DATE
CHEZMOI_REPO=~/.local/share/chezmoi
ENCRYPT_ZIP=false         # Set to true for zip encryption (prompted)
EXCLUDE_SECRETS=false     # Set to true to skip .ssh and .gnupg backups

# SSH TOGGLES
SEND_SSH=true
SSH_USER=backupuser
SSH_HOST=backup.example.com
SSH_DEST_PATH=~/backups/arch

echo "[+] Starting full system backup for $DATE..."
mkdir -p "$BACKUP_DIR"/{pkglist,dotfiles,local,configs,services,crontabs,network,secrets,system,tools,extras}

# === 1. PACKAGE LISTS ===
echo "[+] Saving installed packages..."
pacman -Qqe > "$BACKUP_DIR/pkglist/pacman-packages.txt" 2>/dev/null
pacman -Qqm > "$BACKUP_DIR/pkglist/aur-packages.txt" 2>/dev/null

# === 2. DOTFILES WITH CHEZMOI ===
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

# === 3. .local BIN & SHARE ===
echo "[+] Backing up .local..."
[ -d ~/.local/bin ] && rsync -a ~/.local/bin "$BACKUP_DIR/local/" 2>/dev/null
[ -d ~/.local/share ] && rsync -a ~/.local/share "$BACKUP_DIR/local/" \
    --exclude="Trash" --exclude="recently-used.xbel" 2>/dev/null

# === 4. CONFIG FILES ===
echo "[+] Backing up system configs..."
for file in /etc/pacman.conf /etc/mkinitcpio.conf /etc/fstab; do
    [ -f "$file" ] && cp --parents "$file" "$BACKUP_DIR/configs"
done
[ -f /etc/pacman.d/mirrorlist ] && cp --parents /etc/pacman.d/mirrorlist "$BACKUP_DIR/configs"

# === 5. SYSTEMD UNITS ===
echo "[+] Backing up systemd units..."
[ -d ~/.config/systemd/user ] && cp -r --parents ~/.config/systemd/user "$BACKUP_DIR/services"
[ -d /etc/systemd/system ] && sudo cp -r --parents /etc/systemd/system "$BACKUP_DIR/services" 2>/dev/null

# === 6. CRONTABS ===
echo "[+] Backing up crontabs..."
crontab -l > "$BACKUP_DIR/crontabs/user-crontab.txt" 2>/dev/null
sudo crontab -l -u root > "$BACKUP_DIR/crontabs/root-crontab.txt" 2>/dev/null

# === 7. NETWORK SETTINGS ===
echo "[+] Backing up network settings..."
[ -d /etc/NetworkManager/system-connections ] && sudo cp -r /etc/NetworkManager/system-connections "$BACKUP_DIR/network" 2>/dev/null

# === 8. SECRETS: SSH & GPG ===
if [ "$EXCLUDE_SECRETS" = false ]; then
    echo "[+] Backing up secrets..."
    [ -d ~/.ssh ] && cp -r ~/.ssh "$BACKUP_DIR/secrets"
    [ -d ~/.gnupg ] && cp -r ~/.gnupg "$BACKUP_DIR/secrets"
else
    echo "[*] Skipping secrets backup."
fi

# === 9. SYSTEM BOOT INFO ===
echo "[+] Backing up system boot info..."
lsblk -f > "$BACKUP_DIR/system/lsblk.txt" 2>/dev/null
[ -d /boot/loader ] && sudo cp -r /boot/loader "$BACKUP_DIR/system/" 2>/dev/null
[ -d /boot/grub ] && sudo cp -r /boot/grub "$BACKUP_DIR/system/" 2>/dev/null
[ -d /etc/snapper ] && sudo cp -r /etc/snapper "$BACKUP_DIR/system/snapper" 2>/dev/null

# === 10. DEVELOPER TOOLS ===
echo "[+] Backing up dev tools..."
[ -d ~/.npm ] && cp -r ~/.npm "$BACKUP_DIR/tools/" 2>/dev/null
[ -d ~/.cargo ] && cp -r ~/.cargo "$BACKUP_DIR/tools/" 2>/dev/null
[ -d ~/.var ] && cp -r ~/.var "$BACKUP_DIR/tools/" 2>/dev/null

# === 11. EXTRAS ===
echo "[+] Backing up extras..."
[ -d ~/Pictures/Wallpapers ] && cp -r ~/Pictures/Wallpapers "$BACKUP_DIR/extras/"
[ -d ~/.fonts ] && cp -r ~/.fonts "$BACKUP_DIR/extras/"
[ -d ~/.themes ] && cp -r ~/.themes "$BACKUP_DIR/extras/"
[ -d ~/.local/share/fonts ] && cp -r ~/.local/share/fonts "$BACKUP_DIR/extras/"

# === 12. ZIP & CLEANUP ===
echo "[+] Creating zip archive..."
if [ "$ENCRYPT_ZIP" = true ]; then
    zip -er "$BACKUP_DIR.zip" "$BACKUP_DIR" && rm -rf "$BACKUP_DIR"
else
    zip -r "$BACKUP_DIR.zip" "$BACKUP_DIR" && rm -rf "$BACKUP_DIR"
fi

echo "[✓] Full backup complete: $BACKUP_DIR.zip"

# === 13. SSH UPLOAD ===
if [ "$SEND_SSH" = true ]; then
    echo "[+] Sending backup over SSH to $SSH_USER@$SSH_HOST..."
    scp "$ZIP_NAME" "$SSH_USER@$SSH_HOST:$SSH_DEST_PATH/"
    if [ $? -eq 0 ]; then
        echo "[✓] Backup successfully transferred to $SSH_HOST"
    else
        echo "[!] SSH transfer failed. Check your SSH keys or credentials."
    fi
else
    echo "[*] Skipping SSH transfer."
fi
