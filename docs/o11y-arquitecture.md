# Arquitectura de Observabilidad del Homelab — OTel Demo + LGTM

## Introducción

Este documento describe la arquitectura de observabilidad del homelab kronops: cómo el
**OpenTelemetry Demo** (tienda web "Astronomy Shop") genera telemetría, cómo el
**OpenTelemetry Collector** la procesa, y cómo los backends **LGTM** (Loki, Grafana,
Tempo, Mimir) del cluster de observabilidad la almacenan y visualizan.

El homelab corre sobre clusters k3s en Raspberry Pi (arm64). El demo vive en `k3s-prod`
y los backends de observabilidad en `k3s-o11y`. La separación es deliberada: el nodo de
prod es un Pi de 4GB que no puede sostener el demo Y los backends a la vez.

### Objetivos

* Desplegar el demo OTel como aplicación de prueba polglota (11 servicios en 8 lenguajes)
* Exportar trazas, logs y métricas a backends centralizados en `k3s-o11y`
* Visualizar la telemetría en Grafana con los tres datasources configurados
* Tener un laboratorio repetible para clases: los alumnos despliegan y configuran todo

## Topología general

```
┌─────────────────── k3s-prod (10.101.165.13) ───────────────────┐
│                                                                 │
│  namespace: otel-demo                                           │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐    │
│  │ frontend │──▶ checkout │──▶ payment   │  │ product-catalog   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────┬───────┘    │
│       │             │             │               │            │
│  ┌────▼─────────────▼─────────────▼───────────────▼──────┐     │
│  │              OTel Collector (DaemonSet)               │     │
│  │         receivers: otlp :4317/:4318                   │     │
│  └────┬──────────────┬──────────────┬────────────────────┘     │
│       │              │              │                           │
└───────┼──────────────┼──────────────┼───────────────────────────┘
        │ traces       │ logs         │ metrics
        ▼              ▼              ▼
┌─────────────────── k3s-o11y (10.101.165.160 LB) ───────────────┐
│                                                                 │
│  namespace: monitoring                                          │
│                                                                 │
│  tempo.hq.kronops.io ──▶ lgtm-tempo:4318   (traces)             │
│  loki.hq.kronops.io  ──▶ lgtm-loki:3100    (logs)               │
│  mimir.hq.kronops.io ──▶ lgtm-mimir          (metrics)          │
│  grafana.hq.kronops.io ─▶ lgtm-grafana:80  (visualización)      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Clusters

| Cluster | Nodo | IP | Rol | RAM |
|---------|------|----|----|-----|
| `k3s-prod` | k3s-prod (Pi 4, arm64) | 10.101.165.13 | Aloja el demo OTel | 4GB (3.7 allocatable) |
| `k3s-o11y` | VM Proxmox | 10.101.165.160 (LB) | Aloja el stack LGTM | dimensionado para backends |

Ambos clusters comparten la LAN `10.101.165.0/24` y el patrón de ingresses:

* **MetalLB** asigna IPs del pool `10.101.165.140-167`
* **ingress-nginx** enruta por host
* **cert-manager** emite TLS con el ClusterIssuer del cluster
* **external-dns** registra los hosts vía RFC2136 contra el DNS de la LAN

## El demo: Astronomy Shop

El [OpenTelemetry Demo](https://opentelemetry.io/docs/demo/) es una tienda web de
astronomía compuesta por microservicios **polglotas** — su valor didáctico es mostrar
instrumentación OTel en múltiples lenguajes:

| Servicio | Lenguaje | Función | Señal que genera |
|----------|----------|---------|------------------|
| frontend | TypeScript (Next.js) | UI de la tienda | traces (incluye browser telemetry) |
| cart | C# (.NET) | Carrito (Valkey) | traces, metrics, logs |
| checkout | Go | Proceso de compra | traces, metrics, logs |
| currency | C++ | Conversión de moneda | traces, metrics |
| payment | Node.js | Cobro (con datos "sensibles" para demo de redaction) | traces, metrics |
| product-catalog | Go | Catálogo (PostgreSQL) | traces, metrics, logs |
| quote | PHP | Cotización de envío | traces |
| recommendation | Python | Recomendaciones | traces, metrics, logs |
| shipping | Rust | Cálculo de envío | traces, metrics |
| email | Python (Django) | Notificaciones | traces, logs |
| accounting | .NET | Contabilidad (consume Kafka) | traces, logs |
| fraud-detection | Java | Detección de fraude (consume Kafka) | traces, logs |
| kafka | (KRaft) | Cola de órdenes | — |
| flagd + flagd-ui | (OpenFeature) | Feature flags | traces |
| astronomy-db | PostgreSQL 18 | Base de datos | — |
| valkey-cart | Valkey | Estado del carrito | — |

### Componentes deshabilitados y por qué

El chart permite habilitar/deshabilitar cada servicio. En este homelab se deshabilitan:

| Componente | Razón |
|------------|-------|
| `frontend-proxy` | Bug de TCMalloc en la imagen Envoy en arm64: intenta un mmap de 1GB al arrancar y crash (exit 134). No se corrige con env vars. El `frontend` se expone directo por ingress. |
| `prometheus`, `grafana`, `jaeger`, `opensearch` | Los backends de observabilidad viven centralizados en `k3s-o11y`. Instalarlos por-demo duplica ~2GB RAM en un nodo de 4GB. |
| `load-generator` | 1.5GB de RAM para tráfico sintético. Solo si sobra RAM. |
| `agent`, `chatbot`, `mcp` | Componentes LLM, pesados y fuera del alcance del lab. |
| `ad`, `telemetry-docs`, `opamp-server`, `firepit` | Opcionales del demo, no aportan al objetivo. |

### Resource tuning para el Pi

Los límites del chart default asumen un nodo con holgura. Valores verificados en `k3s-prod`:

| Componente | Default | Homelab | Nota |
|------------|---------|---------|------|
| kafka | 700Mi (heap 400M) | **512Mi (heap 256M)** | A 400Mi de limit entra en OOMKill loop |
| recommendation | 500Mi | 150Mi | Sobra para el lab |
| fraud-detection | 300Mi | 200Mi | |
| frontend | 250Mi | 128Mi | |
| resto | 16-160Mi | igual o menor | |

Total en limits con esta configuración: **~1.9GB** — cabe holgado en los 3.7GB
allocatable del nodo.

## El collector

El chart despliega el **OpenTelemetry Collector Contrib** como DaemonSet (un nodo =
una réplica). Es el único punto de salida de telemetría del demo:

```
servicios (OTLP gRPC :4317 / HTTP :4318)
        │
        ▼
