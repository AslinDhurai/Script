Automate security patch updates:
#!/bin/bash
LOGFILE="/var/log/patch_updates.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

{
  echo "===== Security Patch Update Started at $DATE ====="

  if command -v yum &>/dev/null; then
    echo "[INFO] Detected RHEL/CentOS (using yum)"
    yum --security update -y --exclude=kernel*

  elif command -v apt &>/dev/null; then
    echo "[INFO] Detected Debian/Ubuntu (using apt)"
    apt update -y
    
    if ! dpkg -l | grep -qw unattended-upgrades; then
      echo "[INFO] Installing unattended-upgrades"
      apt install -y unattended-upgrades
    fi
    echo "[INFO] Configuring unattended-upgrades to exclude kernel updates"
    cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
        "\${distro_id}:\${distro_codename}";
        "\${distro_id}:\${distro_codename}-security";
};

Unattended-Upgrade::Package-Blacklist {
        "linux-image";
        "linux-headers";
        "linux-modules";
        "linux-modules-extra";
};

Unattended-Upgrade::Automatic-Reboot "false";
EOF
    echo "[INFO] Running unattended-upgrades"
    unattended-upgrade -d -o Dpkg::Options::="--force-confold"

  else
    echo "[ERROR] No supported package manager found."
    exit 1
  fi

  echo "===== Security Patch Update Finished at $(date '+%Y-%m-%d %H:%M:%S') ====="
  echo ""

} >> "$LOGFILE" 2>&1
