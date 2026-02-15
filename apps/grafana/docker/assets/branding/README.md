# Grafana OSS Branding System Documentation

## 1. Overview

The WeAura Grafana branding system is a **3-layer approach** designed to maximize customization within the constraints of Grafana OSS (Open Source Software). Since Grafana OSS lacks white-labeling features available only in Enterprise, this system combines configuration, CSS variables, and runtime modifications to achieve comprehensive branding.

### Why 3 Layers?

| Layer | Purpose | Limitation | Workaround |
|-------|---------|-----------|-----------|
| **Layer 1: grafana.ini** | App title, SSO, root URL, login text | Only supports text fields and URLs | Configuration only |
| **Layer 2: CSS Variables** | Colors, sizing, typography | Limited to CSS properties | CSS overrides mounted as custom.css |
| **Layer 3: Init Container** | Logo file replacement, favicon | OSS doesn't support file-based logos | Download and replace files before startup |

### Grafana OSS Constraints

- ❌ No custom login background images (Enterprise feature)
- ❌ No file-based logo configuration (only URL support)
- ❌ No hardcoded UI text changes beyond title/name
- ❌ No favicon configuration via grafana.ini
- ✅ Text branding via config (app title, login title)
- ✅ CSS variable overrides (colors, sizing)
- ✅ Runtime file replacement via init containers

---

## 2. Layer 1: grafana.ini Configuration

This layer controls application-level branding through Grafana configuration. All values are passed via ConfigMap mounted to `/etc/grafana/grafana.ini`.

### Configurable Fields

| Config Key | Scope | Type | Description | Example |
|-----------|-------|------|-------------|---------|
| `[server].root_url` | Server | URL | Root URL for all Grafana URLs and redirects | `https://grafana.clientco.com` |
| `[branding].app_title` | UI | String | Application title (browser tab) | `ClientCo Observability` |
| `[branding].app_name` | UI | String | Short app name (navbar, emails) | `ClientCo Grafana` |
| `[branding].login_title` | Login | String | Welcome message on login page | `Welcome to ClientCo Monitoring` |
| `[branding].login_logo` | Login | URL | Logo URL for login page (NOT file path) | `https://cdn.clientco.com/logo.svg` |
| `[auth.google].client_id` | SSO | String | Google OAuth client ID (optional) | `...gserviceaccount.com` |
| `[auth.google].client_secret` | SSO | String | Google OAuth secret (from Secret) | `...-XXXXX` |
| `[auth.google].allowed_domains` | SSO | CSV | Allowed email domains | `clientco.com,partner.com` |

### Example grafana.ini Snippet

```ini
[server]
root_url = https://grafana.clientco.com

[branding]
app_title = ClientCo Observability
app_name = ClientCo Grafana
login_title = Welcome to ClientCo Monitoring
login_logo = https://cdn.clientco.com/logo.svg

[auth.google]
enabled = true
client_id = <CLIENT_ID>.apps.googleusercontent.com
client_secret = <SECRET>
allowed_domains = clientco.com
```

### Helm Values Mapping

```yaml
grafana:
  # Core branding
  adminUser: admin
  adminPassword: <SECRET>
  
  # Branding config
  grafanaIni:
    server:
      root_url: "https://grafana.{{ .Values.domain }}"
    branding:
      app_title: "{{ .Values.branding.appTitle }}"
      app_name: "{{ .Values.branding.appName }}"
      login_title: "{{ .Values.branding.loginTitle }}"
      login_logo: "{{ .Values.branding.logoUrl }}"
    auth.google:
      enabled: "{{ .Values.branding.googleSSO.enabled }}"
      client_id: "{{ .Values.branding.googleSSO.clientId }}"
      client_secret: "{{ .Values.branding.googleSSO.clientSecret }}"
      allowed_domains: "{{ .Values.branding.googleSSO.allowedDomains }}"
```

---

## 3. Layer 2: CSS Variables and Overrides

This layer provides visual customization through CSS variables. The `custom.css` file is mounted into the Grafana container and loaded via `[paths].custom_static` configuration, allowing runtime style changes without rebuilding the Grafana image.

### CSS Variables

