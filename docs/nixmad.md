# Nixmad - Nomad Job Deployment Tool

This project uses two related but distinct systems for Nomad job management:

1. **nix-nomad** - Third-party library for generating Nomad JSON from Nix configuration (from https://github.com/tristanpemble/nix-nomad)  
2. **nixmad** - Custom CLI tool for deploying generated jobs

## Job Definition Format

All Nomad jobs in this repository use the **nix-nomad options format** with `job."name"` syntax.

### Standard nix-nomad Format
All jobs use the standard nix-nomad module system with `job."name"` syntax.

**Examples:** All job files including `immich.nix`, `traefik.nix`, `grafana.nix`, `vector.nix`, `tempo.nix`, `loki.nix`

```nix
{ util, time, defaults, ... }: {
  job."whoami" = {
    group."whoami" = {
      network = {
        mode = "bridge";
        port."http".hostNetwork = "ts";
      };
      service."whoami" = {
        port = "http";
        tags = [ "traefik.enable=true" ];
      };
      task."whoami" = {
        driver = "docker";
        config = {
          image = "traefik/whoami";
        };
      };
    };
  };
}
```

## Helper Libraries

### Utility Functions
The `jobs/lib/default.nix` provides utility functions still used by the nix-nomad format:

- **Helper Functions**:
  - `mkEnvoyProxyConfig()` - Consul Connect proxy configuration  
  - `mkResourcesWithFactor()` - Resource scaling utilities
  - `defaults.dns.servers` - DNS configuration

- **Constants**: `seconds`, `minutes`, `hours`, `kiB`, `localhost`

### Module System Integration
Jobs are organized through the NixOS module system:
- All jobs are imported through `jobs/default.nix`
- Shared utilities available via `jobs/modules/`
- Automatic UI link generation for monitoring dashboards

## Job Deployment with nixmad

The custom `nixmad` CLI tool evaluates Nix job definitions and deploys them to Nomad.

### Usage

```bash
# Deploy a job
nix run .#nixmad -- path/to/job.nix

# Deploy with specific version
nixmad path/to/job.nix -v "1.2.3"

# Deploy using current git commit as version
nixmad path/to/job.nix --master
```

### How it works

1. Evaluates the Nix job file to JSON using the `gonix` library
2. Handles function-based jobs by passing version parameters
3. Pipes the generated JSON to `nomad run -json -`

## Job Organization

- `jobs/default.nix` - Imports all job modules
- `jobs/modules/` - Shared job utilities and modules
- `jobs/lib/` - Library functions for job composition
- Individual `.nix` files define specific services

## Deploying Jobs

### Using the nix-nomad flake output:
```bash
nix eval .#nomadJobs.grafana --json | nomad run --json -
```

### Using nixmad CLI tool:
```bash
# Deploy a job directly
nix run .#nixmad -- jobs/monitoring/grafana.nix

# Deploy with specific version
nixmad jobs/monitoring/grafana.nix -v "1.2.3"
```
