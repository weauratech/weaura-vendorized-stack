# Grafana Content Packs: Learnings

## Dashboard Design Patterns

### Datasource Variable Pattern
- **CRITICAL**: Use `${DS_PROMETHEUS}`, `${DS_LOKI}`, `${DS_MIMIR}` variables instead of hardcoded UIDs
- Define datasource variables in `templating.list` with `type: "datasource"`
- Benefits: Portable across Grafana instances, easier provisioning

### Dashboard Structure Best Practices
- Keep panels count low: 6-8 panels max for clarity
- Use stat panels for KPIs (single value metrics)
- Use timeseries for trends over time
- Use table panels for detailed multi-dimensional data
- Use logs panels for Loki datasources

### Tagging Convention
- All default dashboards tagged with `"weaura-default"`
- Enables bulk management and filtering
- Tag appears in dashboard JSON at root level: `"tags": ["weaura-default"]`

## Alert Rule Patterns

### Grafana Alerting Provisioning Format
- YAML-based, not JSON
- Use `apiVersion: 1` for provisioning format
- Structure: groups → rules
- Each rule needs: uid, title, condition, data, for, annotations, labels

### Alert Expression Pattern (Multi-Step)
- **Step A**: Query datasource (Prometheus/Loki)
- **Step B**: Reduce to single value (`type: reduce`)
- **Step C**: Threshold check (`type: threshold`)
- Condition references final step (typically `C`)

### Datasource References in Alerts
- Use `datasourceUid: ${DS_PROMETHEUS}` for Prometheus queries
- Use `datasourceUid: __expr__` for expression steps (reduce, threshold)

### Configurable Thresholds
- Threshold values (80 for CPU, 85 for disk, 5 for error rate) are inline
- Can be parameterized via Helm values by templating the YAML before provisioning
- Example: `{{ .Values.alerts.cpuThreshold | default 80 }}`

## Gotchas & Pitfalls

### Dashboard JSON Gotchas
1. **UID vs datasourceUid**: Dashboard panels use nested `datasource` object with `uid` field
2. **Null ID**: Dashboard `id` must be `null` for provisioning (Grafana assigns on import)
3. **Schema Version**: Using `schemaVersion: 38` (Grafana 10.x compatible)
4. **Variable Syntax**: `${VAR_NAME}` in queries, not `$VAR_NAME`

### Alert Rule Gotchas
1. **Expression Datasource**: Must use `__expr__` UID for reduce/threshold steps
2. **Condition Field**: Must reference the final expression step (usually `C`)
3. **For Duration**: `for: 5m` prevents flapping, but delays firing
4. **NoDataState**: Use `OK` for metrics that may not exist, `NoData` for critical metrics

## Validation Commands

```bash
# Validate all JSONs
for f in apps/grafana/content-packs/dashboards/*.json; do
  python3 -m json.tool < "$f" > /dev/null && echo "✓ $f" || echo "✗ $f"
done

# Check for hardcoded UIDs (should return nothing or only DS_ variables)
grep -r '"uid"' apps/grafana/content-packs/dashboards/ | grep -v 'DS_' | grep -v 'grafana' | grep -v 'weaura-'

# Verify datasource variable usage
grep '"datasource"' apps/grafana/content-packs/dashboards/*.json | head -10

# Count tagged dashboards
grep -l "weaura-default" apps/grafana/content-packs/dashboards/*.json | wc -l
```

## Metric Naming Conventions Observed

### Kubernetes (kube-state-metrics)
- `kube_pod_info` - Pod metadata
- `kube_pod_status_phase` - Pod lifecycle state
- `kube_pod_container_status_waiting_reason` - Container wait reasons
- `kube_deployment_created` - Deployment metadata
- `kube_service_info` - Service metadata

### Node Exporter
- `node_cpu_seconds_total{mode="idle"}` - CPU idle time
- `node_memory_MemAvailable_bytes` - Available memory
- `node_filesystem_avail_bytes` - Filesystem free space
- `node_network_receive_bytes_total` - Network RX
- `node_load1`, `node_load5`, `node_load15` - System load averages

### Container Metrics (cAdvisor)
- `container_cpu_usage_seconds_total` - Container CPU usage
- `container_memory_usage_bytes` - Container memory usage

### Application Metrics (RED Method)
- `http_requests_total` - Request counter (labels: method, status_code)
- `http_request_duration_seconds_bucket` - Request latency histogram

## Next Steps for Integration
- Create Helm chart ConfigMaps from these JSON/YAML files
- Wire up `dashboardProviders` in Grafana values
- Define `${DS_*}` variable mappings in Helm values
- Test provisioning in dev cluster
