# Runbook — Despliegue del stack LGTM en k3s-o11y

Guía operativa para desplegar y mantener los backends de observabilidad
(**L**oki, **G**rafana, **T**empo, **M**imir) en el cluster `k3s-o11y`, vía
Argo CD + Helm charts oficiales de Grafana. Todo el estado deseado vive en
este repo; Argo CD lo sincroniza con auto-sync (prune + selfHeal).

Estado verificado en vivo: 2026-10-03 (apps Synced/Healthy, 14 pods Running).

---

## 1. Arquitectura del despliegue

Cada componente es una **Application de Argo CD** con source de chart Helm y
values inline (`spec.source.helm.values`). La Application es autocontenida:
sin valueFiles externos ni dependencia de commits previos.

Los ingress **no** van en los values de los charts: viven como manifiestos
planos en `kubernetes/o11y/api-gateway-o11y/` y los sincroniza la Application
`api-gateway-o11y` (source git por path, patrón whoami).

```text
ansible/roles/k3s-argocd-apps/files/
├── lgtm/
│   ├── loki-app.yml       chart loki 7.3.0            (SingleBinary)
│   ├── grafana-app.yml    chart grafana 10.5.15       (datasources via provisioning)
│   ├── tempo-app.yml      chart tempo 1.24.4          (metrics-generator ON)
│   └── mimir-app.yml      chart mimir-distributed 6.2.0 (mínimo, sin zonas)
└── api-gateway-o11y-app.yml   source.path → kubernetes/o11y/api-gateway-o11y/

kubernetes/o11y/api-gateway-o11y/
├── grafana-ingress.yml    grafana.hq.kronops.io  → lgtm-grafana:80
├── loki-ingress.yml       loki.hq.kronops.io     → lgtm-loki:3100
├── tempo-ingress.yml      tempo.hq.kronops.io    → lgtm-tempo:4318 (OTLP HTTP)
└── mimir-ingress.yml      mimir.hq.kronops.io    → lgtm-mimir-gateway:8080
```

Convenciones comunes a las 5 Applications:

* `project: platform`, destino `https://10.101.165.15:6443` (k3s-o11y), namespace `monitoring`
* `syncPolicy.automated` con `prune: true` y `selfHeal: true`, `CreateNamespace=true`
* Labels `environment: o11y`, `owner: yorch`, `component: observability`
* Charts pineados por `targetRevision` (nunca `latest`)

## 2. Recursos del cluster

| Recurso | Valor |
| --- | --- |
| Nodo | VM Proxmox, Ubuntu 24.04, 4 vCPU, 6.8 Gi RAM, 79 GB disco |
| k3s | v1.36.4+k3s1, single-node, storageClass `local-path` |
| LB ingress | 10.101.165.160 (pool MetalLB `10.101.165.160-167`) |
| ClusterIssuer | `kronops-o11y-intermediate-ca1-issuer` |
| Consumo actual | 14 pods, ~30 Gi PVC, ~3 Gi RAM en requests |

PVCs por componente (todos `local-path`, sin S3 ni replication de datos):

| Componente | PVC | Tamaño |
| --- | --- | --- |
| Grafana | `lgtm-grafana` | 5 Gi |
| Loki | `storage-lgtm-loki-0` | 10 Gi |
| Tempo | `storage-lgtm-tempo-0` | 5 Gi |
| Mimir ingester | `storage-lgtm-mimir-ingester-0` | 5 Gi |
| Mimir store-gateway | `storage-lgtm-mimir-store-gateway-0` | 2 Gi |
| Mimir compactor | `storage-lgtm-mimir-compactor-0` | 2 Gi |
| Mimir alertmanager | `storage-lgtm-mimir-alertmanager-0` | 1 Gi |

## 3. Prerrequisitos

1. **Gateway del cluster**: `deploy-k3s-gateway.yml` corrido en o11y
   (MetalLB, ingress-nginx, cert-manager con el issuer, external-dns).
2. **Argo CD** instalado en `k3s-devops` (`deploy-k3s-argocd.yml`) con el
   cluster o11y registrado (`deploy-local-argocd-cli.yml`).
3. **AppProject `platform`** con `clusterResourceWhitelist` que incluya
   ClusterRole/ClusterRoleBinding, WebhookConfigurations y CRDs — los charts
   de Grafana y Mimir crean recursos cluster-scoped y sin whitelist el
   auto-sync se rinde tras 5 reintentos.
