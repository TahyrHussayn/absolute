# ⚡ Absolute

> **Production-Grade Phoenix 1.8 & BEAM Showcase Web Application**
> 
> *Distributed Concurrency • OTP Fault Tolerance • Keyless AWS IaC • Prometheus & Grafana Observability*

---

## 🌟 Overview

**Absolute** is a state-of-the-art web application built on **Elixir, Phoenix 1.8, and the Erlang/OTP Virtual Machine (BEAM)**. It showcases the incredible strength of distributed concurrent systems, real-time LiveView streaming, self-healing process supervision, and cloud-native keyless infrastructure.

---

## 🚀 Feature Highlights

### ⚡ 1. Interactive BEAM & OTP Playground (`/playground`)
Contains **15 live interactive demonstrations** of core BEAM capabilities:
- 🔄 **Real-Time PubSub Counter**: Global state updates pushed instantaneously across tabs without custom JavaScript.
- ⚡ **Mass Concurrency Spawner**: Spawns **100,000 green threads** (~2KB each) concurrently with sub-second execution speeds.
- 🛡️ **Self-Healing Supervision ("Let It Crash")**: Intentionally crash GenServer workers and observe supervisor auto-recovery in real-time.
- 💬 **Zero-JS Multi-Tab Chat**: Driven by Phoenix LiveView Streams and PubSub broadcasts.
- 📊 **Live BEAM Introspection**: Real-time memory allocation breakdown (heap, binary, atom), scheduler core counts, and process limits updated every second.
- 🗄️ **ETS In-Memory Storage**: State survives GenServer manager crashes via Erlang Term Storage.
- 👥 **DynamicSupervisor Workers**: Dynamically spawns isolated GenServer processes per user session at runtime.
- 🌐 **Phoenix Presence (CRDT)**: Real-time user presence tracking with zero database overhead.
- 📦 **Agent Shared State**: Concurrency-safe shared mutable state without mutexes.
- 🔍 **Registry Process Lookup**: Dynamic process registration and lookup by custom keys.
- ♾️ **Lazy Infinite Streams**: Memory-efficient stream unfolding for large Fibonacci computations.
- 🌀 **Tail Call Optimization (TCO)**: Executes 1,000,000 recursive function calls with zero stack growth.
- 🔢 **Binary Pattern Matching**: Direct TCP packet parsing using native `<<src::16, dst::16, ...>>` bit syntax.
- 📈 **Telemetry Event Pipeline**: Live monitoring of system events emitted across the application.

---

### 🕸️ 2. Multi-Node Distributed BEAM Cluster Mesh (`/cluster`)
- Connects multiple Erlang/OTP nodes over native TCP (`4369` EPMD & `9000-9005` distribution ports).
- Features live cluster discovery, cross-node node pinging, and CRDT-based multi-server PubSub broadcast messaging.

---

### 📊 3. Prometheus & Grafana Observability Stack
- **Native Metrics Endpoint (`GET /metrics`)**: Sub-millisecond Prometheus text exposition exporter for VM memory, active process counts, scheduler load, and run queue lengths.
- **Prometheus Server (`:9090`)**: Auto-scrapes application metrics every 5 seconds.
- **Grafana Dashboard (`:3000`)**: Real-time visualization of process load, latencies, and memory metrics.
- **Phoenix LiveDashboard (`/admin/dashboard`)**: Production process tree inspection, ETS tables, and BEAM tracing.

---

### 🔐 4. Peak Cloud Security & Infrastructure-as-Code (IaC)
- **Terraform AWS Manifests (`infra/`)**: Provisions AWS VPC, Security Group, EC2 instance profiles, and S3 state backend (`absolute-tfstate`) with DynamoDB locks (`absolute-tflocks`).
- **Keyless GitHub Actions Authentication (`infra/oidc.tf`)**: Zero long-lived AWS IAM credentials! Uses OpenID Connect (OIDC) federated tokens for secure deployment.
- **AWS SSM Parameter Store (`infra/ssm.tf`)**: Encrypts production secrets using AWS KMS.
- **Cloud-Init Boot Script (`user_data.tftpl`)**: Automatically fetches secrets via AWS CLI on instance boot.

