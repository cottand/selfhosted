# Nixmad - Nomad Job Deployment Tool

This project uses two related but distinct systems for Nomad job management:

1. **nix-nomad** - Third-party library for generating Nomad JSON from Nix configuration (from https://github.com/tristanpemble/nix-nomad)
2. **nixmad** - Custom CLI tool for deploying generated jobs

## Two Job Definition Dialects

The repository contains jobs defined in **two different dialects**:

### 1. nix-nomad Dialect (Third-party)
Uses the standard nix-nomad module system with `job."name"` syntax.

**Examples:** `immich.nix`, `traefik.nix`, `attic.nix`

```nix
{ util, ... }: {
  job."whoami" = {
    group."whoami" = {
      network = {
        mode = "bridge";
        port."http".hostNetwork = "ts";
      };
      # ... standard nix-nomad syntax
    };
  };
}
```

### 2. Custom nixmad Dialect  
Uses a custom transformation library defined in `jobs/lib/default.nix` with `lib.mkJob` function.

**Examples:** `loki.nix`, `tempo.nix`, `vector.nix`

```nix
let
  lib = (import ../lib) { };
in
lib.mkJob "vector" {
  type = "system";
  group."vector" = {
    network = {
      mode = "bridge";
      # ... custom nixmad syntax with transformations
    };
    # ... gets transformed via lib.transformJob
  };
}
```

## Key Differences

### Custom nixmad Library Features
The custom dialect (`jobs/lib/default.nix`) provides:

- **Field Transformations**: Converts Nix-friendly syntax to Nomad JSON format
  - `group` → `taskGroups` (as list)
  - `task` → `tasks` (as list) 
  - `service` → `services` (as list)
  - `upstream` → `upstreams` (as list)

- **Helper Functions**:
  - `mkJob(name, config)` - Creates job with automatic UI links
  - `mkServiceGoGrpc()` - Template for Go gRPC services
  - `mkEnvoyProxyConfig()` - Consul Connect proxy configuration
  - `mkResourcesWithFactor()` - Resource scaling utilities

- **Constants**: `seconds`, `minutes`, `hours`, `kiB`, `localhost`

### Standard vs Custom Syntax

**Standard nix-nomad** (e.g., `immich.nix`):
```nix
{ util, ... }: {
  job."immich" = {
    group."immich-server" = {
      # Direct Nomad JSON structure
    };
  };
}
```

**Custom nixmad** (e.g., `vector.nix`):
```nix
let lib = (import ../lib) { }; in
lib.mkJob "vector" {
  # Gets transformed via lib.transformJob
  group."vector" = {
    # More Nix-friendly syntax
  };
}
```

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

## Deploying with nix-nomad

```bash
nix eval .#nomadJobs.grafana --json | nomad run --json -
```