4. **Capacidad en el nodo**: verificar antes de agregar componentes
   (`free -h`, `df -h /`). Sin margen de disco, parar y pedir más disco.
5. **Secret de admin de Grafana** (ver sección 4).

> [!WARNING]
> external-dns está en CrashLoopBackOff (RFC2136 `bad authentication`, TSIG
> roto contra el DNS autoritativo). Los hosts existentes siguen resolviendo,
> pero **ningún host nuevo puede registrarse**: mientras no se arregle la
> credencial TSIG, un host nuevo requiere entrada manual en `/etc/hosts` del
> cliente. El smoke test con `curl --resolve` no depende de DNS.

## 4. Despliegue inicial

### 4.1 Secret de admin de Grafana

El password no vive en git (detect-secrets lo prohíbe). La Application lo
referencia con `envValueFrom.secretKeyRef` y el secret se crea imperativo en
el cluster o11y:

```bash
kubectl --context k3s-o11y -n monitoring create secret generic lgtm-grafana-admin \
  --from-literal=admin-password='<password del gestor de secretos>'
```

Si el secret no existe, el pod de Grafana queda en `CreateContainerConfigError`.

### 4.2 Registrar las Applications

Desde `ansible/` (corre en `k3s-devops`, que alcanza la API de Argo CD):

```bash
cd ansible
ansible-playbook --syntax-check deploy-k3s-argocd-apps.yml
ansible-playbook deploy-k3s-argocd-apps.yml -K
```

El role `k3s-argocd-apps` copia cada manifiesto a /tmp y hace `kubectl apply`
(patrón copy+apply por componente).

### 4.3 Orden de arranque

Argo CD sincroniza todo en paralelo; el orden acá es de **validación**
incremental, no de dependencia dura:

1. `lgtm-loki` — subir primero: es el datasource default de Grafana
2. `lgtm-grafana` — valida datasource Loki antes de abrir la UI a usuarios
3. `lgtm-tempo`
4. `lgtm-mimir` — el más lento (11 pods, validación de config en startup)
5. `api-gateway-o11y` — ingress; el path debe estar mergeado a `main` ANTES
   de registrar la app (una Application con `source.path` renderiza desde el
   remote: un path solo existente en un branch local deja la app vacía)

### 4.4 Verificar estado en Argo CD

Las Applications viven en el cluster **devops**, no en o11y:

```bash
kubectl --context k3s-devops get applications -n argocd
# Esperado: lgtm-grafana/loki/tempo/mimir y api-gateway-o11y Synced + Healthy
```

Recursos en el cluster destino:

```bash
kubectl --context k3s-o11y get pods,pvc -n monitoring
```

## 5. Smoke tests (verificados 2026-10-03)

Con `--resolve` se bypassa el resolver local y se prueba el camino completo
(DNS del autoritativo, cert TLS, ingress, service, pod):

```bash
LB=10.101.165.160   # kubectl --context k3s-o11y get svc -n ingress ingress-ingress-nginx-controller
```

### Grafana

```bash
curl -s --resolve grafana.hq.kronops.io:443:$LB https://grafana.hq.kronops.io/api/health
# {"database":"ok","version":"12.3.1",...}
```

Login en la UI con el user `admin` y el password del secret del punto 4.1.

### Loki

```bash
# El endpoint de labels responde 200 (los health NO están expuestos por diseño)
curl -s --resolve loki.hq.kronops.io:443:$LB https://loki.hq.kronops.io/loki/api/v1/labels
# {"status":"success"}

# Push de una línea (auth_enabled: false, single tenant)
MS=$(( $(date +%s) * 1000 ))
curl -s -o /dev/null -w "%{http_code}\n" \
  --resolve loki.hq.kronops.io:443:$LB \
  -X POST -H "Content-Type: application/json" \
  -d "{\"streams\":[{\"stream\":{\"job\":\"smoke\"},\"values\":[[\"${MS}000000\",\"linea de prueba\"]]}]}" \
  https://loki.hq.kronops.io/loki/api/v1/push
# 204

curl -s --resolve loki.hq.kronops.io:443:$LB \
  "https://loki.hq.kronops.io/loki/api/v1/query_range?query=%7Bjob%3D%22smoke%22%7D&limit=1"
# La línea aparece en el resultado
```

