# AWS EC2 Production Deployment Guide

This guide details how to deploy **Absolute** on an AWS EC2 instance using **Docker Compose** for maximum performance and minimal cost (~$0 for 12 months free tier, ~$8/mo after).

---

## Architecture Overview

```
┌──────────────────────── AWS EC2 (t3.micro) ────────────────────────┐
│                                                                    │
│   ┌───────────────────────────┐    ┌───────────────────────────┐   │
│   │ Phoenix Web Application   │───►│ PostgreSQL 18 Database    │   │
│   │ (Port 4000 / Port 80)     │    │ (Docker container)        │   │
│   └───────────────────────────┘    └───────────────────────────┘   │
│                                                                    │
│   Docker Compose manages container orchestration & networking      │
└────────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Launch your AWS EC2 Instance

1. Log into your **AWS Management Console** and open **EC2**.
2. Click **Launch Instance**.
3. **Name**: `absolute-production`
4. **OS Image (AMI)**: **Ubuntu Server 24.04 LTS** (64-bit x86).
5. **Instance Type**: `t3.micro` (eligible for 12 months free tier).
6. **Key Pair**: Select existing or create a new SSH key pair and download `.pem`.
7. **Network Settings**:
   - Allow **SSH** (Port 22) from your IP
   - Allow **HTTP** (Port 80) from anywhere (`0.0.0.0/0`)
   - Allow **HTTPS** (Port 443) from anywhere (`0.0.0.0/0`)
8. Click **Launch Instance**.

---

## Step 2: Connect to your EC2 Instance

```bash
ssh -i /path/to/your-key.pem ubuntu@<YOUR-EC2-PUBLIC-IP>
```

---

## Step 3: Install Docker & Docker Compose on EC2

Run the following script on your EC2 instance:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg git

# Install Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow non-root docker execution
sudo usermod -aG docker $USER
newgrp docker
```

---

## Step 4: Clone Repository & Set Environment Variables

```bash
# Clone repository
git clone https://github.com/YOUR_GITHUB_USERNAME/absolute.git
cd absolute

# Create production env file
cat << 'EOF' > .env
SECRET_KEY_BASE=$(openssl rand -base64 48)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$(openssl rand -hex 16)
POSTGRES_DB=absolute_prod
DATABASE_URL=ecto://postgres:${POSTGRES_PASSWORD}@postgres:5432/absolute_prod
PHX_HOST=<YOUR-EC2-PUBLIC-IP-OR-DOMAIN>
PORT=4000
EOF
```

---

## Step 5: Launch Containers

```bash
# Build and run containers in detached mode
docker compose -f compose.prod.yaml up -d --build

# Run database migrations
docker compose -f compose.prod.yaml exec app /app/bin/migrate
```

---

## Step 6: Verify Deployment

Check container status and logs:

```bash
docker compose -f compose.prod.yaml ps
docker compose -f compose.prod.yaml logs -f
```

Open `http://<YOUR-EC2-PUBLIC-IP>` in your web browser!

---

## Useful Commands

- **Stop App**: `docker compose -f compose.prod.yaml down`
- **Restart App**: `docker compose -f compose.prod.yaml restart`
- **View Logs**: `docker compose -f compose.prod.yaml logs -f app`
- **Update Deployment (after git push)**:
  ```bash
  git pull
  docker compose -f compose.prod.yaml up -d --build
  docker compose -f compose.prod.yaml exec app /app/bin/migrate
  ```
