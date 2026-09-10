# Архітектура — Enterprise AKS Platform

[English version](architecture.md)

> **Фінальний стан (10 вересня 2026):** кластер AKS видалено за рішенням власника,
> підписка вимкнена — нижче нічого не live. Документ описує останній живий стан
> і шлях перебудови ([costs](costs.ua.md), [recovery](recovery.ua.md)).

## Огляд

Платформа — це однотенантне dev-середовище в Azure. Уся інфраструктура описана в Terraform,
усі застосунки доставляються Argo CD з GitOps-репозиторію, а workload-и автентифікуються
в Azure без жодних секретів у коді.

## Компоненти

### Azure-шар

| Компонент | Назва | Призначення |
|---|---|---|
| Resource group | `rg-dev-aks-ne` | Одна RG на все середовище |
| Virtual network | `vnet-dev-aks-ne` (10.0.0.0/16) | Усе живе всередині цієї VNet |
| Підмережі | `snet-aks` (10.0.1.0/24), `snet-app` (10.0.2.0/24), `snet-private-endpoint` (10.0.3.0/24) | Ізоляція мережі |
| NSG | `nsg-aks`, `nsg-app`, `nsg-private-endpoint` | Файрвол підмереж (правила будуть уточнені) |
| ACR | `acrdevmedia` (Basic) | Образ контейнерів; admin вимкнено |
| Key Vault | `kv-dev-media-ne` | Усі секрети; private endpoint; RBAC |
| AKS | `aks-dev-cluster-ne` (1.34) | Kubernetes-кластер |
| Log Analytics | `la-dev-aks-ne` | Container insights, метрики, логи |
| PostgreSQL | `psql-dev-media-ne` (PG16, B1ms) | База даних; тільки private endpoint |

### Внутрішнє влаштування AKS

- **Мережа**: Azure CNI Overlay + **Cilium** dataplane (Cilium також виконує NetworkPolicies).
- **Node pools**:
  - `system` — 2 × `Standard_EC2as_v5` (confidential compute, єдина родина, яку дозволяє trial), Azure Linux.
  - `user` — 0–1 × `Standard_EC2as_v5`, автоскейлінг, для застосунків.
- **Ідентичність**: System-assigned identity кластера + **OIDC issuer** + **Workload Identity** для подів.
- **Безпека**: Azure Policy (Gatekeeper), Secrets Store CSI driver із ротацією, allowlist IP для API server.
- **Масштабування**: автоскейлер нод в обох пулах; HPA на `media-api` (live).

### Потік секретів (Zero Trust)

```
Пароль PostgreSQL
        генерує Terraform (random_password)
                  │
                  ▼
          Key Vault  db-password / db-url
                  │
     (pod) CSI driver ← Workload Identity ← service account
                  │
                  ▼
            застосунок читає секрет
```

Жоден пароль ніколи не з'являється в git-репозиторії чи Kubernetes-маніфесті.

### PostgreSQL без пароля (Microsoft Entra ID)

Демо-застосунок взагалі не використовує пароль із Key Vault. Натомість workload
identity пода (`uami-media-dev-ne`, зареєстрований Entra-адміном сервера) отримує
короткоживучий токен доступу й передає його як пароль PostgreSQL:

```
pod (service account media-api)
  │  federated credential → workload identity (client-id 2308ae95-…)
  ▼
login.microsoftonline.com → токен для https://ossrdbms-aad.database.windows.net
  │  (scope ossrdbms-aad — застарілий scope ossrdbms відхиляється з AADSTS500011)
  ▼
psql-dev-media-ne.postgres.database.azure.com як uami-media-dev-ne (ssl=require)
```

- Мережа: політика `default-deny` блокує все; `allow-db-egress` відкриває
  `10.0.3.0/24:5432`, а `allow-aad-egress` — TCP 443 для токен-ендпоїнта.
- Job `db-init` створює базу `media` тим самим identity до старту застосунку.
- Жодних паролів ніде: legacy-секрети Key Vault (`db-password` / `db-url`) і
  монтування CSI-драйвера видалено — випадковий admin-пароль існує лише тому,
  що Azure вимагає його при створенні сервера (break-glass через Terraform state).

### Топологія мережі