---

### 🤖 5. Rock-Solid Gated CI/CD Pipeline (`.github/workflows/deploy.yml`)
- Triggers on push to `main` branch.
- **Verification Gates**:
  1. Elixir compilation with `--warnings-as-errors`.
  2. Formatting verification (`mix format --check-formatted`).
  3. Automated unit & integration tests (`mix test`).
  4. Docker production image build validation.
  5. Terraform syntax validation & linting (`terraform fmt -check`).
  6. Keyless AWS EC2 deployment via OIDC role assumption.

---

## 🏗️ Day 0 AWS Bootstrap Workflow

For new AWS accounts, run the automated **Industry-Standard Day 0 Bootstrap Script** ONCE from your computer to provision the S3 state backend, DynamoDB locks, and OIDC Keyless Role:

```bash
# 1. Ensure your local terminal is authenticated to your AWS Account:
#    (Run 'aws sso login' or 'aws configure' if not already logged in)
aws sso login

# 2. Run the Day 0 Bootstrap Task (using Make or Mix):
make bootstrap    # Polyglot DevOps task
# OR
mix bootstrap     # Native Elixir Mix task
```

> **Note**: The script automatically verifies your active AWS login session (`aws sts get-caller-identity`). If your terminal is already logged into AWS, simply run `make bootstrap` directly!

The script will provision the required resources in your AWS account and output your **12-Digit Account ID** to set as `AWS_ACCOUNT_ID` under GitHub Repo ➔ **Settings ➔ Secrets and variables ➔ Actions**.

From that point forward, all deployments are 100% automated via keyless OIDC on git push!

---

## 💣 Total AWS Teardown & Resource Destruction (Zero Cloud Cost)

When you are done testing and want to **completely wipe every single AWS resource** (EC2 instances, security groups, IAM roles, S3 state buckets, DynamoDB lock tables, SSM parameters) so you incur **$0 ongoing AWS charges**:

```bash
# Run the automated Total Destruction task (using Make or Mix):
make destroy    # Polyglot DevOps task
# OR
mix destroy     # Native Elixir Mix task
```

The script will prompt for confirmation and violently destroy **100% of provisioned resources in your AWS account**.

---

## 🛠️ Local Development Guide

### Prerequisites
- Elixir `1.17+` & Erlang/OTP `27+`
- PostgreSQL `18+` (or Docker)

### Quickstart Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/YOUR_GITHUB_USERNAME/absolute.git
   cd absolute
   ```

2. **Start Local PostgreSQL**:
   ```bash
   docker compose up -d postgres
   ```

3. **Install Dependencies & Setup Database**:
   ```bash
   mix setup
   ```

4. **Start the Phoenix LiveView Server**:
   ```bash
   mix phx.server
   ```
   Open [`localhost:4000`](http://localhost:4000) in your browser!

5. **Run Pre-Commit Verification Suite**:
   ```bash
   mix precommit
   ```

---

## 🐳 Docker & Production Stack

To run the complete production stack (App + Postgres + Prometheus + Grafana) locally or on a server:

```bash
# 1. Start all production containers
docker compose -f compose.prod.yaml up -d --build

# 2. Run database migrations
docker compose -f compose.prod.yaml exec app /app/bin/migrate

# Access Services:
# - Application: http://localhost:80 (or http://localhost:4000)
# - Prometheus:  http://localhost:9090
# - Grafana:     http://localhost:3000
```

---

## 🧪 Testing

The codebase includes an automated ExUnit test suite:

```bash
# Run all tests
mix test

# Run tests with warnings-as-errors precommit check
mix precommit
```

---

## 📄 License

Absolute is open-source software licensed under the MIT License.
