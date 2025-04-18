  ARCH LINUX BACKUP SYSTEM — README
===============================================================================

This backup system captures a full snapshot of your Arch Linux environment,
including package lists, dotfiles, configuration files, system settings,
crontabs, secrets, and personal tools.

The backup is generated into a dated zip archive named:  arch-backup-YYYY-MM-DD.zip

Inside the archive, you’ll find organized directories:
  - `pkglist/`       → pacman and AUR package lists
  - `dotfiles/`      → chezmoi-managed dotfiles
  - `local/`         → ~/.local/bin and ~/.local/share
  - `configs/`       → core system config files (fstab, pacman.conf, etc.)
  - `services/`      → systemd unit files (user + system)
  - `crontabs/`      → root and user crontabs
  - `network/`       → NetworkManager system-connections
  - `secrets/`       → .ssh and .gnupg folders (optional)
  - `system/`        → bootloader, grub, snapper info
  - `tools/`         → development environment data (cargo, npm, etc.)
  - `extras/`        → wallpapers, fonts, themes

-------------------------------------------------------------------------------
CONFIGURATION OPTIONS (set at top of backup script):
-------------------------------------------------------------------------------
  - `DATE`                  → Automatically set as current date (YYYY-MM-DD)
  - `BACKUP_DIR`            → Where backup contents are staged before zipping
  - `CHEZMOI_REPO`          → Location of chezmoi dotfiles repo
  - `ENCRYPT_ZIP`           → true = create encrypted zip (will prompt for password)
  - `INCLUDE_ETC`           → true = include /etc (non-sensitive files)
  - `INCLUDE_SENSITIVE_ETC` → true = include /etc files like shadow, ssl keys, etc.
  - `EXCLUDE_SECRETS`       → true = do NOT back up ~/.ssh and ~/.gnupg

  **SSH TOGGLES:**
  - `SEND_SSH`              → true = scp archive to remote server after backup
  - `SSH_USER`              → remote username
  - `SSH_HOST`              → remote host (e.g., pi400)
  - `SSH_DEST_PATH`         → remote path to store the archive (e.g., /mnt/backups)


  HOW TO RESTORE THIS SYSTEM FROM BACKUP
===============================================================================

1. **SET UP BASE ARCH INSTALL (with internet access and user account)**
   - Partition & format disks
   - Mount root & boot
   - pacman -S base base-devel linux linux-firmware networkmanager git
   - arch-chroot into the new system
   - Enable networking: `systemctl enable NetworkManager`
   
2. **TRANSFER BACKUP ZIP**
   
   Move or extract the backup zip to the new home directory (e.g., via USB):
     ```
       scp arch-backup-YYYY-MM-DD.zip user@newhost:~
     ```
   Unzip it:
     ```
       unzip arch-backup-YYYY-MM-DD.zip
     ```
     
4. **INSTALL ESSENTIAL TOOLS**
   ```
   sudo pacman -S chezmoi rsync unzip git zsh vim
   ```
5. **RESTORE PACKAGE LISTS**

   ```
   cd arch-backup-YYYY-MM-DD/pkglist
   ```
   Install official packages
   ```
   sudo pacman -S --needed - < pacman-packages.txt
   ```
   Install AUR packages with yay or something else
   ```
   yay -S --needed - < aur-packages.txt   # if using yay
   ```

7. **RESTORE ETC CONFIGS**
   ```
   sudo cp -r ../etc/* /etc/
   ```

9. **RESTORE DOTFILES (chezmoi)**
   ```
   chezmoi init --source=~/arch-backup-YYYY-MM-DD/dotfiles
   chezmoi apply
   ```

10. **RESTORE USER .local DATA**
    ```
    cp -r ../local/* ~/.local/
    ```
    
11. **RESTORE CORE CONFIG FILES**
    ```
    sudo cp -r ../configs/* /
    ```

11. **RESTORE SYSTEMD SERVICES**

    ```
    cp -r ../services/home/* ~/
    sudo cp -r ../services/etc/* /etc/
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    ```
    
11. **RESTORE CRONTABS**

    ```
    crontab ../crontabs/user-crontab.txt
    sudo crontab ../crontabs/root-crontab.txt
    ```

11. **RESTORE NETWORK SETTINGS**

    ```
    sudo cp -r ../network/system-connections /etc/NetworkManager/
    ```

13. **RESTORE SECRETS (SSH & GPG)**

    ```
    cp -r ../secrets/.ssh ~/
    cp -r ../secrets/.gnupg ~/
    ```

13. **RESTORE SYSTEM BOOT INFO**

    ```
    sudo cp -r ../system/loader /boot/
    sudo cp -r ../system/grub /boot/
    sudo cp -r ../system/snapper /etc/
    lsblk -f     # to verify restored layout
    ```

15. **RESTORE DEVELOPER TOOLS**

    ```
    cp -r ../tools/* ~/
    ```

15. **RESTORE EXTRAS (Wallpapers, Fonts, Themes)**

    ```
    cp -r ../extras/* ~/
    ```

16. **FINAL CHECKS**
   - Re-enable services: `systemctl enable --now <service>`
   - Reboot and verify everything is working
   - Clean up temporary files if needed