```
                   10.0.1.0/24 snet-aks      ноди AKS + поді
VNet 10.0.0.0/16   10.0.2.0/24 snet-app       майбутні app-gateway / jumpbox
                   10.0.3.0/24 snet-private-endpoint   PE: KV, PostgreSQL

Private DNS зони: privatelink.vaultcore.azure.net, privatelink.postgres.database.azure.com
```

Key Vault і PostgreSQL доступні **лише** через private endpoints — без публічних IP.

## Спостережуваність (live)

- `kube-prometheus-stack` 90.0.0 через Argo CD (застосунок `monitoring`, multi-source:
  чарт із публічного репо + `apps/monitoring/values.yaml` із GitOps).
  Налаштовано під маленькі ноди: retention 7д/8GB, PVC 10Gi, alertmanager вимкнено,
  Grafana ClusterIP з persistence 5Gi (admin-пароль генерує чарт, лежить у секреті
  `monitoring-grafana`).
- `media-api` віддає `/metrics` (лічильник `media_items_created_total`), а
  `ServiceMonitor` згодовує їх Prometheus — перевірено end-to-end.
- Redis працює подом (`Deployment`) у `media` (Azure Cache for Redis ніколи не
  створювався) — черга між `media-api` та `media-worker`.
- Grafana приватна (без зайвого LB-frontend): перевіряти зсередини кластера.
- Tempo 1.24 (single binary, PVC 5Gi) + OTel-колектор (deployment) у тому самому
  неймспейсі: `media-api` експортує FastAPI- й asyncpg-спани через OTLP/HTTP
  (`OTEL_EXPORTER_OTLP_ENDPOINT`, дозволено політикою `allow-otlp-egress`),
  колектор батчить їх у Tempo; у Grafana Tempo підключено як datasource.
- Два уроки Argo CD з цього rollout: CRD prometheus-operator перевищують ліміт
  анотацій 256KB при client-side apply → `ServerSideApply=true`; клієнтська схема
  Argo 2.14 не знає `.status.terminatingReplicas` (новіший K8s) → server-side diff
  compare option на застосунку.

## GitOps-доставка

```
developer: git push
     │
     ▼
репозиторій enterprise-aks-gitops (єдине джерело істини)
     │  Argo CD опитує (app-of-apps)
     ▼
AKS-кластер сходиться (Sync/Healthy)
```

- **Кореневий застосунок** `app-of-apps` стежить за `infrastructure/argocd/` у GitOps-репо
  і створює кожен `Application`, оголошений там.
- **cluster-config** застосовує маніфести рівня кластера: namespace (`media`, `database`,
  `monitoring`, `ingress`), `ResourceQuota`, `LimitRange`.
- Нічого не застосовується через `kubectl apply` — Argo CD — єдиний, хто пише в кластер.

### Зовнішній доступ (останній живий стан: ingress)

- Фінальна схема: `ingress-nginx` на frontend `4.210.50.215` кластерного outbound LB,
  nip.io-хости, self-signed demo TLS (ClusterIssuer `selfsigned-demo` —
  Let's Encrypt HTTP-01 відкинуто: нема Azure LB hairpin для self-check).
  - Демо-API: `https://media.4-210-50-215.nip.io` (перевірено: `/healthz` ok,
    POST створює елементи).
  - UI Argo CD лишився на оригінальному `LoadBalancer`-сервісі
    (`http://20.54.22.159`, `server.insecure: true`); HTTPS ingress
    (`https://argocd.4-210-50-215.nip.io`) закомічено в GitOps, але live не
    перевірено — кластер помер раніше.
- Рання ітерація давала кожному застосунку свій LB-сервіс (`media-api-lb` на `:8080`,
  старий IP `4.245.138.35`); замінено на ingress, щоб зекономити frontend IP
  (trial-підписка дозволяє лише 3 публічні IP).
- `nsg-aks` дозволяє TCP 80/443 з Інтернету для frontend LB (`lb_ingress_ports`
  у модулі networking) — решта залишається закритою (zero-trust підхід).
- Чому не `kubectl port-forward`: датаплейн Cilium на AKS перехоплює на IP нод лише
  діапазон nodePort, а правило Azure LB цілить у порт сервісу (floating IP).
  Підтримуваний шлях — LoadBalancer-сервіс.

## Заплановано (наступні ітерації)

- Azure Front Door / Application Gateway перед ingress
- Справжній домен + DNS-01 для довірених TLS (замість self-signed demo-сертифікатів)
- Перевірити HTTPS ingress Argo CD live після перебудови