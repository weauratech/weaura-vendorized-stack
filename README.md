# weaura-vendorized-stack

Monorepo for WeAura vendorized stack infrastructure (Grafana, Rancher, Metabase, Kubecost).

## Overview

This repository contains production-ready infrastructure configurations for vendorized stack applications deployed across customer environments. It's designed as a scalable monorepo where each application has its own subdirectory under `apps/`, allowing for independent versioning, deployment, and configuration management.

## Repository Structure

```
weaura-vendorized-stack/
├── apps/                           # Vendorized applications
│   ├── grafana/                    # Grafana configuration & infrastructure
│   │   ├── helm/                   # Helm chart overrides & values
│   │   ├── terraform/              # Infrastructure-as-Code (IaC) definitions
│   │   ├── docker/                 # Custom Dockerfile & entrypoints
│   │   ├── content-packs/          # Grafana dashboards & alerts
│   │   │   ├── dashboards/         # Dashboard JSON definitions
│   │   │   └── alerts/             # Alert rule definitions
│   │   └── docs/                   # Grafana-specific documentation
│   ├── rancher/                    # (Future) Rancher configuration
│   ├── metabase/                   # (Future) Metabase configuration
│   └── kubecost/                   # (Future) Kubecost configuration
├── shared/                         # Shared utilities & CI/CD
│   ├── scripts/                    # Common shell scripts, utilities
│   └── ci/                         # Shared CI/CD configurations
├── examples/                       # Example deployments & use cases
├── .github/
│   └── workflows/                  # GitHub Actions workflows
└── README.md
```

## Adding New Applications

To add a new vendorized app (e.g., Rancher, Metabase):

1. Create the application directory:
   ```bash
   mkdir -p apps/{app-name}/{helm,terraform,docker,docs}
   ```

2. Add app-specific subdirectories as needed:
   - `helm/` for Helm chart customizations
   - `terraform/` for infrastructure definitions
   - `docker/` for custom container images
   - `docs/` for application-specific documentation

3. Reference shared utilities from `shared/` and `shared/ci/`

## Directory Purposes

### `apps/grafana/`
- **helm/**: Helm values files and chart overrides for Grafana deployments
- **terraform/**: Terraform modules for Grafana infrastructure (RDS, storage, networking)
- **docker/**: Dockerfile for custom Grafana images with pre-installed plugins
- **content-packs/dashboards/**: JSON dashboard definitions (importable into Grafana)
- **content-packs/alerts/**: Alert rule definitions and notification configs
- **docs/**: Grafana deployment guides, configuration best practices

### `shared/`
- **scripts/**: Reusable shell scripts (backup automation, health checks, migrations)
- **ci/**: Shared GitHub Actions workflows, deployment scripts

### `examples/`
Example deployments showing end-to-end setup for customer environments

### `.github/workflows/`
GitHub Actions for CI/CD (linting, testing, deployment workflows)

## Development & Deployment

Each application follows this workflow:

1. **Development**: Modify configs in `apps/{app}/`
2. **Testing**: Run validation/linting (CI in `.github/workflows/`)
3. **Staging**: Deploy to staging cluster
4. **Production**: Promote to production

## License

This repository is licensed under **AGPL-3.0** because it includes and distributes Grafana configurations and customizations.

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make changes in the appropriate `apps/*/` subdirectory
3. Test locally and via GitHub Actions
4. Submit a pull request with detailed description

## References

- [aura-helm-charts](https://github.com/weauratech/aura-helm-charts) - Chart patterns and structure
- [aura-platform-foundation](https://github.com/weauratech/aura-platform-foundation) - Environment organization examples
