# ⚠️ DEPRECATED

This directory (`helm-repo/`) is **DEPRECATED** and will be removed in a future release.

## What Changed?

The `.tgz` packages and `index.yaml` in this directory are **NO LONGER** the source of truth for WeAura charts.

## New Distribution Method

WeAura charts are now distributed via **Harbor OCI**:

```
oci://registry.dev.weaura.ai/weaura-vendorized/
```

## Installation

For installation instructions, see:

- **Portuguese:** `apps/grafana/docs/guia-cliente.md`
- **English:** `apps/grafana/docs/quickstart.md`

## Harbor Access

To access the Harbor OCI registry, contact **WeAura** for a Harbor robot account.

---

**Migration Timeline:** This directory will be removed in a future release. Migrate to Harbor OCI as soon as possible.
