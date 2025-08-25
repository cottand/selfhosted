# Terraform Infrastructure Management

The `terraform/` directory contains Infrastructure as Code definitions for cloud resources and service configurations.

## Structure

```
terraform/
├── base/           # Core infrastructure (DNS, secrets, websites)
├── ci/             # CI/CD infrastructure
├── consul/         # Consul service mesh configuration
├── grafana/        # Grafana cloud integration
├── metal/          # Physical and cloud compute instances
├── modules/        # Reusable Terraform modules
├── nomad/          # Nomad cluster policies and CSI
├── sso-via-vault/  # Single sign-on via Vault
├── vault/          # Vault configuration and policies
└── workloads-sso/  # Workload identity management
```

## Key Infrastructure Components

### Base Infrastructure (`base/`)
- DNS management for `dcotta.com` and `dcotta.eu`
- Tailscale coordination
- Vault KMS unsealing
- Static websites

### Compute Resources (`metal/`)
- GCP compute instances
- OCI (Oracle Cloud) instances  
- Load balancer configuration
- Instance IP resolution

### Security & Identity
- **Vault** - PKI, policies, auth methods, secret engines
- **SSO via Vault** - OIDC integration for services
- **Nomad** - Job policies and CSI volume management

## Development Workflow

### Planning Changes
```bash
cd terraform/[module]
terraform plan
```

### Applying Changes
```bash
terraform apply
```

### Managing State
Each module has its own backend configuration for state management.

## Module Organization

### Custom Modules (`modules/`)
- **node/** - Generic compute node configuration
- **roach-client/** - CockroachDB client setup
- **sso-identity/** - Identity provider configuration  
- **static-site/** - Static website hosting
- **workload-role/** - Nomad workload role management

### Provider Configurations
- **Google Cloud Platform** - Compute, BigQuery, IAM
- **Oracle Cloud Infrastructure** - Compute, load balancing
- **Cloudflare** - DNS, proxying
- **HashiCorp Vault** - Secret management
- **HashiCorp Nomad** - Job orchestration
- **HashiCorp Consul** - Service mesh

## Policies and Permissions

Vault and Nomad policies are defined in dedicated `policies/` subdirectories:
- Fine-grained access control
- Workload-specific permissions
- Admin and read-only roles