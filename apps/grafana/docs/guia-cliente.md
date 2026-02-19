# Guia do Cliente - WeAura Grafana Vendor

**Versão**: 0.2.0  
**Atualizado**: 16 Fev 2026

## Pré-requisitos

Antes de instalar o vendor Grafana, você precisa ter:

- **Kubernetes cluster** (versão 1.23+)
- **Helm 3** (versão 3.8+)
- **kubectl** configurado para seu cluster
- **Namespace** criado para a instalação
- **Harbor credentials** para acessar o registro de imagens WeAura (fornecidas pela equipe WeAura)

Verifique os requisitos:

```bash
# Verificar versão do Helm
helm version --short

# Verificar acesso ao cluster
kubectl cluster-info

# Verificar namespace (criar se não existir)
kubectl get namespace grafana || kubectl create namespace grafana
```

---

## Instalação Básica (5 minutos)

### Passo 1: Fazer login no registro Harbor

```bash
# Fazer login no Harbor (use credenciais fornecidas pela WeAura)
helm registry login registry.dev.weaura.ai
```

Quando solicitado:
- **Username**: (fornecido pela WeAura)
- **Password**: (fornecido pela WeAura)

### Passo 2: Criar arquivo de configuração mínimo

Crie um arquivo `values.yaml` com as configurações do seu tenant:

```yaml
# values.yaml
tenant:
  id: minha-empresa
  name: "Minha Empresa S.A."

branding:
  appTitle: "Minha Empresa - Observabilidade"
  appName: "Minha Empresa Grafana"
  loginTitle: "Bem-vindo ao Monitoramento"
  
  cssOverrides:
    primaryColor: "#0066CC"
    primaryColorHover: "#0052A3"
```

### Passo 3: Instalar o chart

```bash
helm install grafana oci://registry.dev.weaura.ai/weaura-vendorized/weaura-grafana \
  --namespace grafana \
  --values values.yaml \
  --version 0.2.0 \
  --wait
```

### Passo 4: Verificar a instalação

```bash
# Verificar status do pod
kubectl get pods -n grafana

# Aguardar pod ficar Running (3 containers)
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=grafana -n grafana --timeout=300s

# Verificar logs
kubectl logs -n grafana -l app.kubernetes.io/name=grafana --all-containers --tail=50
```

### Passo 5: Acessar o Grafana

```bash
# Port-forward para acesso local
kubectl port-forward -n grafana svc/grafana 3000:80

# Abra http://localhost:3000 no navegador
# Usuário padrão: admin
# Senha padrão: (veja o secret)
kubectl get secret -n grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

---

## Estrutura do Chart

O chart cria os seguintes componentes no seu cluster:

### Recursos Kubernetes Criados

| Recurso | Nome | Função |
|---------|------|--------|
| **Deployment** | `grafana` | Pod principal do Grafana (3 containers) |
| **Service** | `grafana` | Expõe Grafana na porta 80 |
| **Secret** | `grafana` | Credenciais admin |
| **ConfigMap** | `grafana-grafana-ini` | Configuração principal (branding, SSO) |
| **ConfigMap** | `grafana-datasources` | Datasources provisionados |
| **ConfigMap** | `grafana-dashboards` | Dashboards provisionados |
| **ConfigMap** | `grafana-alerting` | Regras de alerta |
| **ConfigMap** | `grafana-css-overrides` | CSS customizado |
| **PVC** (opcional) | `grafana` | Persistência de dados |

### Dashboards Incluídos

O vendor já vem com 4 dashboards pré-configurados:

1. **Kubernetes Overview** - Visão geral do cluster (nodes, pods, recursos)
2. **Application Overview** - Métricas de aplicações (requests, latência, erros)
3. **Loki Logs** - Visualização centralizada de logs
4. **Node Exporter** - Métricas detalhadas dos nodes (CPU, memória, disco, rede)

---

## Configurações Avançadas

### Persistência

Por padrão, o Grafana usa `emptyDir` (dados são perdidos ao reiniciar o pod). Para produção, habilite persistência:

```yaml
grafana:
  persistence:
    enabled: true
    storageClassName: gp3  # Ajuste para sua storage class
    size: 10Gi
    accessModes:
      - ReadWriteOnce
