#! /bin/sh

## time and date config
timedatectl set-ntp true
timedatectl set-timezone Asia/Dhaka
timedatectl status

## disk partition config
echo "=== Available Block Devices ==="
lsblk -f
echo ""

# Storage configuration variables
TARGET_DEVICE=""
DISK_CONFIG=""
AVAILABLE_PARTITIONS=""
EFI_PARTITION=""
BOOT_PARTITION=""
ROOT_PARTITION=""
HOME_PARTITION=""
EXISTING_HOME=""
HOME_MOUNT_OPTS=""

# Helper function to check if partition is already assigned
is_partition_used() {
    local part="$1"
    [ "$part" = "$EFI_PARTITION" ] || \
    [ "$part" = "$BOOT_PARTITION" ] || \
    [ "$part" = "$ROOT_PARTITION" ] || \
    [ "$part" = "$HOME_PARTITION" ] || \
    [ "$part" = "$EXISTING_HOME" ]
}

# Print help
print_help() {
    cat << 'EOF'
Usage: <command> [...]

Available commands:
  gpt                 : Create new GPT partition table (DESTROYS ALL DATA!)
  n-efi               : Create new EFI partition
  n-linuxfs           : Create new Linux filesystem partition
  set-efi             : Set partition for /boot/efi (will format as FAT32)
  set-boot            : Set partition for /boot (will format as ext4)
  set-root            : Set partition for / (will format as btrfs)
  set-home            : Set partition for /home (will format as btrfs)
  set-existing-home   : Mount existing partition as /home (won't format)
  list-part           : List available partitions
  show-config         : Show current configuration
  reset               : Reset all configuration (start over)
  preset-pc           : Apply preset for personal PC (/dev/nvme0n1)
  write               : Execute the configuration
  help                : Show this message
EOF
}

# Create GPT partition table
cmd_gpt() {
    if [ -n "$DISK_CONFIG" ]; then
        echo "Error: GPT partition table already initialized!"
        echo "Use 'reset' command to start over."
        return
    fi

    echo "WARNING: This will DESTROY ALL DATA on $TARGET_DEVICE!"
    read -p "Are you sure? Type 'YES' to confirm: " confirm
    if [ "$confirm" != "YES" ]; then
        echo "Cancelled. (You must type 'YES' exactly to confirm)"
        return
    fi

    echo "Creating GPT partition table on $TARGET_DEVICE..."
    DISK_CONFIG="sgdisk -Z $TARGET_DEVICE; partprobe $TARGET_DEVICE"
    AVAILABLE_PARTITIONS=""
    echo "GPT partition table will be created on write."
    echo "You can now create partitions with n-efi and n-linuxfs."
}

# Create new EFI partition
cmd_n_efi() {
    if [ -z "$DISK_CONFIG" ]; then
        echo "Error: Run 'gpt' command first to initialize partition table!"
        return
    fi

    read -p "Partition size (e.g., +512M, +1G): " size
    if [ -z "$size" ]; then
        echo "Size cannot be empty!"
        return
    fi

    # Calculate next partition number
    PART_COUNT=$(echo "$AVAILABLE_PARTITIONS" | grep -c "^" | tr -d ' ')
    PART_NUM=$((PART_COUNT + 1))

    # Add to disk config
    DISK_CONFIG="$DISK_CONFIG
sgdisk -n 0:0:$size -t 0:ef00 $TARGET_DEVICE"

    # Add to available partitions
    if echo "$TARGET_DEVICE" | grep -q "nvme\|mmcblk"; then
        NEW_PART="${TARGET_DEVICE}p${PART_NUM}"
    else
        NEW_PART="${TARGET_DEVICE}${PART_NUM}"
    fi

    if [ -z "$AVAILABLE_PARTITIONS" ]; then
        AVAILABLE_PARTITIONS="$NEW_PART"
    else
        AVAILABLE_PARTITIONS="$AVAILABLE_PARTITIONS
$NEW_PART"
    fi

    echo "EFI partition will be created: $NEW_PART"
}

# Create new Linux filesystem partition
cmd_n_linuxfs() {
    if [ -z "$DISK_CONFIG" ]; then
        echo "Error: Run 'gpt' command first to initialize partition table!"
        return
    fi

    read -p "Partition size (e.g., +10G, +0 for rest of disk): " size
    if [ -z "$size" ]; then
        echo "Size cannot be empty!"
        return
    fi

    # Calculate next partition number
    PART_COUNT=$(echo "$AVAILABLE_PARTITIONS" | grep -c "^" | tr -d ' ')
    PART_NUM=$((PART_COUNT + 1))

    # Add to disk config
    DISK_CONFIG="$DISK_CONFIG
sgdisk -n 0:0:$size -t 0:8300 $TARGET_DEVICE"

    # Add to available partitions
    if echo "$TARGET_DEVICE" | grep -q "nvme\|mmcblk"; then
        NEW_PART="${TARGET_DEVICE}p${PART_NUM}"
    else
        NEW_PART="${TARGET_DEVICE}${PART_NUM}"
    fi

    if [ -z "$AVAILABLE_PARTITIONS" ]; then
        AVAILABLE_PARTITIONS="$NEW_PART"
    else
        AVAILABLE_PARTITIONS="$AVAILABLE_PARTITIONS
$NEW_PART"
    fi

    echo "Linux filesystem partition will be created: $NEW_PART"
}

# Set EFI partition
cmd_set_efi() {
    read -p "EFI partition path (e.g., /dev/nvme0n1p1): " part

    # Check if using disk-config mode
    if [ -n "$DISK_CONFIG" ]; then
        if ! echo "$AVAILABLE_PARTITIONS" | grep -q "^${part}$"; then
            echo "Error: $part is not in the available partitions list!"
            echo "Available partitions:"
            echo "$AVAILABLE_PARTITIONS"
            return
        fi
    else
        if [ ! -b "$part" ]; then
            echo "Error: $part is not a valid block device!"
            return
        fi
    fi

    if is_partition_used "$part"; then
        echo "Error: This partition is already assigned!"
        return
    fi
    EFI_PARTITION="$part"
    echo "EFI partition set to: $EFI_PARTITION"
}

# Set boot partition
cmd_set_boot() {
    read -p "Boot partition path (e.g., /dev/nvme0n1p2): " part

    # Check if using disk-config mode
    if [ -n "$DISK_CONFIG" ]; then
        if ! echo "$AVAILABLE_PARTITIONS" | grep -q "^${part}$"; then
            echo "Error: $part is not in the available partitions list!"
            echo "Available partitions:"
            echo "$AVAILABLE_PARTITIONS"
            return
        fi
    else
        if [ ! -b "$part" ]; then
            echo "Error: $part is not a valid block device!"
            return
        fi
    fi

    if is_partition_used "$part"; then
        echo "Error: This partition is already assigned!"
        return
    fi
    BOOT_PARTITION="$part"
    echo "Boot partition set to: $BOOT_PARTITION"
}

# Set root partition
cmd_set_root() {
    read -p "Root partition path (e.g., /dev/nvme0n1p3): " part

    # Check if using disk-config mode
    if [ -n "$DISK_CONFIG" ]; then
        if ! echo "$AVAILABLE_PARTITIONS" | grep -q "^${part}$"; then
            echo "Error: $part is not in the available partitions list!"
            echo "Available partitions:"
            echo "$AVAILABLE_PARTITIONS"
            return
        fi
    else
        if [ ! -b "$part" ]; then
            echo "Error: $part is not a valid block device!"
            return
        fi
    fi

    if is_partition_used "$part"; then
        echo "Error: This partition is already assigned!"
        return
    fi
    ROOT_PARTITION="$part"
    echo "Root partition set to: $ROOT_PARTITION"
}

# Set home partition (will format)
cmd_set_home() {
    read -p "Home partition path (e.g., /dev/nvme0n1p4): " part

    # Check if using disk-config mode
    if [ -n "$DISK_CONFIG" ]; then
        if ! echo "$AVAILABLE_PARTITIONS" | grep -q "^${part}$"; then
            echo "Error: $part is not in the available partitions list!"
            echo "Available partitions:"
            echo "$AVAILABLE_PARTITIONS"
            return
        fi
    else
        if [ ! -b "$part" ]; then
            echo "Error: $part is not a valid block device!"
            return
        fi
    fi

    if is_partition_used "$part"; then
        echo "Error: This partition is already assigned!"
        return
    fi
    HOME_PARTITION="$part"
    echo "Home partition set to: $HOME_PARTITION"
}

# Set existing home partition (won't format)
cmd_set_existing_home() {
    read -p "Existing home partition path: " part

    # For existing home, always check if it's a real block device
    if [ ! -b "$part" ]; then
        echo "Error: $part is not a valid block device!"
        return
    fi

    if is_partition_used "$part"; then
        echo "Error: This partition is already assigned!"
        return
    fi
    read -p "Mount options (leave blank for defaults): " opts
    EXISTING_HOME="$part"
    HOME_MOUNT_OPTS="$opts"
    echo "Existing home partition set to: $EXISTING_HOME"
}

# List partitions
cmd_list_part() {
    if [ -n "$DISK_CONFIG" ]; then
        echo "=== Partitions that will be created ==="
        echo "$AVAILABLE_PARTITIONS"
    else
        echo "=== Current partitions on $TARGET_DEVICE ==="
        lsblk -f "$TARGET_DEVICE"
    fi
}

# Show current configuration
cmd_show_config() {
    echo "=== Current Configuration ==="
    echo "Target Device:     $TARGET_DEVICE"
    echo "Disk Config Mode:  $([ -n "$DISK_CONFIG" ] && echo "YES (will create new partitions)" || echo "NO (using existing partitions)")"
    if [ -n "$DISK_CONFIG" ]; then
        echo ""
        echo "Partition creation commands:"
        echo "$DISK_CONFIG"
        echo ""
        echo "Available partitions after creation:"
        echo "$AVAILABLE_PARTITIONS"
        echo ""
    fi
    echo "EFI Partition:     ${EFI_PARTITION:-<not set>}"
    echo "Boot Partition:    ${BOOT_PARTITION:-<not set>}"
    echo "Root Partition:    ${ROOT_PARTITION:-<not set>}"
    echo "Home Partition:    ${HOME_PARTITION:-<not set>}"
    echo "Existing Home:     ${EXISTING_HOME:-<not set>}"
    [ -n "$HOME_MOUNT_OPTS" ] && echo "Home Mount Opts:   $HOME_MOUNT_OPTS"
}

# Reset all configuration
cmd_reset() {
    echo "WARNING: This will reset ALL configuration!"
    read -p "Are you sure? [y/N] " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Cancelled."
        return
    fi

    DISK_CONFIG=""
    AVAILABLE_PARTITIONS=""
    EFI_PARTITION=""
    BOOT_PARTITION=""
    ROOT_PARTITION=""
    HOME_PARTITION=""
    EXISTING_HOME=""
    HOME_MOUNT_OPTS=""

    echo "Configuration reset. You can start over."
}

# Preset for personal PC
cmd_preset_pc() {
    if [ ! -b "/dev/nvme0n1" ]; then
        echo "Error: /dev/nvme0n1 not found!"
        return
    fi

    echo "=== Preset PC Configuration Preview ==="
    cat << 'EOF'
This will execute:
  mkfs.fat -F32 /dev/nvme0n1p1
  mkfs.ext4 /dev/nvme0n1p2
  mkfs.btrfs -f /dev/nvme0n1p3
  mount /dev/nvme0n1p3 /mnt
  btrfs su cr /mnt/@
  btrfs su cr /mnt/@pkg
  btrfs su cr /mnt/@log
  btrfs su cr /mnt/@snapshots
  umount /mnt
  mount -o noatime,compress=zstd,subvol=@ /dev/nvme0n1p3 /mnt
  mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}
  mount -o noatime,compress=zstd,subvol=@log /dev/nvme0n1p3 /mnt/var/log
  mount -o noatime,compress=zstd,subvol=@pkg /dev/nvme0n1p3 /mnt/var/cache/pacman/pkg
  mount -o noatime,compress=zstd,subvol=@snapshots /dev/nvme0n1p3 /mnt/.snapshots
  mount -o noatime,compress=zstd /dev/nvme0n1p4 /mnt/home
  mount /dev/nvme0n1p2 /mnt/boot
  mkdir -p /mnt/boot/efi
  mount /dev/nvme0n1p1 /mnt/boot/efi

EOF

    read -p "Continue? [Y/n] " confirm
    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        echo "Cancelled."
        return
    fi

    # Execute preset
    mkfs.fat -F32 /dev/nvme0n1p1
    mkfs.ext4 /dev/nvme0n1p2
    mkfs.btrfs -f /dev/nvme0n1p3
    mount /dev/nvme0n1p3 /mnt
    btrfs su cr /mnt/@
    btrfs su cr /mnt/@pkg
    btrfs su cr /mnt/@log
    btrfs su cr /mnt/@snapshots
    umount /mnt
    mount -o noatime,compress=zstd,subvol=@ /dev/nvme0n1p3 /mnt
    mkdir -p /mnt/boot /mnt/home /mnt/var/log /mnt/var/cache/pacman/pkg /mnt/.snapshots
    mount -o noatime,compress=zstd,subvol=@log /dev/nvme0n1p3 /mnt/var/log
    mount -o noatime,compress=zstd,subvol=@pkg /dev/nvme0n1p3 /mnt/var/cache/pacman/pkg
    mount -o noatime,compress=zstd,subvol=@snapshots /dev/nvme0n1p3 /mnt/.snapshots
    mount -o noatime,compress=zstd /dev/nvme0n1p4 /mnt/home
    mount /dev/nvme0n1p2 /mnt/boot
    mkdir -p /mnt/boot/efi
    mount /dev/nvme0n1p1 /mnt/boot/efi

    echo "=== Preset applied successfully! ==="
    echo "Mounted filesystems:"
    lsblk -f | grep /mnt
}

