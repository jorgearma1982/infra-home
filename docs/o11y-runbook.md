# Runbook — Despliegue del OpenTelemetry Demo en k3s-prod

Guía paso a paso para desplegar el demo OTel (Astronomy Shop) en el cluster
`k3s-prod` y verificar su telemetría de punta a punta. Escrita para ejecutarse en
una sesión de lab de ~20 minutos.

**Requisitos previos:**

* `kubectl` y `helm` instalados y con acceso a `k3s-prod` (`kubectl config get-contexts`)
* Los backends de o11y (Tempo, Loki, Mimir, Grafana) desplegados y accesibles en
  `k3s-o11y` — ver `docs/o11y-arquitecture.md`
* DNS de la LAN resolviendo `*.hq.kronops.io`

---

## 1. Preparar el repositorio de Helm

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm search repo open-telemetry/opentelemetry-demo --versions | head -5
```

Verifica que la versión del chart es la **0.42.0** (app 3.1.0), que es la validada
para este lab.

## 2. Crear el archivo de values

Crea `otel-demo-values.yaml`:

```yaml
default:
  replicas: 1
  revisionHistoryLimit: 2

serviceAccount:
  create: true

components:
  # --- Servicios core de la tienda ---
  accounting:
    enabled: true
    resources: { limits: { memory: 160Mi }, requests: { memory: 100Mi } }
  cart:
    enabled: true
    resources: { limits: { memory: 64Mi }, requests: { memory: 40Mi } }
  checkout:
    enabled: true
    resources: { limits: { memory: 20Mi }, requests: { memory: 15Mi } }
  currency:
    enabled: true
    resources: { limits: { memory: 20Mi }, requests: { memory: 15Mi } }
  email:
    enabled: true
    resources: { limits: { memory: 48Mi }, requests: { memory: 32Mi } }
  fraud-detection:
    enabled: true
    resources: { limits: { memory: 200Mi }, requests: { memory: 128Mi } }
  frontend:
    enabled: true
    resources: { limits: { memory: 128Mi }, requests: { memory: 80Mi } }
    ingress:
      enabled: true
      ingressClassName: nginx
      hosts:
        - host: otel-demo.hq.kronops.io
          paths:
            - path: /
              pathType: Prefix
              port: 8080
      tls: []
  image-provider:
    enabled: true
    resources: { limits: { memory: 64Mi }, requests: { memory: 40Mi } }
  payment:
    enabled: true
    resources: { limits: { memory: 64Mi }, requests: { memory: 40Mi } }
  product-catalog:
    enabled: true
    resources: { limits: { memory: 20Mi }, requests: { memory: 15Mi } }
  quote:
    enabled: true
    resources: { limits: { memory: 24Mi }, requests: { memory: 16Mi } }
  recommendation:
    enabled: true
    resources: { limits: { memory: 150Mi }, requests: { memory: 100Mi } }
  shipping:
    enabled: true
    resources: { limits: { memory: 20Mi }, requests: { memory: 15Mi } }

  # --- Infraestructura del demo ---
  flagd:
    enabled: true
    resources: { limits: { memory: 48Mi }, requests: { memory: 32Mi } }
  kafka:
    enabled: true
    resources: { limits: { memory: 512Mi }, requests: { memory: 384Mi } }
    envOverrides:
      - name: KAFKA_HEAP_OPTS
        value: "-Xmx256M -Xms256M"
  astronomy-db:
    enabled: true
    resources: { limits: { memory: 64Mi }, requests: { memory: 48Mi } }
  valkey-cart:
    enabled: true
    resources: { limits: { memory: 16Mi }, requests: { memory: 12Mi } }

  # --- Deshabilitados (ver arquitectura para el porqué) ---
  frontend-proxy:
    enabled: false   # bug TCMalloc en arm64
  ad:
    enabled: false
  agent:
    enabled: false   # LLM
  chatbot:
    enabled: false   # LLM
  mcp:
    enabled: false   # LLM
  load-generator:
    enabled: false   # 1.5GB de tráfico sintético
  telemetry-docs:
    enabled: false
  opamp-server:
    enabled: false
  firepit:
    enabled: false

# --- Collector ---
opentelemetry-collector:
  enabled: true
  mode: daemonset
  fullnameOverride: otel-collector
  presets:
    hostMetrics: { enabled: false }
    kubernetesAttributes: { enabled: true }
    kubeletMetrics: { enabled: true }
    clusterMetrics: { enabled: false }
    annotationDiscovery:
      metrics: { enabled: true }
  resources:
    limits: { memory: 150Mi }
    requests: { memory: 100Mi }
  config:
    receivers:
      otlp:
        protocols:
          http:
            cors:
              allowed_origins: ["http://*", "https://*"]
              allowed_headers: ["content-type", "traceparent", "baggage"]
    exporters:
      debug:
        verbosity: detailed

# --- Backends de observabilidad: FUERA, viven en k3s-o11y ---
jaeger:
  enabled: false
prometheus:
  enabled: false
grafana:
  enabled: false
opensearch:
  enabled: false
```

**Puntos clave del values** (explicar en el lab):

* `kafka` con heap reducido a 256M — el default (400M) OOMKillea en este nodo
* `frontend-proxy` deshabilitado — crash garantizado en arm64, el ingress va en `frontend`
* Los 4 backends de observabilidad deshabilitados — viven en `k3s-o11y`

## 3. Instalar

```bash
kubectl config use-context k3s-prod

helm install otel-demo open-telemetry/opentelemetry-demo \
  --version 0.42.0 \
  --namespace otel-demo \
  --create-namespace \
  --values otel-demo-values.yaml