| Variable | Scope | Default | Purpose | Example |
|----------|-------|---------|---------|---------|
| `--primary-color` | Global | `#FF6B35` | Primary brand color for buttons, links | `#FF6B35` |
| `--primary-color-hover` | Global | `#E55A2A` | Hover state for primary elements | `#E55A2A` |
| `--logo-width` | Navbar | `120px` | Width of navbar logo | `150px` |
| `--logo-height` | Navbar | `40px` | Height of navbar logo | `50px` |
| `--login-background-color` | Login | `#1A1A2E` | Login page background (OSS limitation) | `#0F0F1E` |
| `--login-logo-width` | Login | `200px` | Login page logo width | `250px` |
| `--login-logo-height` | Login | `60px` | Login page logo height | `75px` |
| `--font-family-sans-serif` | Global | System fonts | Default font family for UI | `'Inter', sans-serif` |

### Selectors Provided

- `.btn-primary` — Primary action buttons
- `.btn-primary:hover` — Button hover state
- `a` — Link color
- `.sidemenu__logo img` — Navbar logo sizing
- `.login-page` — Login page container styling
- `.login__logo img` — Login page logo sizing

### Customization via Helm Values

Override CSS variables through Helm ConfigMap:

```yaml
branding:
  cssOverrides:
    primaryColor: "#FF6B35"
    primaryColorHover: "#E55A2A"
    logoWidth: "120px"
    logoHeight: "40px"
    loginBackgroundColor: "#1A1A2E"
    loginLogoWidth: "200px"
    loginLogoHeight: "60px"
    fontFamilySansSerif: "-apple-system, BlinkMacSystemFont, 'Segoe UI'"
```

### Helm Template Pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-custom-css
data:
  custom.css: |
    :root {
      --primary-color: {{ .Values.branding.cssOverrides.primaryColor }};
      --primary-color-hover: {{ .Values.branding.cssOverrides.primaryColorHover }};
      --logo-width: {{ .Values.branding.cssOverrides.logoWidth }};
      --logo-height: {{ .Values.branding.cssOverrides.logoHeight }};
      --login-background-color: {{ .Values.branding.cssOverrides.loginBackgroundColor }};
      --login-logo-width: {{ .Values.branding.cssOverrides.loginLogoWidth }};
      --login-logo-height: {{ .Values.branding.cssOverrides.loginLogoHeight }};
    }
    
    .btn-primary {
      background-color: var(--primary-color) !important;
      border-color: var(--primary-color) !important;
    }
    
    .btn-primary:hover {
      background-color: var(--primary-color-hover) !important;
      border-color: var(--primary-color-hover) !important;
    }
```

---

## 4. Layer 3: Init Container Logo Replacement

### Why This Layer Exists

Grafana OSS `[branding].login_logo` only accepts **URLs**, not file paths. For logo files stored in private artifact repositories or for favicon replacement, an init container downloads and replaces the SVG files before Grafana starts.

### When Used

Conditional initialization:
- If `branding.logoUrl` is provided AND points to an artifact (not already a URL in use)
- Before Grafana pod initialization
- Run once per pod startup

### How It Works

1. **Download Phase**: Init container fetches logo from `branding.logoUrl`
2. **Replacement Phase**: Places logo at `/usr/share/grafana/public/img/grafana_icon.svg`
3. **Startup Phase**: Grafana container starts and serves the custom logo

### Script Location and Implementation

The script `apps/grafana/docker/scripts/apply-branding.sh` handles:
- Downloading logo from URL with retry logic
- Validating SVG format
- Replacing default Grafana SVG
- Handling errors gracefully

*Note: Script creation is Task 4b. This documentation defines the pattern.*

### Helm Template Pattern (Conditional InitContainer)

```yaml
spec:
  initContainers:
    {{- if .Values.branding.logoUrl }}
    - name: apply-branding
      image: curlimages/curl:latest
      command:
        - /bin/sh
        - -c
        - |
          set -e
          echo "Downloading logo from {{ .Values.branding.logoUrl }}"
          curl -fsSL -o /branding-output/logo.svg "{{ .Values.branding.logoUrl }}"
          echo "Logo downloaded successfully"
      volumeMounts:
        - name: grafana-storage
          mountPath: /branding-output
    {{- end }}
  containers:
    - name: grafana
      image: grafana/grafana:latest
      volumeMounts:
        - name: grafana-storage
          mountPath: /usr/share/grafana/public/img
  volumes:
    - name: grafana-storage
      emptyDir: {}
