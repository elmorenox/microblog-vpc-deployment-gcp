#!/bin/bash
# scripts/start_app.sh
# Update system packages
sudo apt update
sudo apt upgrade -y

# Install necessary packages
sudo apt install -y git python3 python3-pip python3-venv

# Create app directory if not exists
mkdir -p /home/ubuntu/microblog

# Get GitHub repository URL from file (created during instance setup)
GITHUB_REPO='https://github.com/elmorenox/microblog-vpc-deployment-gcp.git'

# Clone the repository
if [ -d "/home/ubuntu/microblog/.git" ]; then
  echo "Git repository already exists, pulling latest changes"
  cd /home/ubuntu/microblog
  git pull
else
  echo "Cloning repository from $GITHUB_REPO"
  git clone $GITHUB_REPO /home/ubuntu/microblog
  cd /home/ubuntu/microblog
fi

# Create and activate virtual environment
if [ ! -d "venv" ]; then
  python3 -m venv venv
fi
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install gunicorn pymysql cryptography python-dotenv prometheus-flask-exporter

# Create logs directory
mkdir -p logs

# Create .env file with necessary environment variables - replaced heredoc with echo statements
echo "SECRET_KEY=your-secret-key-$(date +%s)" > /home/ubuntu/microblog/.env
echo "DATABASE_URL=sqlite:///app.db" >> /home/ubuntu/microblog/.env
echo "LOG_TO_STDOUT=1" >> /home/ubuntu/microblog/.env
echo "MAIL_SERVER=localhost" >> /home/ubuntu/microblog/.env
echo "MAIL_PORT=25" >> /home/ubuntu/microblog/.env
echo "MAIL_USE_TLS=" >> /home/ubuntu/microblog/.env
echo "MAIL_USERNAME=" >> /home/ubuntu/microblog/.env
echo "MAIL_PASSWORD=" >> /home/ubuntu/microblog/.env
echo "ADMINS=your-email@example.com" >> /home/ubuntu/microblog/.env
echo "LANGUAGES=en,es" >> /home/ubuntu/microblog/.env
echo "MS_TRANSLATOR_KEY=" >> /home/ubuntu/microblog/.env
echo "ELASTICSEARCH_URL=" >> /home/ubuntu/microblog/.env
echo "REDIS_URL=redis:///" >> /home/ubuntu/microblog/.env

if [ -f "/home/ubuntu/microblog/.env" ]; then
  echo ".env file created successfully"
else
  echo "Failed to create .env file"
  exit 1
fi

# Initialize database
export FLASK_APP=microblog.py
flask db upgrade || flask db init && flask db migrate -m "initial migration" && flask db upgrade

# Add before the gunicorn command
echo "Starting gunicorn server..."
# Add after the gunicorn command
echo "Gunicorn server started with PID $(pgrep -f gunicorn)"

# Kill any existing gunicorn processes
pkill -f gunicorn || echo "No gunicorn processes running"

# Start the application with gunicorn in the background
gunicorn -b 0.0.0.0:5000 --access-logfile /home/ubuntu/microblog/logs/access.log --error-logfile /home/ubuntu/microblog/logs/error.log microblog:app --daemon

# Check if the application is running
sleep 10
if pgrep -f gunicorn > /dev/null; then
  echo "Application started successfully"
else
  echo "Failed to start the application"
  exit 1
fi

# Install Node Exporter for system monitoring
echo "Setting up Node Exporter for Prometheus monitoring..."
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
  echo "Node Exporter installed and started"
fi
