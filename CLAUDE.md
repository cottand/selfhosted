# Self-hosted Fleet Infrastructure

This repository contains the configuration-as-code for a personal self-hosted cluster using Nomad, Consul, Vault, and NixOS.

## Project Structure

- `jobs/` - Nixmad job definitions that generate HCL for Nomad workloads
- `machines/` - NixOS configurations for cluster nodes managed via Colmena
- `dev-go/` - Go services and CLI tools (nixmad, shipper, custom services)
- `terraform/` - Infrastructure as code for cloud resources and service configuration
- `csi-volumes/` - CSI volume definitions for persistent storage
- `secret/` - Encrypted secrets and PKI certificates
- `misc/` - Miscellaneous configs and dashboards
- `scripts/` - Build and deployment scripts

## Key Technologies

- **Nomad** - Container orchestration and job scheduling
- **Consul** - Service discovery and service mesh
- **Vault** - Secret management and PKI authority
- **NixOS** - Declarative OS configuration management
- **Wireguard** - Secure node-to-node networking
- **SeaweedFS** - Distributed file system for persistent storage
- **CockroachDB** - Distributed SQL database

## Common Commands

- **Deploy jobs**: `nix run .#nixmad -- path/to/job.nix`
- **Deploy infrastructure**: `nix run .#shipper`
- **Build all services**: `nix build .#services`
- **Deploy machines**: `colmena deploy`
- **Format code**: `nix fmt`

## Development Workflows

- **Nixmad jobs**: See [docs/nixmad.md](docs/nixmad.md) for details on the Nix-to-HCL job system
- **Go services**: See [docs/go-services.md](docs/go-services.md) for service development
- **Terraform**: See [docs/terraform.md](docs/terraform.md) for infrastructure management
- **Machine configuration**: See [docs/machines.md](docs/machines.md) for NixOS node management

## Architecture

The cluster consists of multiple nodes connected via Tailscale:
- Hetzner and Contabo VPS nodes in Germany
- Physical machines in London, UK and Madrid, Spain
- Cloudflare proxies public HTTP traffic
- All services communicate over encrypted mesh network

## Testing & Linting

Run `nix fmt` to format Nomad and Terraform files.
Check service builds with `nix build .#services`.


# Workflows

### Set up a cockraochDB user

1. Create certificate and put cert in vault at secrets v2 path `/nomad/job/roach/users/${name}` (see examples at terraform/vault/pki_roach.tf)
2. Add certificate to secrets of cockroachDB runtime, for example:

  ```diff
  --- a/jobs/roach.nix
  +++ b/jobs/roach.nix
  @@ -207,7 +207,7 @@ let
             '';
             perms = "0600";
           }
  -      ] ++ builtins.concatLists (map certsForUser [ "root" "grafana" ]);
  +      ] ++ builtins.concatLists (map certsForUser [ "root" "grafana" "ente" ]);
       };
     };
   in
  ```
3. Create SQL migration file under `./misc/sql`
4. Report as done

### Provision a Nomad job

1. Create a job definition under `jobs/`
2. Add the job definition to `jobs/default.nix`
3. Validate with `nix eval .#nomadJobs.{name} --json`
4. Report as done