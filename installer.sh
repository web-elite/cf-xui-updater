#!/usr/bin/env bash

SERVICE_NAME="cfscanner"
INSTALL_DIR="/opt/cfscanner"
LOG_DIR="$INSTALL_DIR/logs"
VENV_DIR="$INSTALL_DIR/venv"
RUNNER_SCRIPT="$INSTALL_DIR/cfscanner_runner.sh"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

function install_cfscanner() {
    echo "[+] Installing prerequisites..."
    sudo apt update -y && sudo apt install -y python3 python3-pip python3-venv git

    echo "[+] Creating directories..."
    sudo mkdir -p "$LOG_DIR"
    sudo chown -R $USER:$USER "$INSTALL_DIR"

    echo "[+] Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"

    echo "[+] Installing CFScanner..."
    pip install --upgrade pip
    pip install --upgrade git+https://github.com/MortezaBashsiz/CFScanner.git#subdirectory=python

    echo "[+] Creating runner script..."
    cat > "$RUNNER_SCRIPT" <<EOF
#!/usr/bin/env bash
source "$VENV_DIR/bin/activate"
while true; do
    TIMESTAMP=\$(date +"%Y%m%d_%H%M%S")
    echo "[+] Scanning at \$TIMESTAMP..."
    cfscanner > "$LOG_DIR/cfscanner_\$TIMESTAMP.log" 2>&1
    sleep INTERVAL_PLACEHOLDER
done
EOF
    chmod +x "$RUNNER_SCRIPT"

    echo "[+] Creating systemd service..."
    sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=CFScanner Auto IP Scanner
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/bin/bash $RUNNER_SCRIPT
Restart=always
RestartSec=10
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

    change_interval 1800 # default 30 min
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME

    echo "[+] Installation complete."
}

function uninstall_cfscanner() {
    echo "[!] Stopping and removing service..."
    sudo systemctl stop $SERVICE_NAME || true
    sudo systemctl disable $SERVICE_NAME || true
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload

    echo "[!] Removing files..."
    sudo rm -rf "$INSTALL_DIR"

    echo "[+] Uninstall complete."
}

function disable_cfscanner() {
    echo "[!] Disabling service..."
    sudo systemctl stop $SERVICE_NAME
    sudo systemctl disable $SERVICE_NAME
    echo "[+] Service disabled."
}

function change_interval() {
    local interval=$1
    echo "[+] Changing scan interval to $interval seconds..."
    sed -i "s/sleep .*/sleep $interval/" "$RUNNER_SCRIPT"
    sudo systemctl daemon-reload
    sudo systemctl restart $SERVICE_NAME
    echo "[+] Interval updated."
}

function menu() {
    clear
    echo "===== CFScanner Installer Menu ====="
    echo "1) Install"
    echo "2) Disable Service"
    echo "3) Uninstall"
    echo "4) Change Interval"
    echo "0) Exit"
    echo "===================================="
    read -rp "Select an option: " choice

    case $choice in
        1) install_cfscanner ;;
        2) disable_cfscanner ;;
        3) uninstall_cfscanner ;;
        4)
            read -rp "Enter interval in minutes: " minutes
            secs=$((minutes * 60))
            change_interval $secs
            ;;
        0) exit 0 ;;
        *) echo "[!] Invalid option" ;;
    esac
}

menu
