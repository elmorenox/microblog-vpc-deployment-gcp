#!/bin/bash
# scripts/monitoring_setup.sh
# Update system packages
sudo apt update
sudo apt upgrade -y

# Install necessary packages
sudo apt install -y wget git unzip

# Create directories for Prometheus and Grafana
sudo mkdir -p /opt/prometheus /opt/grafana /etc/prometheus

# Download and install Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.37.0/prometheus-2.37.0.linux-amd64.tar.gz
tar -xvf prometheus-2.37.0.linux-amd64.tar.gz
sudo cp prometheus-2.37.0.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.37.0.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-2.37.0.linux-amd64/consoles /etc/prometheus
sudo cp -r prometheus-2.37.0.linux-amd64/console_libraries /etc/prometheus
rm -rf prometheus-2.37.0.linux-amd64*

# Create Prometheus configuration with app server IP
cat > /tmp/prometheus.yml << 'EOL'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  # Remove the flask_app job if you're not instrumenting the app
  # - job_name: 'flask_app'
  #   static_configs:
  #     - targets: ['10.0.2.100:5000']
  
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['10.0.2.100:9100', 'localhost:9100']
EOL

sudo cp /tmp/prometheus.yml /etc/prometheus/prometheus.yml

# Create Prometheus service
cat > /tmp/prometheus.service << 'EOL'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/opt/prometheus \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOL

sudo cp /tmp/prometheus.service /etc/systemd/system/prometheus.service

# Download and install Grafana
cd /tmp
wget https://dl.grafana.com/oss/release/grafana-9.0.5.linux-amd64.tar.gz
tar -zxvf grafana-9.0.5.linux-amd64.tar.gz
sudo mv grafana-9.0.5 /opt/grafana
# Copy default configuration files
sudo mkdir -p /opt/grafana/conf
sudo cp -r /opt/grafana/grafana-9.0.5/conf/* /opt/grafana/conf/

# Set appropriate permissions
sudo chown -R ubuntu:ubuntu /opt/grafana
rm grafana-9.0.5.linux-amd64.tar.gz

# Set up folders for dashboards (we'll use API for datasources)
sudo mkdir -p /opt/grafana/conf/provisioning/dashboards

# Create a basic dashboard provisioning file
cat > /tmp/dashboard_provider.yml << 'EOL'
apiVersion: 1
providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /opt/grafana/conf/provisioning/dashboards
EOL
sudo cp /tmp/dashboard_provider.yml /opt/grafana/conf/provisioning/dashboards/

# Create custom Grafana configuration to disable API authentication
sudo mkdir -p /opt/grafana/conf/custom
cat > /tmp/custom.ini << 'EOL'
[auth]
# Disable login form
disable_login_form = false

[auth.anonymous]
# Enable anonymous access
enabled = true
# Organization name that should be used for anonymous users
org_name = Main Org.
# Role for anonymous users
org_role = Admin

[security]
# Disable authentication for the API
disable_initial_admin_creation = true
api_key_max_seconds_to_live = 0

[auth.proxy]
enabled = false
EOL

sudo cp /tmp/custom.ini /opt/grafana/conf/custom/custom.ini

# Create Grafana service with both config files
cat > /tmp/grafana.service << 'EOL'
[Unit]
Description=Grafana
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/opt/grafana/grafana-9.0.5/bin/grafana-server \
  --config=/opt/grafana/conf/defaults.ini \
  --config=/opt/grafana/conf/custom/custom.ini \
  --homepath=/opt/grafana/grafana-9.0.5

[Install]
WantedBy=multi-user.target
EOL

sudo cp /tmp/grafana.service /etc/systemd/system/grafana.service

# Set up Node Exporter for local monitoring
echo "Setting up Node Exporter for local monitoring..."
if ! command -v node_exporter &> /dev/null; then
  cd /tmp
  wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
  tar -xvf node_exporter-1.3.1.linux-amd64.tar.gz
  sudo cp node_exporter-1.3.1.linux-amd64/node_exporter /usr/local/bin/
  rm -rf node_exporter-1.3.1.linux-amd64*

  sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable node_exporter
  sudo systemctl start node_exporter
fi

# Start services
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl enable grafana
sudo systemctl start grafana

# Wait for Grafana to fully start
echo "Waiting for Grafana to start..."
sleep 15

# Create Prometheus datasource via API
echo "Creating Prometheus datasource via API..."
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090","access":"proxy","isDefault":true}' \
  http://localhost:3000/api/datasources

echo "Monitoring server setup completed"