```

### Environment Variables for Init Container

```yaml
initContainers:
  - name: apply-branding
    env:
      - name: LOGO_URL
        value: "{{ .Values.branding.logoUrl }}"
      - name: LOGO_PATH
        value: "/usr/share/grafana/public/img/grafana_icon.svg"
      - name: RETRY_COUNT
        value: "3"
      - name: RETRY_DELAY
        value: "5"
```

---

## 5. OSS Limitations

### What Can't Be Done (Enterprise Only)

| Feature | Reason | Workaround |
|---------|--------|-----------|
| Custom login background image | Enterprise-only feature | Use CSS `--login-background-color` for solid color |
| White-labeled footer | Hardcoded in OSS source | None; use app_title prominently |
| Custom favicon | No config support | Use init container to replace SVG (Layer 3) |
| Email template branding | Hardcoded in source | None; limited to app_name in emails |
| Custom login form layout | UI hardcoded | CSS overrides for colors/sizing only |
| Removing Grafana branding | Hardcoded in source | Not possible in OSS |

### What Can Be Done

| Feature | Supported Via | Notes |
|---------|---------------|-------|
| App title (browser tab) | Layer 1: `[branding].app_title` | Yes, configurable |
| App name (navbar, emails) | Layer 1: `[branding].app_name` | Yes, configurable |
| Login page title | Layer 1: `[branding].login_title` | Yes, configurable |
| Logo on login page | Layer 1: `[branding].login_logo` + Layer 3 init | URL or file via init container |
| Primary color | Layer 2: `--primary-color` CSS var | Yes, all buttons/links |
| Logo sizing | Layer 2: `--logo-width`, `--logo-height` | Yes, navbar and login page |
| Login page background | Layer 2: `--login-background-color` | Solid color only (no images) |

### Validation: Audit What's Branded

```bash
# Check what's branded in logs
kubectl logs -f deployment/grafana | grep -i "title\|brand"

# Verify CSS loaded
kubectl exec -it pod/grafana-XXX -- curl http://localhost:3000/build/custom.css | head -20
```

---

## 6. Usage Examples

### Complete Helm values.yaml Example

```yaml
domain: clientco.com

branding:
  # Layer 1: Text Branding
  appTitle: "ClientCo Observability Platform"
  appName: "ClientCo Grafana"
  loginTitle: "Welcome to ClientCo Monitoring"
  
  # Layer 1: Logo URL (can be external CDN or result of Layer 3 init container)
  logoUrl: "https://cdn.clientco.com/assets/logo.svg"
  
  # Layer 2: CSS Variables
  cssOverrides:
    primaryColor: "#FF6B35"
    primaryColorHover: "#E55A2A"
    logoWidth: "120px"
    logoHeight: "40px"
    loginBackgroundColor: "#1A1A2E"
    loginLogoWidth: "200px"
    loginLogoHeight: "60px"
    fontFamilySansSerif: "-apple-system, BlinkMacSystemFont, 'Segoe UI'"
  
  # Layer 3: Logo File (if using init container)
  logoSource: "gs://my-artifacts/logos/clientco-logo.svg"
  
  # SSO (Optional: Google OAuth)
  googleSSO:
    enabled: true
    clientId: "{{ lookup .GOOGLE_CLIENT_ID }}"
    clientSecret: "{{ lookup .GOOGLE_CLIENT_SECRET }}"
    allowedDomains: "clientco.com,trusted-partner.com"

grafana:
  adminUser: admin
  adminPassword: "{{ .Values.grafanaPassword }}"
  
  # Grafana configuration
  grafanaIni:
    server:
      root_url: "https://grafana.{{ .Values.domain }}"
      serve_from_sub_path: "false"
    
    branding:
      app_title: "{{ .Values.branding.appTitle }}"
      app_name: "{{ .Values.branding.appName }}"
      login_title: "{{ .Values.branding.loginTitle }}"
      login_logo: "{{ .Values.branding.logoUrl }}"
    
    auth.google:
      enabled: "{{ .Values.branding.googleSSO.enabled }}"
      client_id: "{{ .Values.branding.googleSSO.clientId }}"
      client_secret: "{{ .Values.branding.googleSSO.clientSecret }}"
      allowed_domains: "{{ .Values.branding.googleSSO.allowedDomains }}"
```

### Minimal Configuration (Text Only)

```yaml
branding:
  appTitle: "My Observability"
  appName: "My Grafana"
  loginTitle: "Welcome"
  logoUrl: ""  # Empty = use default Grafana logo
  
  cssOverrides:
    primaryColor: "#4CAF50"  # Green
    primaryColorHover: "#45a049"