```

Verificar storage classes disponíveis:

```bash
kubectl get storageclass
```

### Datasources Adicionais

Adicione datasources além do Prometheus padrão:

```yaml
grafana:
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        # Prometheus (já incluído por padrão)
        - name: Prometheus
          type: prometheus
          access: proxy
          url: http://prometheus:9090
          isDefault: true
        
        # Loki para logs
        - name: Loki
          type: loki
          access: proxy
          url: http://loki:3100
        
        # CloudWatch (exemplo)
        - name: CloudWatch
          type: cloudwatch
          jsonData:
            authType: ec2_iam_role
            defaultRegion: us-east-1
```

### Ingress (Expor externamente)

Para expor o Grafana com um domínio público:

```yaml
grafana:
  ingress:
    enabled: true
    ingressClassName: nginx  # ou alb, traefik, etc
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - grafana.minha-empresa.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.minha-empresa.com
```

Não esqueça de configurar o DNS:

```bash
# Obter IP do Load Balancer
kubectl get ingress -n grafana grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Criar registro DNS A apontando para esse IP
# grafana.minha-empresa.com -> <IP_DO_LB>
```

### SSO com Google OAuth

Para autenticação via Google Workspace:

```yaml
branding:
  googleSSO:
    enabled: true
    clientId: "123456789-xxxxx.apps.googleusercontent.com"
    clientSecret: "GOCSPX-xxxxxxxxxxxxxx"  # Use Secret, não valores diretos
    allowedDomains: "minha-empresa.com"
```

**Importante**: Armazene `clientSecret` em um Secret Kubernetes:

```bash
# Criar secret
kubectl create secret generic grafana-sso \
  -n grafana \
  --from-literal=google-client-secret='GOCSPX-xxxxxx'

# Referenciar no values.yaml
branding:
  googleSSO:
    enabled: true
    clientId: "123456789-xxxxx.apps.googleusercontent.com"
    clientSecret:
      valueFrom:
        secretKeyRef:
          name: grafana-sso
          key: google-client-secret
    allowedDomains: "minha-empresa.com"
```

### Logo Customizado

Para usar o logo da sua empresa:

```yaml
branding:
  logoUrl: "https://cdn.minha-empresa.com/logo.svg"
  
  cssOverrides:
    logoWidth: "140px"
    logoHeight: "45px"
    loginLogoWidth: "220px"
    loginLogoHeight: "70px"
```

**Requisitos do logo**:
- Formato: SVG (recomendado) ou PNG
- Fundo transparente
- Dimensões sugeridas: 400x120px (proporção ~3:1)

---

## Operações Comuns

### Verificar Status

```bash
# Status do Helm release
helm status grafana -n grafana

# Status dos pods
kubectl get pods -n grafana -l app.kubernetes.io/name=grafana

# Logs em tempo real
kubectl logs -n grafana -l app.kubernetes.io/name=grafana --all-containers -f

# Health check
kubectl exec -n grafana deployment/grafana -- curl -s http://localhost:3000/api/health | jq
```

### Atualizar Configuração

```bash
# Editar values.yaml com novas configurações
vim values.yaml

# Aplicar mudanças (upgrade)
helm upgrade grafana oci://registry.dev.weaura.ai/weaura-vendorized/weaura-grafana \
  --namespace grafana \
  --values values.yaml \
  --version 0.2.0 \
  --wait

# Verificar se aplicou
kubectl rollout status deployment/grafana -n grafana
```

### Reiniciar Grafana

```bash
# Reiniciar pod (forçar novo deploy)
kubectl rollout restart deployment/grafana -n grafana

# Aguardar rollout completo
kubectl rollout status deployment/grafana -n grafana

# Verificar se voltou
kubectl get pods -n grafana -l app.kubernetes.io/name=grafana
```

### Desinstalar

```bash
# Desinstalar o chart (mantém PVC se existir)
helm uninstall grafana -n grafana

# Limpar PVC (CUIDADO: apaga dados permanentemente)
kubectl delete pvc -n grafana grafana

