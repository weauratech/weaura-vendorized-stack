# Grafana OSS Quickstart Guide

Get a WeAura-vendorized Grafana deployment up and running in minutes using Helm or Terraform.

## Prerequisites

Before deploying, ensure you have:

- **kubectl** (v1.25+) — Kubernetes cluster access
- **helm** (v3.12+) — Package manager for Kubernetes (`curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`)
- **Terraform** (v1.0+) — For infrastructure-as-code deployments
- **AWS CLI** (v2) — If deploying to AWS with S3 backend (optional)
- **Kubernetes cluster** — EKS, AKS, or self-managed (v1.25+)
- **Cluster admin access** — To create namespaces and install Helm charts

Verify prerequisites:

```bash
kubectl version --client
helm version
terraform version
aws --version  # Only if using AWS
```

## Helm Deployment (Minimal Profile)

Deploy Grafana only (no observability stack) using Helm. Best for evaluating Grafana functionality.

### Step 1: Add Helm Repository (if using published charts)

```bash
helm repo add weaura https://charts.weaura.io  # Will be available after release
helm repo update
```

Or use local chart:

```bash
cd weaura-vendorized-stack
helm repo add weaura ./apps/grafana/helm
```

### Step 2: Create Namespace

```bash
kubectl create namespace acme-corp-observability
```

### Step 3: Deploy Grafana

```bash
helm install weaura-grafana ./apps/grafana/helm/weaura-grafana/ \
  --namespace acme-corp-observability \
  --set tenant.id=acme-corp \
  --set tenant.name="ACME Corporation" \
  --set grafana.image.tag=10.4.0
```

Or use example values file:

```bash
helm install weaura-grafana ./apps/grafana/helm/weaura-grafana/ \
  --namespace acme-corp-observability \
  --values examples/grafana/minimal.yaml
```

### Step 4: Verify Deployment

```bash
# Check pod status
kubectl get pods -n acme-corp-observability

# Wait for Grafana pod to be Running
kubectl get pods -n acme-corp-observability -w

# Check service
kubectl get svc -n acme-corp-observability
```

Expected output:
```
NAME              READY   STATUS    RESTARTS   AGE
weaura-grafana-0   1/1     Running   0          2m

NAME              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)
weaura-grafana   ClusterIP   10.96.123.45   <none>        3000/TCP
```

### Step 5: Access Grafana UI

```bash
# Port-forward to localhost
kubectl port-forward -n acme-corp-observability svc/weaura-grafana 3000:80

# Open browser
open http://localhost:3000
```

Default credentials:
- Username: `admin`
- Password: `admin` (change on first login)

## Terraform Deployment (Standard Profile)

Deploy Grafana + Loki + Mimir stack using Terraform for full observability. Best for production deployments.

### Step 1: Initialize Terraform

```bash
cd apps/grafana/terraform/modules/grafana-oss/examples

terraform init -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=grafana/terraform.tfstate" \
  -backend-config="region=us-east-2" \
  -backend-config="dynamodb_table=terraform-locks"
```

Or use local state for testing:

```bash
terraform init -backend=false
```

### Step 2: Prepare Variables

Create or use existing `terraform.tfvars`:

```hcl
# Required variables
cloud_provider = "aws"
cluster_name   = "staging-us-east-2"
tenant_id      = "acme-corp"
tenant_name    = "ACME Corporation"

# Optional: Enable stack components
enable_grafana     = true
enable_loki        = true
enable_mimir       = true
enable_tempo       = false
enable_pyroscope   = false

# Optional: Branding
grafana_app_title = "ACME Observability"
grafana_logo_url  = "https://example.com/logo.png"

# Optional: Retention (hours)
retention_loki     = 720   # 30 days
retention_mimir    = 2160  # 90 days
```

Or use example profile:

```bash
terraform plan -var-file=../../../../examples/grafana/standard.tfvars
```

### Step 3: Plan & Review Changes

```bash
terraform plan -var-file=terraform.tfvars -out=tfplan
```

Review the execution plan. Expected: 30-40 resources created.

### Step 4: Apply Configuration

```bash
terraform apply tfplan
```

Monitor progress (~5-10 minutes). Terraform will:
- Create namespaces (acme-corp-observability)
- Deploy Grafana Helm chart
- Deploy Loki for log aggregation
- Deploy Mimir for metrics storage
- Configure IRSA (IAM Roles for Service Accounts) for S3 access
- Set up PersistentVolumeClaims and StorageClasses

### Step 5: Verify Terraform Deployment

```bash
# Check pods across all observability namespaces
kubectl get pods -n acme-corp-observability

# Check Helm releases
helm list -n acme-corp-observability

# Port-forward Grafana
kubectl port-forward -n acme-corp-observability svc/weaura-grafana 3000:80

# Open http://localhost:3000
```