```

> **No uses `--wait`** en este nodo: los pulls de imágenes arm64 tardan ~7 min y el
> comando puede quedarse esperando. Lanza sin `--wait` y observa el progreso.

## 4. Observar el despliegue

```bash
kubectl get pods -n otel-demo -w
```

Qué esperar (~5-7 min):

1. Los pods pasan por `ContainerCreating` mientras bajan imágenes
2. `kafka` puede reiniciar 1-2 veces durante el arranque de KRaft — normal
3. `accounting`, `checkout`, `shipping`, `fraud-detection` se quedan en `Init:0/1`:
   sus initContainers (`wait-for-kafka`) esperan a que `kafka:9092` responda
4. Cuando kafka levanta, los init terminan y todos los pods quedan `Running 1/1`

```bash
# Eventos del namespace por si algo falla
kubectl get events -n otel-demo --sort-by=.lastTimestamp | tail -20
```

## 5. Verificar

```bash
# Todos los pods Ready
kubectl get pods -n otel-demo

# El ingress asignado
kubectl get ingress -n otel-demo
# NAME       CLASS   HOSTS                     ADDRESS          PORTS
# frontend   nginx   otel-demo.hq.kronops.io   10.101.165.140   80
```

Smoke test del ingress (desde un pod dentro del cluster):

```bash
kubectl run curl-test --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" \
  http://10.101.165.140/ -H "Host: otel-demo.hq.kronops.io"
# Esperado: 200
```

Abrir la tienda desde el navegador:

```
http://otel-demo.hq.kronops.io
```

## 6. Ver la telemetría

### En vivo por stdout (sin backends)

El collector imprime cada traza/log con el exporter debug:

```bash
kubectl logs -n otel-demo \
  -l app.kubernetes.io/name=opentelemetry-collector -f --tail=50
```

> El label correcto es `app.kubernetes.io/name=opentelemetry-collector`. Verifícalo
> siempre con `kubectl describe daemonset otel-collector-agent -n otel-demo`.

Genera tráfico: agrega productos al carrito y completa una compra en la UI. En los
logs del collector verás los spans de la transacción completa con su trace id.

### En Grafana (backends de o11y)

1. Abre `https://grafana.hq.kronops.io`
2. **Explore → Tempo**: busca por `service.name = frontend` o pega un trace id
3. **Explore → Loki**: query `{service_name="checkout"}` para ver los logs
4. Sigue el waterfall de la compra: frontend → checkout → payment

## 7. Ejercicios sugeridos para el lab

1. **Seguir una traza de punta a punta** — completa una compra y localiza en Tempo
   la traza desde `frontend` hasta `kafka` (propagación de contexto W3C)
2. **Comparar instrumentación por lenguaje** — abri la traza en Grafana y observa
   las librerías de instrumentación distintas por servicio (Java agent, .NET auto,
   SDK manual en Rust...)
3. **Feature flags** — en la UI del demo, activa el flag `productIdCache` y observa
   el cambio en los spans de `recommendation`
4. **Fault injection** — activa el flag `cartFailure` y analiza la traza fallida
   (error spans, propagación de errores)
5. **Redaction de PII** — completa el pago y busca en Tempo los atributos
   `demo.payment.card_number`: verás `****-****-****-0454` (el collector los
   enmascaró)
6. **Logs estructurados** — en Loki, correlaciona un trace id con los logs de
   `checkout`

## Troubleshooting

| Síntoma | Causa | Fix |
|---------|-------|-----|
| Pod en `Init:0/1` mucho tiempo | Esperando a kafka | Normal hasta que kafka levanta; revisa `kubectl logs <pod> -c wait-for-kafka` |
| `kafka` en `CrashLoopBackOff` / `OOMKilled` | Heap default no cabe | Verifica `KAFKA_HEAP_OPTS=-Xmx256M` en el values |
| `frontend-proxy` crash con `TCMalloc ... MmapAligned() failed` | Bug arm64 conocido | Mantener `frontend-proxy.enabled: false`; exponer `frontend` |
| `helm install` falla con "cannot reuse a name" | Un install previo quedó a medio caminar | `helm uninstall otel-demo -n otel-demo` y reintenta |
| Prometheus/Grafana aparecen en el namespace | Values sin `enabled: false` explícito | Bórralos (`kubectl delete deploy/svc <name> -n otel-demo`) y corrige el values |
| Namespace atascado en `Terminating` | Finalizer pendiente | `kubectl get ns otel-demo -o json \| jq '.spec.finalizers'` — vaciar con proxy+finalize |
| Logs de fraud-detection llenos de `opensearch: no such host` | El chart default exporta logs a OpenSearch del demo completo | Ruido esperado: el servicio funciona. Discutir como ejemplo de config default vs entorno real |
| DNS no resuelve `*.hq.kronops.io` desde el cluster | external-dns → RFC2136, ciclo de 2 min; caché negativa de CoreDNS | Esperar un ciclo completo; verificar `kubectl logs -n external-dns deploy/external-dns` |
| Ingress 404 en `/` con rewrite configurado | `rewrite-target: /` rompe las rutas absolutas del frontend | NO usar `nginx.ingress.kubernetes.io/rewrite-target` en este ingress |

## Limpieza

```bash
helm uninstall otel-demo -n otel-demo
kubectl delete namespace otel-demo   # opcional: elimina el namespace completo
```

## Referencias

* Arquitectura general: `docs/o11y-arquitecture.md`
* [OpenTelemetry Demo docs](https://opentelemetry.io/docs/demo/)
* [Demo Helm chart values](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-demo)
