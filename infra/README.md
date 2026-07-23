# Infrastructure as Code (IaC) — Multi-Node AWS BEAM Cluster

This directory contains **Terraform / OpenTofu** code to automatically provision a multi-node, self-meshing Erlang/BEAM cluster on AWS EC2.

---

## What This IaC Provisions

1. **Security Group** (`absolute-beam-cluster-sg`):
   - Opens **80** (HTTP), **443** (HTTPS), and **22** (SSH).
   - Opens **4369** (EPMD) and **9000-9005** (BEAM Interconnect) between nodes inside the security group.
2. **2x EC2 Instances** (`t3.micro` — AWS Free Tier eligible):
   - Automatically installs Docker & Docker Compose via `user_data.tftpl`.
   - Generates production `.env` with unique `RELEASE_NODE=absolute@<PRIVATE_IP>` and shared `BEAM_COOKIE`.
   - Builds and launches the Phoenix app + Postgres database stack.

---

## Quick Start (3 Commands)

### 1. Initialize Terraform / OpenTofu

```bash
cd infra
terraform init
# or: tofu init
```

### 2. Preview the Plan

```bash
terraform plan
# or: tofu plan
```

### 3. Deploy the Infrastructure

```bash
terraform apply -auto-approve
# or: tofu apply -auto-approve
```

---

## Useful Options

### Scale the Cluster (e.g. 5 Nodes)

```bash
terraform apply -var="node_count=5"
```

### Change AWS Region

```bash
terraform apply -var="aws_region=eu-central-1"
```

### Clean Up & Destroy Infrastructure

```bash
terraform destroy -auto-approve
```
