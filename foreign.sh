#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print informational messages in green
echo_info() {
    echo -e "\e[32m[INFO] $1\e[0m"
}

# Function to print error messages in red
echo_error() {
    echo -e "\e[31m[ERROR] $1\e[0m" >&2
}

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo_error "Please run as root."
    exit 1
fi

# Change to /root directory
cd /root

# 1. Run Hashemi Linux Optimizer script with options 2, n, 5, y
run_linux_optimizer() {
    echo_info "Downloading Linux Optimizer script..."
    wget "https://raw.githubusercontent.com/hawshemi/Linux-Optimizer/main/linux-optimizer.sh" -O /root/linux-optimizer.sh
    chmod +x /root/linux-optimizer.sh

    echo_info "Running Linux Optimizer with options 2 and 5, and answering 'n' to reboot..."
    bash /root/linux-optimizer.sh <<EOF
2
n
5
y
EOF
}

# 2. Block England IP ranges
block_england_ips() {
    echo_info "Blocking England IP ranges..."

    sudo iptables -A OUTPUT -d 25.0.0.0/8 -j DROP && sudo apt update && sudo apt install iptables-persistent && sudo iptables-save | sudo tee /etc/iptables/rules.v4
}

# 3. Install X-UI (version 2.4.8)
install_xui() {
    echo_info "Installing X-UI version 2.4.8..."
    VERSION="v2.4.8"
    bash <(curl -Ls "https://raw.githubusercontent.com/mhsanaei/3x-ui/$VERSION/install.sh") "$VERSION"
}

# 4. Backup and restore
# (Manual Step - Instructions provided at the end)

# 5. Change DNS in Cloudflare
# (Manual Step - Instructions provided at the end)

# 6. Download and configure Backhaul based on architecture
setup_backhaul() {
    echo_info "Setting up Backhaul..."

    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64|arm64)
            BACKHAUL_URL="https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_arm64.tar.gz"
            ;;
        x86_64|amd64)
            BACKHAUL_URL="https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_amd64.tar.gz"
            ;;
        *)
            echo_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    wget "$BACKHAUL_URL" -O backhaul.tar.gz
    tar -xzf backhaul.tar.gz
    rm backhaul.tar.gz LICENSE README.md

    echo_info "Creating Backhaul configuration..."
    read -p "Enter the tunnel IP: " TUNNEL_IP

    read -p "Enter the Backhaul Token: " BACKHAUL_TOKEN

    cat <<EOF > /root/config.toml
[client] 
remote_addr = "${TUNNEL_IP}:8080"
transport = "tcpmux"
token = "${BACKHAUL_TOKEN}"
connection_pool = 8
aggressive_pool = false
keepalive_period = 75
dial_timeout = 10
retry_interval = 3
nodelay = true
mux_version = 1
mux_framesize = 32768
mux_recievebuffer = 4194304
mux_streambuffer = 65536
sniffer = false
web_port = 3000
sniffer_log = "/root/backhaul.json"
log_level = "info"
EOF
}

# 7. Create systemd service for Backhaul
create_backhaul_service() {
    echo_info "Creating Backhaul systemd service..."

    tee /etc/systemd/system/backhaul.service > /dev/null <<EOF
[Unit]
Description=Backhaul Reverse Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/root/backhaul -c /root/config.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

# 8. Start Backhaul service
start_backhaul_service() {
    echo_info "Starting Backhaul service..."

    systemctl daemon-reload
    systemctl enable backhaul.service
    systemctl start backhaul.service
    systemctl status backhaul.service --no-pager
}

# Main Execution Flow
main() {
    # Prompt the user to decide whether to run Linux Optimizer
    read -p "Run Linux Optimizer? [y/N]: " RUN_OPTIMIZER
    case "$RUN_OPTIMIZER" in
        [yY][eE][sS]|[yY]) 
            run_linux_optimizer
            ;;
        *)
            echo_info "Skipping Linux Optimizer."
            ;;
    esac

    block_england_ips
    install_xui
    setup_backhaul
    create_backhaul_service
    start_backhaul_service

    echo_info "Setup completed successfully!"
    echo "Please restore the x-ui backup and change DNS in Cloudflare."
}

# Run the main function
main
