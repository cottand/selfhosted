# Go Services Development

The `dev-go/` directory contains Go services and CLI tools for the cluster.

## Structure

```
dev-go/
├── cmd/                    # CLI tools
│   ├── nixmad/            # Job deployment CLI
│   └── shipper/           # Infrastructure deployment CLI
├── services/              # Microservices
├── lib/                   # Shared libraries
└── vendor/                # Go module dependencies
```

## CLI Tools

### nixmad
Custom deployment tool for Nomad jobs defined in Nix.
- Evaluates `.nix` job files to JSON
- Supports versioned deployments
- Integrates with `nomad run` command

### shipper
Infrastructure deployment tool.
- Handles service deployments
- Coordinates with Nomad cluster

## Services

Services follow a consistent structure:
- `module.go` - Service module definition
- `handler.go` - HTTP/RPC handlers  
- `package.nix` - Nix package definition
- `job.nix` - Nomad job definition (if applicable)

### Available Services

- **s-rpc-nomad-api** - Nomad API service
- **s-rpc-portfolio-stats** - Portfolio statistics service  
- **s-rpc-vault** - Vault integration service
- **s-web-github-webhook** - GitHub webhook handler
- **s-web-portfolio** - Portfolio web service
- **cron-vault-snapshot** - Vault backup service

## Shared Libraries

- **bedrock/** - Core infrastructure (DB, telemetry, modules)
- **config/** - Configuration management
- **nix/** - Nix evaluation utilities  
- **proto/** - Generated protobuf code
- **util/** - Common utilities

## Development

### Building Services

```bash
# Build all services
nix build .#services

# Build specific service  
nix build .#services.s-web-portfolio
```

### Running Services

Services are deployed via Nomad jobs that reference the Nix-built binaries.

### Adding New Services

1. Create service directory under `services/`
2. Add `module.go`, `handler.go`, `package.nix`
3. Create Nomad job definition if needed
4. Add to `services/default.nix` imports

### Proto Generation

```bash
nix run .#scripts.gen-protos
```