# Deletar namespace (remove tudo)
kubectl delete namespace grafana
```

---

## Solução de Problemas

### Pod não inicia (CrashLoopBackOff)

**Sintoma**: Pod reinicia continuamente

```bash
# Ver eventos
kubectl describe pod -n grafana -l app.kubernetes.io/name=grafana

# Ver logs do último crash
kubectl logs -n grafana -l app.kubernetes.io/name=grafana --previous --all-containers
```

**Causas comuns**:
- Configuração inválida no `grafana.ini` (verifique ConfigMap)
- Datasource com URL incorreta (verifique conectividade)
- Persistência com PVC em estado `Pending` (verifique storage class)

**Solução**:
```bash
# Verificar ConfigMaps
kubectl get configmap -n grafana

# Validar syntax do grafana.ini
kubectl get configmap grafana-grafana-ini -n grafana -o yaml

# Corrigir e fazer upgrade
helm upgrade grafana weaura/weaura-grafana -n grafana --values values.yaml
```

### Login não funciona (SSO)

**Sintoma**: Botão "Sign in with Google" não aparece ou dá erro

**Verificações**:

```bash
# Verificar configuração do SSO
kubectl get configmap grafana-grafana-ini -n grafana -o yaml | grep -A 10 "auth.google"

# Verificar secret (se usando)
kubectl get secret grafana-sso -n grafana -o jsonpath='{.data.google-client-secret}' | base64 --decode

# Logs do Grafana (procurar por "oauth" ou "google")
kubectl logs -n grafana -l app.kubernetes.io/name=grafana --all-containers | grep -i oauth
```

**Causas comuns**:
- `clientId` ou `clientSecret` incorretos
- Redirect URI não cadastrada no Google Console (deve ser `https://grafana.minha-empresa.com/login/google`)
- Domínio não está em `allowedDomains`

### Dashboards não aparecem

**Sintoma**: Dashboard list está vazia

**Verificações**:

```bash
# Verificar se ConfigMap de dashboards existe
kubectl get configmap -n grafana | grep dashboard

# Verificar label do ConfigMap (deve ter grafana_dashboard: "1")
kubectl get configmap grafana-dashboards -n grafana -o yaml | grep grafana_dashboard

# Verificar logs do sidecar
kubectl logs -n grafana -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard
```

**Solução**:
```bash
# Se label estiver faltando, adicione:
kubectl label configmap grafana-dashboards -n grafana grafana_dashboard=1

# Reiniciar para forçar reload
kubectl rollout restart deployment/grafana -n grafana
```

### Performance lenta

**Sintoma**: Grafana demora para carregar dashboards

**Diagnóstico**:

```bash
# Verificar uso de recursos
kubectl top pod -n grafana

# Verificar limits/requests
kubectl get deployment grafana -n grafana -o yaml | grep -A 5 resources

# Verificar queries lentas nos logs
kubectl logs -n grafana -l app.kubernetes.io/name=grafana --all-containers | grep "slow"
```

**Solução - Aumentar recursos**:

```yaml
grafana:
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 2Gi
```

### Erro "tenant.name" inválido

**Sintoma**: Erro ao criar ConfigMap: `metadata.labels: Invalid value`

**Causa**: `tenant.name` contém espaços ou caracteres especiais

**Solução**: `tenant.name` é movido para annotations automaticamente. Use `tenant.id` (sem espaços):

```yaml
tenant:
  id: minha-empresa      # Sem espaços, usado em labels
  name: "Minha Empresa"  # Com espaços OK, vai para annotations
```

### Prometheus datasource não conecta

**Sintoma**: Dashboard mostra "N/A" ou "No data"

**Verificações**:

```bash
# Testar conectividade do pod Grafana ao Prometheus
kubectl exec -n grafana deployment/grafana -- curl -s http://prometheus:9090/api/v1/status/config

# Verificar datasource provisionado
kubectl exec -n grafana deployment/grafana -- cat /etc/grafana/provisioning/datasources/datasource.yaml

# Ver logs do Grafana sobre datasources
kubectl logs -n grafana -l app.kubernetes.io/name=grafana --all-containers | grep -i datasource
```

**Solução**: Ajuste a URL do Prometheus no values.yaml:

```yaml
grafana:
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://prometheus-server.monitoring.svc.cluster.local:9090  # FQDN completo
          access: proxy
          isDefault: true
```

