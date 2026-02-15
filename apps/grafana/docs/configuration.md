# Grafana Configuration Guide

Complete reference for all WeAura-vendorized Grafana configuration options across Helm and Terraform.

## Overview

Grafana configuration flows through three layers:

1. **Helm Values** (`apps/grafana/helm/weaura-grafana/values.yaml`) — Kubernetes-native configuration
2. **Terraform Variables** (`apps/grafana/terraform/modules/grafana-oss/variables.tf`) — Infrastructure-as-code configuration
3. **Environment Variables** — Runtime overrides (optional)

Both Helm and Terraform wrap the same underlying configuration, allowing you to choose your deployment method.

## Tenant Configuration (REQUIRED)

Every deployment requires tenant identification for multi-tenancy and resource isolation.

### Helm Values

```yaml
tenant:
  id: "acme-corp"           # REQUIRED — Alphanumeric, matches regex ^[a-z0-9-]+$
  name: "ACME Corporation"  # REQUIRED — Human-readable client name
```

### Terraform Variables

```hcl
variable "tenant_id" {
  description = "Tenant identifier for S3 paths and Kubernetes namespaces"
  type        = string
  # Regex validation: must match ^[a-z0-9-]+$
}

variable "tenant_name" {
  description = "Human-readable tenant name for labels and tags"
  type        = string
}
```

### Impact

- **Kubernetes Namespace**: Creates `{tenant_id}-observability` (e.g., `acme-corp-observability`)
- **S3 Paths**: All data stored under `s3://bucket/{tenant_id}/{component}/` (Loki, Mimir, Tempo)
- **IAM Roles**: Named `{tenant_id}-grafana-s3-access`
- **Tags**: Resources tagged with `Tenant: {tenant_name}`, `TenantID: {tenant_id}`

### Example

```bash
# Helm
--set tenant.id=acme-corp \
--set tenant.name="ACME Corporation"

# Terraform
tenant_id   = "acme-corp"
tenant_name = "ACME Corporation"
```

## Branding Configuration

Customize Grafana appearance with your organization's branding.

### Helm Values

```yaml
branding:
  appTitle: "ACME Observability"      # Page title in browser
  appName: "ACME Grafana"             # Application name in UI
  loginTitle: "Sign in to ACME"       # Login page title
  logoUrl: "https://example.com/logo.png"  # Logo URL (optional)
  cssOverrides:
    primaryColor: "#1f77b4"           # Custom primary color
    accentColor: "#ff7f0e"            # Accent color
```

### Terraform Variables

```hcl
variable "grafana_app_title" {
  description = "Grafana page title"
  type        = string
  default     = "Grafana"
}

variable "grafana_app_name" {
  description = "Application name displayed in UI"
  type        = string
  default     = "Grafana"
}

variable "grafana_login_title" {
  description = "Login page title"
  type        = string
  default     = "Sign in to Grafana"
}

variable "grafana_logo_url" {
  description = "Custom logo URL"
  type        = string
  default     = ""
}

variable "grafana_css_overrides" {
  description = "CSS overrides as key-value pairs"
  type        = map(string)
  default     = {}
}
```

### Implementation

- **appTitle** / **appName**: Updates `title` tag and UI header
- **logoUrl**: If set, init container downloads logo to mounted volume
- **cssOverrides**: Injected as `custom.css` ConfigMap and mounted to Grafana

### Example

```bash
# Helm
--set branding.appTitle="ACME Observability" \
--set branding.appName="ACME Grafana" \
--set branding.logoUrl="https://cdn.example.com/acme-logo.png"

# Terraform
grafana_app_title  = "ACME Observability"
grafana_logo_url   = "https://cdn.example.com/acme-logo.png"
grafana_css_overrides = {
  primaryColor = "#1f77b4"
}
```

## Stack Components

Enable or disable observability stack components (Loki, Mimir, Tempo, Pyroscope).

### Helm Values

```yaml
stack:
  grafana:
    enabled: true       # Grafana (always required)
  loki:
    enabled: true       # Log aggregation
  mimir:
    enabled: true       # Metrics storage (Prometheus-compatible)
  tempo:
    enabled: false      # Distributed tracing
  pyroscope:
    enabled: false      # Continuous profiling
```

### Terraform Variables