> [!NOTE]
> Un timestamp viejo da 400 `timestamp too old` (ventana de retención de
> 168h): igual confirma que el path llega al backend. `/api/health` devuelve
> 404 por diseño — el ingress del chart solo expone paths de push/query.

### Tempo (ingesta OTLP HTTP)

```bash
MS=$(( $(date +%s) * 1000 ))
TID=$(openssl rand -hex 16)    # IDs aleatorias: un hex fijo en el doc dispara detect-secrets
SID=$(openssl rand -hex 8)
printf '%s' \
  '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"smoke"}}]},' \
  '"scopeSpans":[{"scope":{"name":"smoke"},"spans":[{"traceId":"'$TID'",' \
  '"spanId":"'$SID'","name":"smoke","kind":1,"startTimeUnixNano":"%s000000",' \
  '"endTimeUnixNano":"%s500000"}]}]}' "$MS" "$MS" > /tmp/tempo-smoke.json

curl -s -o /dev/null -w "%{http_code}\n" \
  --resolve tempo.hq.kronops.io:443:$LB \
  -X POST -H "Content-Type: application/json" \
  -d @/tmp/tempo-smoke.json https://tempo.hq.kronops.io/v1/traces
# 200

# Verificar que la traza quedó almacenada (query interna desde el pod)
kubectl --context k3s-o11y -n monitoring exec lgtm-tempo-0 -- \
  wget -qO- http://localhost:3200/api/traces/$TID
```

> [!NOTE]
> El receiver 4318 solo acepta POST a `/v1/traces|metrics|logs`; un GET a `/`
> responde 404 **por diseño** y no es falla. Todos los valores de atributos
> deben ser `stringValue`; un int devuelve 400.

### Mimir (query y reglas)

```bash
# Readiness del gateway (en la raíz, NO en /prometheus/ready — ese path no está expuesto)
curl -s --resolve mimir.hq.kronops.io:443:$LB https://mimir.hq.kronops.io/ready
# OK

# API de query responde por el gateway
curl -s --resolve mimir.hq.kronops.io:443:$LB \
  "https://mimir.hq.kronops.io/prometheus/api/v1/query?query=up"
# {"status":"success",...}
```

Smoke completo de escritura→storage→query sin infra local, cargando una
regla al ruler y esperando un ciclo de evaluación:

```bash
cat > /tmp/smoke.rules <<'EOF'
groups:
  - name: smoke
    rules:
      - record: smoke_ingest_test
        expr: vector(42)
EOF

kubectl --context k3s-o11y -n monitoring port-forward deploy/lgtm-mimir-ruler 8080:8080 &
mimirtool rules load /tmp/smoke.rules --address=http://localhost:8080 --id=anonymous
# esperar ~1 min y query en Grafana (datasource Mimir): smoke_ingest_test
```

## 6. Flujo de cambios (day-2)

### Cambiar values de un componente

1. Editar el manifiesto en `ansible/roles/k3s-argocd-apps/files/lgtm/<comp>-app.yml`
2. PR → merge a `main` (Refs al issue; sin keywords de auto-cierre)
3. Re-correr `ansible-playbook deploy-k3s-argocd-apps.yml -K` (aplica la
   Application actualizada; el auto-sync de Argo CD hace el resto)
4. Verificar: `kubectl --context k3s-devops get app <nombre> -n argocd`

### Upgrade de versión de chart

1. `helm repo add grafana https://grafana.github.io/helm-charts && helm repo update`
2. `helm show values grafana/<chart> --version <nueva>` — revisar breaking changes
3. Cambiar `targetRevision` en el manifiesto, PR, merge, playbook
4. Seguir pods y logs durante el sync: los componentes stateful (loki, tempo,
   mimir ingester) recrean el pod; con `local-path` los datos persisten en PVC

### Agregar un host / ingress nuevo

1. Crear el manifiesto en `kubernetes/o11y/api-gateway-o11y/` con:
   * `secretName: <cert>  # pragma: allowlist secret` (detect-secrets)
   * annotation del issuer `kronops-o11y-intermediate-ca1-issuer`
   * buffers nginx 25m si es ingesta OTLP (`proxy-body-size`)
2. Merge a `main`; la app `api-gateway-o11y` (`targetRevision: HEAD`) lo
   sincroniza en el siguiente refresh (~3 min)