receivers: otlp, kafkametrics, kubeletstats, receiver_creator
        │
processors: k8s_attributes → memory_limiter → resource_detection → resource
            → transform (sanitización/redaction de PII)
        │
exporters → backends
```

### Pipelines

| Pipeline | Destino en el diseño del chart | Destino en este homelab |
|----------|-------------------------------|------------------------|
| traces | jaeger, debug | **tempo** (via ingress o11y) + debug |
| logs | opensearch, debug | **loki** (via ingress o11y) + debug |
| metrics | prometheus, debug | **mimir** (via ingress o11y) + debug |

El exporter `debug` (verbosity: detailed) imprime la telemetría al stdout del
collector — útil para ver trazas en vivo durante una clase sin abrir Grafana.

### Procesamiento de seguridad

El pipeline de traces incluye dos procesadores didácticos (el demo los trae de fábrica):

* `transform/redact_sensitive_data` — enmascara card numbers, hashea emails
* `redaction` — bloquea keys con patrones tipo password/secret/pin

Útil para enseñar que la telemetría también es superficie de fuga de datos.

## Los backends en k3s-o11y

Desplegados vía ArgoCD + Helm (ver runbook de LGTM). Cada backend expone su endpoint
de ingesta OTLP a través de ingress con TLS:

| Backend | Ingress host | Endpoint de ingesta | Señal |
|---------|--------------|--------------------|----|
| **Tempo** | `tempo.hq.kronops.io` | `:4318` (OTLP HTTP) | traces |
| **Loki** | `loki.hq.kronops.io` | `/otlp/v1/logs` | logs |
| **Mimir** | `mimir.hq.kronops.io` | `/otlp/v1/metrics` | metrics |
| **Grafana** | `grafana.hq.kronops.io` | UI :80 | visualización |

Los tres backends resuelven por DNS de la LAN (`hq.kronops.io` vía external-dns +
RFC2136). Dentro de cada cluster, Grafana usa los service DNS internos
(`lgtm-tempo.monitoring:4317`, etc.) como datasources.

## Flujo completo de una traza

```
1. Usuario abre la tienda → ingress k3s-prod → frontend
2. frontend llama a checkout → propagación de contexto (W3C traceparent)
3. checkout llama a currency, cart, payment, shipping...
4. Cada servicio instrumenta sus spans y los exporta OTLP → collector
5. Collector: agrega attrs k8s, limita memoria, redacta PII
6. Collector exporta → https://tempo.hq.kronops.io (ingress o11y, TLS)
7. Tempo indexa los spans en bloques (filesystem + PVC)
8. Analista abre grafana.hq.kronops.io → Explore → Tempo → busca por service.name
```

## Decisiones de diseño (ADR resumido)

1. **Demo y backends en clusters separados** — el Pi de prod no soporta ambos; además
   refleja el patrón real de plataforma de observabilidad compartida.
2. **Ingesta por ingress TLS con hostname, no por IP ni NodePort** — un solo punto de
   entrada por backend, certificados gestionados, mismo mecanismo que producción.
3. **Collector como DaemonSet** — patrón agente estándar; si el cluster crece a varios
   nodos, cada nodo gana su collector sin cambios.
4. **Exporters debug habilitados** — en un lab, ver la telemetría cruda en stdout es
   herramienta pedagógica; en producción se apagaría.
5. **Kafka habilitado** — el flujo checkout → kafka → accounting/fraud-detection es el
   ejemplo de mensajería asíncrona con telemetría; requiere el tuning de heap descrito.

## Referencias

* [OpenTelemetry Demo — Kubernetes deployment](https://opentelemetry.io/docs/demo/kubernetes-deployment/)
* [OpenTelemetry Demo Helm chart](https://opentelemetry.io/docs/platforms/kubernetes/helm/demo/)
* [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
* Documentos relacionados en este repo: `docs/deploy-k3s-cluster.md`,
  `docs/argocd-apps-flow`