# Write configuration
cmd_write() {
    # Validation
    if [ -z "$ROOT_PARTITION" ]; then
        echo "Error: Root partition not set!"
        return
    fi
    if [ -z "$EFI_PARTITION" ]; then
        echo "Error: EFI partition not set!"
        return
    fi
    if [ -z "$BOOT_PARTITION" ]; then
        echo "Error: Boot partition not set!"
        return
    fi
    if [ -z "$HOME_PARTITION" ] && [ -z "$EXISTING_HOME" ]; then
        echo "Error: Home partition not set!"
        return
    fi

    # Preview commands
    echo "=== Configuration Preview ==="
    echo "This will execute the following commands:"
    echo ""

    # Show disk config if exists
    if [ -n "$DISK_CONFIG" ]; then
        echo "# Create GPT and partitions"
        echo "$DISK_CONFIG"
        echo "partprobe $TARGET_DEVICE"
        echo ""
    fi

    echo "# Format EFI partition"
    echo "mkfs.fat -F32 $EFI_PARTITION"
    echo ""
    echo "# Format boot partition"
    echo "mkfs.ext4 $BOOT_PARTITION"
    echo ""
    echo "# Format and setup root partition with btrfs subvolumes"
    echo "mkfs.btrfs -f $ROOT_PARTITION"
    echo "mount $ROOT_PARTITION /mnt"
    echo "btrfs su cr /mnt/@"
    echo "btrfs su cr /mnt/@pkg"
    echo "btrfs su cr /mnt/@log"
    echo "btrfs su cr /mnt/@snapshots"
    echo "umount /mnt"
    echo ""

    if [ -n "$HOME_PARTITION" ]; then
        echo "# Format and setup home partition with btrfs subvolume"
        echo "mkfs.btrfs -f $HOME_PARTITION"
        echo "mount $HOME_PARTITION /mnt"
        echo "btrfs su cr /mnt/@home"
        echo "umount /mnt"
        echo ""
    fi

    echo "# Mount root with subvolumes"
    echo "mount -o noatime,compress=zstd,subvol=@ $ROOT_PARTITION /mnt"
    echo "mkdir -p /mnt/var/log"
    echo "mount -o noatime,compress=zstd,subvol=@log $ROOT_PARTITION /mnt/var/log"
    echo "mkdir -p /mnt/var/cache/pacman/pkg"
    echo "mount -o noatime,compress=zstd,subvol=@pkg $ROOT_PARTITION /mnt/var/cache/pacman/pkg"
    echo "mkdir -p /mnt/.snapshots"
    echo "mount -o noatime,compress=zstd,subvol=@snapshots $ROOT_PARTITION /mnt/.snapshots"
    echo ""
    echo "# Mount boot partitions"
    echo "mkdir -p /mnt/boot"
    echo "mount $BOOT_PARTITION /mnt/boot"
    echo "mkdir -p /mnt/boot/efi"
    echo "mount $EFI_PARTITION /mnt/boot/efi"
    echo ""
    echo "# Mount home"
    echo "mkdir -p /mnt/home"
    if [ -n "$HOME_PARTITION" ]; then
        echo "mount -o noatime,compress=zstd,subvol=@home $HOME_PARTITION /mnt/home"
    else
        if [ -n "$HOME_MOUNT_OPTS" ]; then
            echo "mount -o $HOME_MOUNT_OPTS $EXISTING_HOME /mnt/home"
        else
            echo "mount $EXISTING_HOME /mnt/home"
        fi
    fi
    echo ""

    read -p "Continue? [Y/n] " confirm
    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        echo "Cancelled."
        return
    fi

    # Execute commands
    echo "=== Executing configuration ==="

    # Execute disk config if exists
    if [ -n "$DISK_CONFIG" ]; then
        echo "Creating GPT and partitions..."
        eval "$DISK_CONFIG"
        partprobe "$TARGET_DEVICE"
        sleep 2  # Give kernel time to recognize new partitions
    fi

    mkfs.fat -F32 "$EFI_PARTITION"
    mkfs.ext4 "$BOOT_PARTITION"

    mkfs.btrfs -f "$ROOT_PARTITION"
    mount "$ROOT_PARTITION" /mnt
    btrfs su cr /mnt/@
    btrfs su cr /mnt/@pkg
    btrfs su cr /mnt/@log
    btrfs su cr /mnt/@snapshots
    umount /mnt

    if [ -n "$HOME_PARTITION" ]; then
        mkfs.btrfs -f "$HOME_PARTITION"
        mount "$HOME_PARTITION" /mnt
        btrfs su cr /mnt/@home
        umount /mnt
    fi

    mount -o noatime,compress=zstd,subvol=@ "$ROOT_PARTITION" /mnt
    mkdir -p /mnt/var/log
    mount -o noatime,compress=zstd,subvol=@log "$ROOT_PARTITION" /mnt/var/log
    mkdir -p /mnt/var/cache/pacman/pkg
    mount -o noatime,compress=zstd,subvol=@pkg "$ROOT_PARTITION" /mnt/var/cache/pacman/pkg
    mkdir -p /mnt/.snapshots
    mount -o noatime,compress=zstd,subvol=@snapshots "$ROOT_PARTITION" /mnt/.snapshots

    mkdir -p /mnt/boot
    mount "$BOOT_PARTITION" /mnt/boot
    mkdir -p /mnt/boot/efi
    mount "$EFI_PARTITION" /mnt/boot/efi

    mkdir -p /mnt/home
    if [ -n "$HOME_PARTITION" ]; then
        mount -o noatime,compress=zstd,subvol=@home "$HOME_PARTITION" /mnt/home
    else
        if [ -n "$HOME_MOUNT_OPTS" ]; then
            mount -o "$HOME_MOUNT_OPTS" "$EXISTING_HOME" /mnt/home
        else
            mount "$EXISTING_HOME" /mnt/home
        fi
    fi

    echo "=== Configuration applied successfully! ==="
    echo "Mounted filesystems:"
    lsblk -f | grep /mnt
}

