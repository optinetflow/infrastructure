#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print messages
echo_info() {
    echo -e "\e[32m[INFO] $1\e[0m"
}

echo_error() {
    echo -e "\e[31m[ERROR] $1\e[0m" >&2
}

# 1. Run Hashemi Linux Optimizer script twice with options 2 and 5
run_linux_optimizer() {
    echo_info "Downloading Linux Optimizer script..."
    wget "https://raw.githubusercontent.com/hawshemi/Linux-Optimizer/main/linux-optimizer.sh" -O linux-optimizer.sh
    chmod +x linux-optimizer.sh

    for option in 2 5; do
        echo_info "Running Linux Optimizer with option $option..."
        bash linux-optimizer.sh "$option"
    done
}

# 2. Block England IP ranges
block_england_ips() {
    echo_info "Blocking England IP ranges..."

    # Example IP ranges for England; you should replace these with actual ranges
    ENGLAND_IP_RANGES=(
        "5.0.0.0/8"
        # Add more IP ranges as needed
    )

    for ip in "${ENGLAND_IP_RANGES[@]}"; do
        sudo iptables -A OUTPUT -d "$ip" -j DROP
    done

    echo_info "Updating iptables-persistent..."
    sudo apt update
    sudo apt install -y iptables-persistent

    sudo iptables-save | sudo tee /etc/iptables/rules.v4
}

# 3. Install X-UI (version 2.4.8)
install_xui() {
    echo_info "Installing X-UI version 2.4.8..."
    VERSION="v2.4.8"
    bash <(curl -Ls "https://raw.githubusercontent.com/mhsanaei/3x-ui/$VERSION/install.sh") "$VERSION"
}

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
    cat <<EOF > /root/config.toml
[client] 
remote_addr = "placeholder_ip:8080"
transport = "tcpmux"
token = "zotgcFwR5Bbof2kQbEasttSaELdfrySTRkcDRcC9YIUVwXvCeYjCv0IaoI8HOpVr"
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

    sudo tee /etc/systemd/system/backhaul.service > /dev/null <<EOF
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

# Function to retrieve Tunnel IP
retrieve_tunnel_ip() {
    echo_info "Retrieving Tunnel IP..."

    # Wait for Backhaul service to start and establish the tunnel
    # Adjust the sleep time as necessary based on your network conditions
    sleep 10

    # Example method to retrieve tunnel IP from the log file
    # This assumes that Backhaul logs the tunnel IP upon connection
    # Adjust the grep/awk command based on actual log format
    TUNNEL_IP=$(grep "Tunnel established" /root/backhaul.json | awk -F '"' '{print $4}')

    # Check if TUNNEL_IP was found
    if [[ -z "$TUNNEL_IP" ]]; then
        echo_error "Failed to retrieve Tunnel IP. Please check the Backhaul logs."
        exit 1
    fi

    echo_info "Tunnel IP retrieved: $TUNNEL_IP"
}

# Function to update config.toml with the retrieved Tunnel IP
update_config() {
    echo_info "Updating config.toml with Tunnel IP..."

    # Use sed to replace the placeholder_ip with the actual Tunnel IP
    sudo sed -i "s/placeholder_ip:8080/${TUNNEL_IP}:8080/" /root/config.toml
}

# 8. Start Backhaul service
start_backhaul_service() {
    echo_info "Starting Backhaul service..."

    sudo systemctl daemon-reload
    sudo systemctl enable backhaul.service
    sudo systemctl start backhaul.service
    sudo systemctl status backhaul.service --no-pager
}

# 9. Restart Backhaul service to apply updated config
restart_backhaul_service() {
    echo_info "Restarting Backhaul service to apply updated config..."

    sudo systemctl restart backhaul.service
    sudo systemctl status backhaul.service --no-pager
}

# Main Execution Flow
main() {
    run_linux_optimizer
    block_england_ips
    install_xui
    setup_backhaul
    create_backhaul_service
    start_backhaul_service

    # Retrieve Tunnel IP
    retrieve_tunnel_ip

    # Update config.toml with the retrieved Tunnel IP
    update_config

    # Restart Backhaul service to apply the new configuration
    restart_backhaul_service

    echo_info "Setup completed successfully!"
    echo "Please proceed with manual steps 4 and 5."
}

# Run the main function
main