### Step 6: Configure Datasources (Post-Deploy)

After accessing Grafana UI, add datasources for Loki and Mimir:

1. Go to **Configuration** → **Data Sources**
2. Click **Add data source**
3. Select **Prometheus** (for Mimir): URL: `http://mimir-distributor.acme-corp-observability:9009`
4. Select **Loki**: URL: `http://loki-distributor.acme-corp-observability:3100`

## Verification Checklist

After deployment, verify:

- [ ] **Grafana pod running**: `kubectl get pods -n acme-corp-observability | grep grafana`
- [ ] **Grafana service accessible**: `kubectl get svc -n acme-corp-observability`
- [ ] **Grafana UI loads**: `localhost:3000` responds
- [ ] **Login succeeds**: Can authenticate with admin account
- [ ] **Default dashboards visible**: **Dashboards** → **Browse** shows content-pack dashboards
- [ ] **Datasources configured** (Terraform only): **Configuration** → **Data Sources** shows Prometheus/Loki

## Troubleshooting

### Pod Stuck in "Pending"

**Symptom**: Pod never transitions to Running

**Causes & Solutions**:

1. **Insufficient resources**:
   ```bash
   # Check node capacity
   kubectl describe nodes
   
   # Check pod events
   kubectl describe pod weaura-grafana-0 -n acme-corp-observability
   ```
   **Fix**: Add nodes to cluster or reduce resource limits in values.yaml

2. **PVC not binding**:
   ```bash
   # Check PVC status
   kubectl get pvc -n acme-corp-observability
   
   # Check StorageClass
   kubectl get storageclass
   ```
   **Fix**: Ensure StorageClass exists: `kubectl get storageclass -o wide`

### Pod Stuck in "CrashLoopBackOff"

**Symptom**: Pod restarts repeatedly

**Diagnosis**:

```bash
# View logs
kubectl logs weaura-grafana-0 -n acme-corp-observability --tail=50

# View previous crash logs
kubectl logs weaura-grafana-0 -n acme-corp-observability --previous
```

**Common causes**:
- Database connection failure: Check PostgreSQL connectivity
- Invalid configuration: Check values.yaml for syntax errors
- Missing secrets: Verify SSO secrets are created (if SSO enabled)

### Cannot Access Grafana UI

**Symptom**: `localhost:3000` refuses connection or times out

**Solutions**:

1. **Check port-forward running**:
   ```bash
   # Should show active connection
   ps aux | grep port-forward
   ```

2. **Verify service exists**:
   ```bash
   kubectl get svc -n acme-corp-observability
   kubectl describe svc weaura-grafana -n acme-corp-observability
   ```

3. **Check pod logs**:
   ```bash
   kubectl logs weaura-grafana-0 -n acme-corp-observability
   ```

### SSO Login Fails (Google OAuth)

**Symptom**: SSO redirect fails or "Invalid client ID" error

**Solutions**:

1. **Verify secret exists**:
   ```bash
   kubectl get secret sso-google -n acme-corp-observability
   ```

2. **Check OAuth credentials**:
   ```bash
   # Verify in values.yaml
   grep -A 5 "sso:" apps/grafana/helm/weaura-grafana/values.yaml
   ```

3. **Verify redirect URI**:
   - In Google Cloud Console, ensure `https://your-grafana-domain/login/google/callback` is registered

### Missing Dashboards or Datasources

**Symptom**: Dashboards don't appear in UI or datasources show "no data"

**Solutions**:

1. **Enable dashboard provisioning**:
   ```bash
   # Check if dashboards ConfigMap exists
   kubectl get configmap -n acme-corp-observability | grep dashboard
   ```

2. **Restart Grafana pod**:
   ```bash
   kubectl delete pod weaura-grafana-0 -n acme-corp-observability
   ```

3. **Verify content-packs**:
   ```bash
   kubectl describe configmap weaura-grafana-dashboards -n acme-corp-observability
   ```

## Next Steps

- **Configure Grafana**: See [Configuration Guide](configuration.md) for all options
- **Customize Branding**: Update appTitle, logo, colors in values.yaml
- **Enable SSO**: Follow Google OAuth setup in [Configuration Guide](configuration.md#sso-google-oauth)
- **Upgrade Stack**: See [Upgrade Guide](upgrade-guide.md) for version updates
- **Review Examples**: Check `examples/grafana/` for complete deployment profiles
- **Enable Observability**: Deploy Loki/Mimir/Tempo for full observability stack

## Support Resources

- **Grafana Docs**: https://grafana.com/docs/grafana/latest/
- **Helm Chart Issues**: Check logs with `kubectl logs` and `helm get values`
- **Terraform Issues**: Run `terraform validate` and check `.terraform/` state