# Main interactive loop
echo "=== Arch Linux Storage Configuration ==="
echo "Type 'help' for available commands"
echo ""

read -p "Target device (e.g., /dev/nvme0n1, /dev/sda): " TARGET_DEVICE
if [ ! -b "$TARGET_DEVICE" ]; then
    echo "Error: $TARGET_DEVICE is not a valid block device!"
    exit 1
fi

echo "Target device set to: $TARGET_DEVICE"
echo ""

while true; do
    read -p "(target: $TARGET_DEVICE) >>> " cmd

    case "$cmd" in
        gpt)            cmd_gpt ;;
        n-efi)          cmd_n_efi ;;
        n-linuxfs)      cmd_n_linuxfs ;;
        set-efi)        cmd_set_efi ;;
        set-boot)       cmd_set_boot ;;
        set-root)       cmd_set_root ;;
        set-home)       cmd_set_home ;;
        set-existing-home) cmd_set_existing_home ;;
        list-part)      cmd_list_part ;;
        show-config)    cmd_show_config ;;
        reset)          cmd_reset ;;
        preset-pc)      cmd_preset_pc; break ;;
        write)          cmd_write; break ;;
        help)           print_help ;;
        "")             continue ;;
        *)              echo "Unknown command: $cmd (type 'help' for available commands)" ;;
    esac
    echo ""
done

## install the base system & some desired packages
echo ""
echo "=== Installing base system ==="
pacstrap -K /mnt base linux linux-firmware btrfs-progs efibootmgr nvim grub

## generate fstab
echo "=== Generating fstab ==="
genfstab -U /mnt >> /mnt/etc/fstab

echo ""
echo "=== Installation complete! ==="
echo "You can now chroot into the installation with:"
echo "  arch-chroot /mnt"