3. Con external-dns caído: entrada manual en `/etc/hosts` del cliente

### Migrar un ingress de helm values a git

Para reusar un cert ya emitido (cert-manager no re-emite, cero downtime):
mantener el MISMO `secretName`, usar nombre de Ingress NUEVO (evita conflicto
de ownership con el release de Helm) y dejar que Argo CD prunee el viejo
cuando los values dejen de renderizarlo.

## 7. Limitaciones conocidas

| Limitación | Detalle |
| --- | --- |
| Ruler de Mimir sin PVC | Corre como Deployment con `emptyDir`: las reglas cargadas vía API se pierden en un restart del pod |
| Storage filesystem, RF=1 | Sin durability ante pérdida del disco; perfil de laboratorio |
| external-dns caído | CrashLoopBackOff por TSIG inválida; hosts nuevos no se registran |
| Mimir sin zonas | `zoneAwareReplication` y `rollout_operator` off: 1 réplica/componente, sin HA real |
| Limits de ingesta Mimir | 200k series por usuario, 25k samples/s — homelab only |

## 8. Troubleshooting

**App `OutOfSync` perpetuo tras editar values** — el auto-sync marcó la revisión como
"will not retry" tras 5 fallos. El annotate refresh NO re-habilita el sync; hay que
forzar la operación:

```bash
kubectl --context k3s-devops patch application <name> -n argocd --type=merge \
  -p '{"operation":{"sync":{"prune":true,"syncOptions":["Prune=true"]}}}'
```

**Sync falla con "is not permitted in project"** — el chart crea recursos cluster-scoped
fuera de la whitelist del AppProject `platform`. Ampliar `clusterResourceWhitelist` en
`roles/k3s-argocd/templates/argocd_project.yml.j2`, re-aplicar y forzar sync (comando arriba).

**Pod de Mimir crash con `error validating config:`** — validación dura del binario en
startup, no la cubre el dry-run. Leer el log del pod, corregir `structuredConfig` en el
manifiesto, PR, playbook. Trampas conocidas del schema 3.x: `push_grpc_method_enabled`,
`rule_path` (no `rule_dir`), dirs de storage que no deben solaparse.

**Pod de Grafana en `CreateContainerConfigError`** — falta el secret `lgtm-grafana-admin`
(sección 4.1).

**Loki 400 `no org id` desde el datasource** — `auth_enabled: true` (default del chart).
Ya está en false en los values.

**Datasource Tempo con `http2: frame too large`** — bug del plugin gRPC en Grafana contra
el puerto HTTP. `httpMethod: POST` en el `jsonData` (ya está).

**OTLP POST rechazado con 413** — batch OTLP excede el body size default de nginx (1m).
Annotations `proxy-body-size`/`client-body-buffer-size` de 25m en el ingress (tempo trae).

**Ingress nuevo no resuelve por DNS** — external-dns en CrashLoop (TSIG). `/etc/hosts`
temporal + smoke con `curl --resolve`; fix raíz: regenerar la credencial TSIG.

**POST vacío a un ingest responde 400/415** — **no es falla**: el request LLEGÓ al
backend. 4xx con payload inválido en un ingest endpoint = camino sano; 000/timeout sí
es falla.

**Recursos viejos siguen vivos tras corregir values** — el auto-sync sin prune no borra
lo que el chart dejó de renderizar. Sync con `Prune=true` y verificar en
`status.resources` de la Application.

**Datasource residual que no se borra desde la UI** — la API de Grafana con basic auth
devuelve 403 CSRF. Vía GitOps: `deleteDatasources` en el provisioning.

## 9. Referencias

* Arquitectura general: `docs/o11y-arquitecture.md`
* Runbook del OTel Demo (consume estos backends): `docs/o11y-otel-demo-runbook.md`
* Manifiestos: `ansible/roles/k3s-argocd-apps/files/lgtm/`, `kubernetes/o11y/api-gateway-o11y/`
* Charts: [grafana](https://github.com/grafana/helm-charts/tree/main/charts/grafana),
  [loki](https://github.com/grafana/helm-charts/tree/main/charts/loki),
  [tempo](https://github.com/grafana/helm-charts/tree/main/charts/tempo),
  [mimir-distributed](https://github.com/grafana/helm-charts/tree/main/charts/mimir-distributed)