```hcl
variable "enable_grafana" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Enable Loki for logs"
  type        = bool
  default     = true
}

variable "enable_mimir" {
  description = "Enable Mimir for metrics"
  type        = bool
  default     = true
}

variable "enable_tempo" {
  description = "Enable Tempo for traces"
  type        = bool
  default     = false
}

variable "enable_pyroscope" {
  description = "Enable Pyroscope for continuous profiling"
  type        = bool
  default     = false
}
```

### Deployment Profiles

- **Minimal**: `grafana: true`, others `false` — Grafana only, metrics from external Prometheus
- **Standard**: `grafana: true`, `loki: true`, `mimir: true` — Full observability (logs + metrics)
- **Full Stack**: All enabled — Add distributed tracing and profiling

### Impact on Resources

| Component | CPU/Memory | Storage | Dependencies |
|-----------|-----------|---------|--------------|
| Grafana | 100m/128Mi | 10Gi | PostgreSQL (optional) |
| Loki | 200m/256Mi | 20Gi | S3 (AWS) or Azure Blob |
| Mimir | 500m/512Mi | 50Gi | S3 (AWS) or Azure Blob |
| Tempo | 300m/256Mi | 20Gi | S3 (AWS) or Azure Blob |
| Pyroscope | 200m/256Mi | 10Gi | S3 (AWS) or Azure Blob |

## Retention Policies

Configure data retention for logs, metrics, and traces (hours).

### Helm Values

```yaml
retention:
  loki: 720        # 30 days (default)
  mimir: 2160      # 90 days (default)
  tempo: 168       # 7 days (default)
  pyroscope: 168   # 7 days (default)
```

### Terraform Variables

```hcl
variable "retention_loki_hours" {
  description = "Loki log retention in hours"
  type        = number
  default     = 720  # 30 days
}

variable "retention_mimir_hours" {
  description = "Mimir metrics retention in hours"
  type        = number
  default     = 2160  # 90 days
}

variable "retention_tempo_hours" {
  description = "Tempo traces retention in hours"
  type        = number
  default     = 168  # 7 days
}

variable "retention_pyroscope_hours" {
  description = "Pyroscope profiles retention in hours"
  type        = number
  default     = 168  # 7 days
}
```

### Calculation

- **720 hours** = 30 days
- **2160 hours** = 90 days
- **168 hours** = 7 days
- **8760 hours** = 1 year

### Storage Impact

Approximate storage per day:
- Loki: 500MB-2GB/day (depends on log volume)
- Mimir: 1-5GB/day (depends on metric cardinality)
- Tempo: 500MB-2GB/day (depends on trace volume)

## SSO (Google OAuth)

Enable single sign-on with Google credentials.

### Helm Values

```yaml
sso:
  enabled: true
  google:
    clientId: "123456789.apps.googleusercontent.com"
    clientSecret: "GOCSPX-xxxxxxxxxxxxx"
    allowedDomains: "example.com,acme.com"  # Comma-separated
```

### Terraform Variables

```hcl
variable "enable_sso" {
  description = "Enable SSO authentication"
  type        = bool
  default     = false
}

variable "sso_google_client_id" {
  description = "Google OAuth 2.0 Client ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sso_google_client_secret" {
  description = "Google OAuth 2.0 Client Secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sso_allowed_domains" {
  description = "Comma-separated list of allowed email domains"
  type        = string
  default     = ""
}
```

### Setup Steps

1. **Create OAuth Credentials**:
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Select your project → **APIs & Services** → **Credentials**
   - Click **Create Credentials** → **OAuth client ID**
   - Choose **Web application**
   - Add authorized redirect URI: `https://your-grafana-domain/login/google/callback`

2. **Store Credentials Securely**:
   ```bash
   # Create Kubernetes secret
   kubectl create secret generic sso-google \
     --from-literal=client-id=YOUR_CLIENT_ID \
     --from-literal=client-secret=YOUR_CLIENT_SECRET \
     -n acme-corp-observability
   ```

3. **Enable in Values**:
   ```yaml
   sso:
     enabled: true
     google:
       clientId: "YOUR_CLIENT_ID"
       clientSecret: "YOUR_CLIENT_SECRET"
       allowedDomains: "acme.com"
   ```

### Security Notes

- **Secrets**: Use Kubernetes Secrets or AWS Secrets Manager, never in values.yaml
- **HTTPS**: Grafana must be accessed over HTTPS for OAuth to work
- **Redirect URI**: Must match exactly in Google Cloud Console
- **Domain Restrictions**: Use `allowedDomains` to limit access to organization users