### Persistência não funciona

**Sintoma**: Dados perdidos após reiniciar pod

**Verificações**:

```bash
# Ver PVC
kubectl get pvc -n grafana

# Ver status do PVC
kubectl describe pvc grafana -n grafana

# Ver eventos do PVC
kubectl get events -n grafana --field-selector involvedObject.name=grafana --sort-by='.lastTimestamp'
```

**Causas comuns**:
- Storage class não suporta provisionamento dinâmico
- Permissões incorretas no volume
- PVC em estado `Pending` (sem storage provisioner)

**Solução**: Use storage class compatível ou configure provisionamento manual.

---

## Boas Práticas

### Segurança

1. **Nunca use senha padrão**: Troque a senha do admin imediatamente após instalar

```bash
# Trocar senha
kubectl exec -n grafana deployment/grafana -- grafana-cli admin reset-admin-password 'NovaSenhaForte123!'
```

2. **Use HTTPS em produção**: Sempre configure TLS no Ingress

3. **Rotacione secrets**: Secrets do SSO devem ser rotacionados periodicamente

4. **RBAC**: Configure permissões granulares por usuário/equipe

### Performance

1. **Datasource caching**: Habilite cache para queries repetitivas

```yaml
grafana:
  grafana.ini:
    caching:
      enabled: true
```

2. **Query timeout**: Ajuste timeout para queries longas

```yaml
grafana:
  grafana.ini:
    dataproxy:
      timeout: 90
```

3. **Resource limits**: Defina limits apropriados para seu uso

### Backup

1. **Backup do PVC**: Se usando persistência, faça snapshot do volume periodicamente

```bash
# Exemplo com Velero
velero backup create grafana-backup --include-namespaces grafana
```

2. **Export de dashboards**: Exporte dashboards via API

```bash
# Listar dashboards
curl -s http://admin:senha@localhost:3000/api/search?type=dash-db | jq

# Exportar dashboard específico
curl -s http://admin:senha@localhost:3000/api/dashboards/uid/kubernetes-overview | jq '.dashboard' > dashboard-backup.json
```

3. **Backup de configuração**: Versione seu `values.yaml` em Git

### Monitoramento

1. **Monitore o próprio Grafana**: Configure alertas para o pod Grafana

```yaml
# Exemplo de ServiceMonitor (se usando Prometheus Operator)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: grafana
  namespace: grafana
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: grafana
  endpoints:
    - port: service
      path: /metrics
```

2. **Logs centralizados**: Envie logs do Grafana para sistema de logs central (Loki, CloudWatch, etc)

3. **Health checks**: Configure probes adequados (já incluídos no chart)

---

## Checklist de Produção

Antes de colocar em produção, verifique:

- [ ] **Persistência habilitada** e testada (reinicie pod e verifique dados)
- [ ] **HTTPS configurado** com certificado válido
- [ ] **Senha do admin alterada** e armazenada em local seguro
- [ ] **SSO configurado** (se necessário) e testado
- [ ] **Backup configurado** para PVC e dashboards
- [ ] **Resource limits** apropriados definidos
- [ ] **Ingress funcionando** com DNS resolvendo corretamente
- [ ] **Datasources conectando** (teste queries em todos)
- [ ] **Dashboards carregando** corretamente
- [ ] **Alertas funcionando** (se configurados)
- [ ] **Monitoramento do Grafana** ativo (métricas sendo coletadas)
- [ ] **Documentação interna** criada com credenciais e runbooks
- [ ] **Equipe treinada** para operação básica

---

## Suporte

Para problemas técnicos ou dúvidas:

1. Verifique a documentação completa em `apps/grafana/docs/`
2. Consulte logs do Grafana: `kubectl logs -n grafana -l app.kubernetes.io/name=grafana --all-containers`
3. Entre em contato com o suporte WeAura

## Referências Úteis

- [Documentação oficial do Grafana](https://grafana.com/docs/grafana/latest/)
- [Helm Chart upstream](https://github.com/grafana/helm-charts/tree/main/charts/grafana)
- [Guia de provisionamento](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Troubleshooting oficial](https://grafana.com/docs/grafana/latest/troubleshooting/)