```

### Full Customization (All 3 Layers)

```yaml
branding:
  # Layer 1: Text + URL
  appTitle: "TechCorp Cloud Monitoring"
  appName: "TechCorp Grafana"
  loginTitle: "TechCorp Cloud Intelligence"
  logoUrl: "https://cdn.techcorp.io/logo.svg"
  
  # Layer 2: CSS
  cssOverrides:
    primaryColor: "#1E88E5"
    primaryColorHover: "#1565C0"
    logoWidth: "140px"
    logoHeight: "44px"
    loginBackgroundColor: "#0D47A1"
    loginLogoWidth: "220px"
    loginLogoHeight: "66px"
  
  # Layer 3: Logo replacement (if using artifact storage)
  logoSource: "gs://techcorp-artifacts/grafana/logo-large.svg"
  
  # SSO
  googleSSO:
    enabled: true
    clientId: "12345...apps.googleusercontent.com"
    clientSecret: "<SECRET>"
    allowedDomains: "techcorp.io"
```

---

## 7. Integration Notes

### How Layers Mount in Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
spec:
  template:
    spec:
      # Init container for Layer 3 (logo replacement)
      initContainers:
        - name: apply-branding
          image: curlimages/curl:latest
          # Runs before Grafana starts, downloads and replaces logo SVG
          volumeMounts:
            - name: grafana-public
              mountPath: /usr/share/grafana/public
      
      containers:
        - name: grafana
          image: grafana/grafana:11.0.0
          
          # Layer 1: grafana.ini configuration
          volumeMounts:
            - name: grafana-config
              mountPath: /etc/grafana/grafana.ini
              subPath: grafana.ini
            
            # Layer 2: CSS overrides
            - name: grafana-css
              mountPath: /usr/share/grafana/public/build/custom.css
              subPath: custom.css
            
            # Layer 3: Logo (created by init container)
            - name: grafana-public
              mountPath: /usr/share/grafana/public
      
      volumes:
        # Layer 1: grafana.ini ConfigMap
        - name: grafana-config
          configMap:
            name: grafana-config
        
        # Layer 2: custom.css ConfigMap
        - name: grafana-css
          configMap:
            name: grafana-custom-css
        
        # Layer 3: Shared volume for logo
        - name: grafana-public
          emptyDir: {}
```

### Deployment Order

1. **Start phase**: Kubernetes creates Pod
2. **Init container phase** (Layer 3): Logo downloaded and placed in shared volume
3. **Container startup** (Layers 1 & 2): 
   - grafana.ini loaded from ConfigMap → sets text branding + SSO
   - custom.css loaded from ConfigMap → CSS variables applied
   - Grafana serves with all three layers active

### Configuration Reloading

| Layer | Reload Behavior | How to Update |
|-------|-----------------|---------------|
| Layer 1 (grafana.ini) | Requires pod restart | Update ConfigMap, restart deployment |
| Layer 2 (custom.css) | Browser cache | Update ConfigMap, clear browser cache + reload |
| Layer 3 (Logo) | Requires pod restart | Update ConfigMap for init container, restart deployment |

### Helm Chart Structure

```
charts/grafana/
├── values.yaml                    # Main branding configuration
├── templates/
│   ├── deployment.yaml            # Pod spec with init containers
│   ├── configmap-config.yaml      # grafana.ini (Layer 1)
│   ├── configmap-css.yaml         # custom.css (Layer 2)
│   └── secret-sso.yaml            # SSO credentials
└── apps/grafana/docker/
    └── assets/branding/
        ├── custom.css             # CSS variables
        ├── apply-branding.sh      # Init container script
        └── README.md              # This documentation
```

---

## Verification Checklist

- [ ] Layer 1: Open Grafana UI, verify browser tab title and login page text
- [ ] Layer 2: Inspect CSS in browser DevTools, verify variables applied
- [ ] Layer 3 (if using): Verify logo SVG downloaded via init container logs
- [ ] SSO: Confirm Google login works and domains are restricted
- [ ] Responsive: Test branding on mobile (logo sizing should scale)

## References

- [Grafana Official Branding Docs](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/#branding)
- [Grafana Configuration Reference](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
- VolkovLabs Branding Example: https://volkovlabs.io/