## Database Backend

Choose between PostgreSQL (recommended) and SQLite (for testing only).

### Helm Values

```yaml
grafana:
  database:
    type: postgres  # or 'sqlite3'
    host: "postgres.default.svc.cluster.local"
    port: 5432
    name: "grafana"
    user: "grafana"
    # password: Use Kubernetes secret, not values
```

### Terraform Variables

```hcl
variable "grafana_database_type" {
  description = "Database backend: postgres or sqlite3"
  type        = string
  default     = "sqlite3"  # Development only
}

variable "grafana_db_host" {
  description = "Database host (PostgreSQL)"
  type        = string
  default     = "localhost"
}

variable "grafana_db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "grafana_db_name" {
  description = "Database name"
  type        = string
  default     = "grafana"
}

variable "grafana_db_user" {
  description = "Database user"
  type        = string
  default     = "grafana"
}

variable "grafana_db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = ""
}
```

### Deployment Options

- **SQLite** (default, development): No external dependency, data stored in PVC
- **PostgreSQL** (production): Managed RDS or external database

### RDS Setup (AWS)

```hcl
# Terraform example
resource "aws_db_instance" "grafana" {
  identifier       = "grafana-${var.tenant_id}"
  engine           = "postgres"
  engine_version   = "14.7"
  instance_class   = "db.t3.micro"
  allocated_storage = 20
  db_name          = "grafana"
  username         = "grafana"
  password         = random_password.grafana_db.result
  skip_final_snapshot = true
}
```

## Secrets Management

Manage sensitive configuration with Kubernetes Secrets or AWS Secrets Manager.

### Kubernetes Secrets (Default)

```bash
# Create secret for database password
kubectl create secret generic grafana-db \
  --from-literal=password=secure-password \
  -n acme-corp-observability

# Create SSO secret
kubectl create secret generic sso-google \
  --from-literal=client-id=YOUR_ID \
  --from-literal=client-secret=YOUR_SECRET \
  -n acme-corp-observability
```

### AWS Secrets Manager (Enterprise)

```bash
# Store secret in AWS
aws secretsmanager create-secret \
  --name grafana/acme-corp/db-password \
  --secret-string "{\"password\":\"secure-password\"}"

# Reference in Terraform
variable "use_aws_secrets_manager" {
  description = "Use AWS Secrets Manager instead of Kubernetes secrets"
  type        = bool
  default     = false
}
```

### Secret References in Helm

```yaml
# values.yaml
grafana:
  database:
    password: ""  # Leave empty, reference secret below

# templates/deployment.yaml
- name: GF_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: grafana-db
      key: password
```

## Configuration Examples

### Minimal (Helm)

```bash
helm install weaura-grafana ./apps/grafana/helm/weaura-grafana/ \
  --namespace acme-corp-observability \
  --set tenant.id=acme-corp \
  --set tenant.name="ACME Corporation"
```

### Full Stack with Branding (Terraform)

```hcl
# terraform.tfvars
tenant_id      = "acme-corp"
tenant_name    = "ACME Corporation"
cloud_provider = "aws"
cluster_name   = "production"

# Branding
grafana_app_title   = "ACME Observability Platform"
grafana_logo_url    = "https://cdn.acme.com/logo.png"
grafana_css_overrides = {
  primaryColor = "#1f77b4"
  accentColor  = "#ff7f0e"
}

# Stack
enable_grafana   = true
enable_loki      = true
enable_mimir     = true
enable_tempo     = false
enable_pyroscope = false

# Retention
retention_loki_hours  = 720   # 30 days
retention_mimir_hours = 2160  # 90 days
```

### Enterprise (SSO + PostgreSQL)

```yaml
# values.yaml
sso:
  enabled: true
  google:
    clientId: "123456789.apps.googleusercontent.com"
    clientSecret: "GOCSPX-xxxxxxxxxxxxx"
    allowedDomains: "acme.com"

grafana:
  database:
    type: postgres
    host: "grafana-db.acme.internal"
    port: 5432
    name: "grafana"
    user: "grafana"
    # password in Kubernetes secret
```

## Reference Files

- **Full Helm Values**: `apps/grafana/helm/weaura-grafana/values.yaml`
- **Terraform Variables**: `apps/grafana/terraform/modules/grafana-oss/variables.tf`
- **Example Profiles**: `examples/grafana/` (minimal.yaml, standard.tfvars, full-stack.tfvars)
