# Grafana Upgrade Guide

Safe upgrade procedures for Helm and Terraform deployments with rollback strategies.

## Overview

WeAura-vendorized Grafana follows semantic versioning:
- **Major (1.0.0)**: Breaking changes, migration required
- **Minor (1.2.0)**: New features, backward compatible
- **Patch (1.2.1)**: Bug fixes, backward compatible

Always review [release notes](https://github.com/weauratech/weaura-vendorized-stack/releases) before upgrading.

## Version Compatibility Matrix

| Grafana OSS | Helm Chart | Docker Image | Kubernetes | Helm | Status |
|-------------|-----------|--------------|-----------|------|--------|
| 10.4.x      | 0.1.x     | 1.0.x        | 1.25+     | 3.12+| Current |
| 10.3.x      | 0.0.x     | 0.9.x        | 1.24+     | 3.10+| Legacy |
| 9.5.x       | N/A       | N/A          | N/A       | N/A  | Unsupported |

## Pre-Upgrade Checklist

Before upgrading, complete these steps:

```bash
# 1. Backup current state
kubectl get all -n acme-corp-observability -o yaml > backup-$(date +%s).yaml

# 2. Check current versions
helm list -n acme-corp-observability
kubectl get pods -n acme-corp-observability

# 3. Verify datasources and dashboards
curl http://localhost:3000/api/datasources  # Via port-forward

# 4. Document current values
helm get values weaura-grafana -n acme-corp-observability > current-values.yaml

# 5. Review release notes
# Go to: https://github.com/weauratech/weaura-vendorized-stack/releases
```

## Helm Upgrade Procedure

For Helm-based deployments (Minimal profile).

### Step 1: Update Helm Repository

```bash
# If using Helm repo
helm repo update weaura

# Or verify local chart updated
cd weaura-vendorized-stack
git pull origin main
```

### Step 2: Dry-Run Upgrade

Always test before applying:

```bash
helm upgrade weaura-grafana ./apps/grafana/helm/weaura-grafana/ \
  --namespace acme-corp-observability \
  --values examples/grafana/minimal.yaml \
  --dry-run \
  --debug > upgrade-plan.yaml

# Review what will change
cat upgrade-plan.yaml | less
```

### Step 3: Execute Upgrade

```bash
helm upgrade weaura-grafana ./apps/grafana/helm/weaura-grafana/ \
  --namespace acme-corp-observability \
  --values examples/grafana/minimal.yaml \
  --timeout 5m
```

Monitor the upgrade:

```bash
# Watch pod restart
kubectl get pods -n acme-corp-observability -w

# Check pod logs
kubectl logs -f weaura-grafana-0 -n acme-corp-observability

# Verify service endpoints
kubectl get svc -n acme-corp-observability
```

Expected behavior:
- Pod terminates
- New pod starts with new image
- Service redirects to new pod
- Data persists (stored in PVC)

### Step 4: Verify Post-Upgrade

```bash
# 1. Check pod health
kubectl get pods -n acme-corp-observability
# Expected: STATUS = Running, RESTARTS = 0

# 2. Check service
kubectl get svc -n acme-corp-observability

# 3. Access Grafana UI
kubectl port-forward -n acme-corp-observability svc/weaura-grafana 3000:80
open http://localhost:3000

# 4. Check Grafana version
# Go to Help (?) → About → Check version number

# 5. Verify dashboards
curl -s http://localhost:3000/api/search?query=* | jq '.[] | .title'

# 6. Verify datasources
curl -s http://localhost:3000/api/datasources | jq '.[] | .name'
```

### Rollback Helm Deployment

If upgrade fails:

```bash
# List recent revisions
helm history weaura-grafana -n acme-corp-observability

# Rollback to previous revision (usually 1)
helm rollback weaura-grafana 1 -n acme-corp-observability

# Verify rollback
kubectl get pods -n acme-corp-observability
kubectl logs weaura-grafana-0 -n acme-corp-observability
```

## Terraform Upgrade Procedure

For Terraform-based deployments (Standard/Full Stack profiles).

### Step 1: Update Terraform Modules

```bash
cd apps/grafana/terraform/modules/grafana-oss/examples

# Update module version in main.tf if using git source
git -C ../../ pull origin main
```

### Step 2: Check Terraform Plan

```bash
# Use existing variables
terraform plan -var-file=../../../../examples/grafana/standard.tfvars \
  -out=tfplan-upgrade
```

Review the plan. Expected changes:
- Helm chart version update (if chart version changed)
- Pod image tag update (if Grafana version changed)
- No changes to stateful resources (PVC, storage)

### Step 3: Apply Upgrade

```bash
terraform apply tfplan-upgrade
```

Monitor the upgrade:

```bash
# Watch Helm release update
helm list -n acme-corp-observability -w

# Check pods
kubectl get pods -n acme-corp-observability -w

# View logs
kubectl logs -f $(kubectl get pods -n acme-corp-observability -l app=grafana -o jsonpath='{.items[0].metadata.name}') -n acme-corp-observability
```

### Step 4: Verify Post-Upgrade

Same as Helm (see Helm Step 4).

### Rollback Terraform Deployment

If upgrade fails:

```bash
# Option 1: Revert to previous tfstate
terraform apply -var-file=../../../../examples/grafana/standard.tfvars \
  -target=helm_release.grafana \
  # Manually restore tfstate if automated rollback fails

# Option 2: Manual Helm rollback
helm rollback weaura-grafana 1 -n acme-corp-observability

# Option 3: Destroy and redeploy (worst case)
terraform destroy -var-file=../../../../examples/grafana/standard.tfvars
terraform apply -var-file=../../../../examples/grafana/standard.tfvars
```

## Breaking Changes & Migration Guides

### 0.x → 1.0 Migration (Grafana 10.4 → 11.x)

**Breaking Changes**:
- Plugin API changed (incompatible with 10.4 plugins)
- Dashboard schema version updated to 39
- Alerting rule format evolved

**Migration Steps**:

1. **Update Helm Chart**:
   ```yaml
   # values.yaml
   grafana:
     image:
       tag: "11.0.0"  # Updated from 10.4.0
   ```

2. **Validate Dashboards**:
   ```bash
   # Dashboards auto-upgrade on restart
   # But verify in UI for errors
   kubectl logs weaura-grafana-0 -n acme-corp-observability | grep -i "dashboard"
   ```

3. **Update Alert Rules** (if using):
   ```yaml
   # apps/grafana/content-packs/alerts/
   # Review YAML format changes in Grafana 11.x docs
   # Re-provision alert rules if syntax changed
   ```

4. **Test in Dev First**:
   ```bash
   # Always test major version upgrade in dev cluster
   # Full testing cycle: 1-2 days recommended
   ```

### Data Persistence During Upgrades

All WeAura components store data persistently:

- **Grafana**: PVC with 10Gi (survives pod restart)
- **Loki**: S3 backend (data in bucket)
- **Mimir**: S3 backend (data in bucket)
- **Tempo**: S3 backend (data in bucket)

**Data is never lost during upgrades** (pod restart only).

## Upgrade Troubleshooting

### Pod Stuck in "ImagePullBackOff"

**Symptom**: `kubectl describe pod` shows image pull error

**Solutions**:

```bash
# 1. Verify image exists
docker pull 950242546328.dkr.ecr.us-east-2.amazonaws.com/weaura-grafana:10.4.0

# 2. Check ECR credentials
kubectl get secret weaura-ecr-creds -n acme-corp-observability

# 3. Verify image tag in values
helm get values weaura-grafana -n acme-corp-observability | grep tag

# 4. Rollback to previous version
helm rollback weaura-grafana 1 -n acme-corp-observability
```

### Pod Stuck in "CrashLoopBackOff" After Upgrade

**Symptom**: Pod restarts continuously after upgrade

**Diagnosis**:

```bash
# Check logs
kubectl logs weaura-grafana-0 -n acme-corp-observability

# Common causes:
# 1. Database schema incompatibility
# 2. New required environment variables
# 3. Mounted volume permission issues
```

**Solutions**:

```bash
# 1. Check database
kubectl get pvc -n acme-corp-observability

# 2. Check environment variables
helm get values weaura-grafana -n acme-corp-observability

# 3. Rollback if unsure
helm rollback weaura-grafana 1 -n acme-corp-observability
```

### Datasources Show "No Data" After Upgrade

**Symptom**: Datasources configured but showing no data

**Solutions**:

```bash
# 1. Restart datasource connections
kubectl delete pod weaura-grafana-0 -n acme-corp-observability

# 2. Re-configure datasources in UI
# Go to Configuration → Data Sources → Test

# 3. Check network policies
kubectl get networkpolicies -n acme-corp-observability
kubectl describe networkpolicy grafana -n acme-corp-observability
```

## Upgrade Scheduling

Recommended upgrade schedule:

- **Patch versions** (10.4.0 → 10.4.1): Every 2 weeks, low risk
- **Minor versions** (10.4.0 → 10.5.0): Monthly, test in dev first
- **Major versions** (10.x → 11.x): Quarterly, full testing required

### Change Windows

- **Dev**: Upgrade anytime
- **Staging**: Tuesday-Thursday (not production hours)
- **Production**: Monthly maintenance window (e.g., first Saturday)

## Monitoring Upgrade Health

After upgrade, monitor for 24 hours:

```bash
# 1. Watch resource usage
kubectl top pods -n acme-corp-observability

# 2. Check for errors in logs
kubectl logs weaura-grafana-0 -n acme-corp-observability | grep -i error

# 3. Monitor datasource connectivity
# In Grafana UI: Configuration → Data Sources → check status

# 4. Set up alerts for pod restarts
# Alert if pod restarts > 5 times in 1 hour
```

## Automated Upgrade Best Practices

If using CI/CD for upgrades:

```bash
# 1. Automated testing
terraform plan -var-file=standard.tfvars -out=tfplan

# 2. Manual approval gate
# Require human approval before terraform apply

# 3. Automated rollback triggers
# Rollback if pod fails health checks for > 5 minutes

# 4. Post-upgrade validation
# Automated tests for datasources, dashboards, login
```

## Support & Escalation

If upgrade fails and rollback doesn't work:

1. **Immediate**: Restore from backup
   ```bash
   kubectl apply -f backup-*.yaml
   ```

2. **Contact Support**: GitHub issue or WeAura support
   - Include: Upgrade from/to versions, error logs, cluster info

3. **Restore from Backup**: PVC snapshots (AWS/Azure)
   ```bash
   # AWS EBS snapshot restore
   # Or restore from S3 backups (Loki/Mimir/Tempo)
   ```
