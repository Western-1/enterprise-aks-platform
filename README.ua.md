# Enterprise AKS Platform — Zero Trust GitOps Infrastructure

Production-рівень Kubernetes-платформа в Azure, побудована на **Terraform**, доставляється через **GitOps (Argo CD)**, захищена за моделлю **Zero Trust** і повністю спостережувана.

> **Це демо/портфоліо-проєкт, а не продакшн.** Він показує, як проєктується справжня корпоративна Kubernetes-платформа: усе — це код, нічого не живе в git, що мало жити у сховищі секретів, а кластер відновлюється сам з git-репозиторію.

[English version](README.md)

---

## Навіщо цей проєкт

Більшість «Kubernetes-проєктів» — це один nginx-под. Цей проєкт — протилежне: тонкий демо-застосунок
(`media-api` + worker + PostgreSQL + Redis), загорнутий у корпоративну платформу. Приблизно **80% складності —
в платформі** (мережа, безпека, GitOps, спостережуваність, масштабування), і лише 20% — у самому застосунку.

Результат — один артефакт, який можна показати на співбесіді й захистити:

- підняти весь стек однією командою `terraform apply`;
- запушити комміт і побачити, як Argo CD деплоїть;
- прогнати навантаження і побачити, як реагують HPA і Cluster Autoscaler;
- убити под і побачити, як Kubernetes його відновлює;
- показати дашборди Grafana і секрети Key Vault, які ніколи не потрапляли в git.

## Поточний статус

| Компонент | Статус |
|---|---|
| VNet + підмережі + NSG + private DNS | ✅ live |
| ACR `acrdevmedia.azurecr.io` | ✅ live |
| Key Vault + private endpoint | ✅ live |
| PostgreSQL (private endpoint, Entra ID без пароля) | ✅ live |
| AKS 1.34 (Cilium, OIDC, Workload Identity, CSI) | ✅ live |
| Log Analytics / Azure Monitor | ✅ live |
| GitOps (Argo CD) | ✅ live — app-of-apps + cluster-config Synced |
| Демо-застосунок (FastAPI) | ✅ live — http://4.245.138.35:8080/healthz |
| CI/CD (GitHub Actions) | ✅ live — OIDC, без секретів |
| Prometheus + Grafana | ✅ live — приватно, тільки в кластері |

## Архітектура (спрощено)

```
                INTERNET
                   │
                   ▼
         ┌───────────────────┐
         │  Azure Front Door │   (planned)
         │  WAF              │
         └─────────┬─────────┘
                   │
         ┌─────────▼─────────┐
         │ Application GW    │   (planned)
         └─────────┬─────────┘
═══════════════════╪════════════════════
                AZURE
                   │
         ┌─────────▼──────────┐
         │        VNet        │
         │  snet-aks / app /  │
         │  private-endpoint  │
         │                    │
         │  ┌──────────────┐  │
         │  │  AKS (1.34)  │  │
         │  │  Cilium      │  │
         │  │  Argo CD     │  │
         │  │  media-api   │  │
         │  │  worker      │  │
         │  │  redis       │  │
         │  └──────┬───────┘  │
         │         │          │
         └─────────┼──────────┘
                   │
        ┌──────────▼──────────┐
        │  Key Vault          │
        │  Secrets Store CSI  │
        │  Workload Identity  │
        └──────────┬──────────┘
                   │
        ┌──────────▼──────────┐
        │  PostgreSQL         │
        │  private endpoint   │
        └─────────────────────┘

          OBSERVABILITY
        Prometheus • Grafana
        Azure Monitor
```

Повна діаграма й деталі: [docs/architecture.ua.md](docs/architecture.ua.md).

## GitOps на практиці

Усе всередині кластера описано в репозиторії
[enterprise-aks-gitops](https://github.com/Western-1/enterprise-aks-gitops).
Argo CD стежить за ним і приводить кластер у відповідність — ніхто не застосовує маніфести вручну:

```
git push → Argo CD (app-of-apps) → створює/синхронізує Applications → кластер сходиться
```

Поточні застосунки під управлінням Argo CD: `cluster-config` (namespace `media`, `database`,
`monitoring`, `ingress` + ResourceQuota/LimitRange).

![Argo CD applications](docs/screenshots/argocd-apps.png)

*Інтерфейс Argo CD: кореневий застосунок `app-of-apps` і `cluster-config` — обидва Synced і Healthy. Кластер сходиться з репозиторію enterprise-aks-gitops, без ручного kubectl apply.*

## Структура репозиторію

```
terraform/
├── modules/                 перевикористовувані Terraform-модулі
│   ├── networking/          VNet, підмережі, NSG, private DNS
│   ├── acr/                 container registry
│   ├── key-vault/           vault + RBAC + private endpoint
│   ├── monitoring/          Log Analytics
│   ├── aks/                 кластер, node pools, OIDC, Workload Identity
│   └── postgres/            flexible server + private endpoint + KV secrets
└── environments/
    ├── dev/                 поточне робоче середовище (northeurope)
    ├── staging/             заплановано
    └── prod/                заплановано
docs/
├── architecture.md          детально (EN) / architecture.ua.md (UA)
├── costs.md                 облік витрат (EN) / costs.ua.md (UA)
├── playbook.md              кожна команда пояснена (EN) / playbook.ua.md (UA)
└── screenshots/             докази для портфоліо
```

## Початок роботи

Передумови: `terraform`, `az` (Azure CLI), `kubectl`, `helm` і активна Azure-підписка.

```bash
# 1. вхід
az login

# 2. створити локальний tfvars (реальні значення ніколи не комітяться)
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars

# 3. підняти все
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# 4. підключити kubectl до кластера
az aks get-credentials --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne
```

Повний довідник команд з очікуваним результатом — у [docs/playbook.ua.md](docs/playbook.ua.md).

## Zero Trust на практиці

- **Жодних секретів у git.** Пароль PostgreSQL генерує Terraform і одразу пише в Key Vault
  (`db-password`, `db-url`). Поди читають його через **Secrets Store CSI driver**.
  Сам застосунок входить у PostgreSQL **без пароля** — короткоживучим токеном
  Microsoft Entra, отриманим через workload identity (див. [архітектуру](docs/architecture.ua.md)).
- **Workload Identity.** Поди автентифікуються в Azure через федеративний service account — без client secrets.
  Той самий identity дає і секрети Key Vault (CSI-драйвер), і токени PostgreSQL (Entra ID).
- **Private networking.** Key Vault і PostgreSQL доступні лише через private endpoints.
- **RBAC всюди.** Ролі з мінімальними правами; ваш користувач має рівно стільки, скільки потрібно задачі.

Деталі: [docs/architecture.ua.md](docs/architecture.ua.md).

## Скріншоти

![Resource group overview](docs/screenshots/azure-rg-overview.png)

*Resource group `rg-dev-aks-ne` в Azure-порталі: VNet, ACR, Key Vault, PostgreSQL, AKS і Log Analytics — усе піднято Terraform.*

![AKS cluster overview](docs/screenshots/aks-overview.png)

*AKS-кластер `aks-dev-cluster-ne`: Kubernetes 1.34, system і user node pools з автоскейлінгом, мережа Cilium.*

![Поди демо-застосунку](docs/screenshots/media-pods.png)

*Неймспейс `media`: `media-api` + `media-worker` у Running, Redis у Running, job `db-init` Completed (створив базу `media` через workload identity).*

![Демо-API через публічний load balancer](docs/screenshots/media-healthz.png)

*Наскрізна перевірка через `http://4.245.138.35:8080`: `/healthz` повертає ok з db і redis true; POST/GET `/media/items` пише й читає рядок у PostgreSQL (view_count збільшує воркер через Redis).*

![Поди моніторингу](docs/screenshots/monitoring-pods.png)

*`kube-prometheus-stack` у `monitoring`: operator, Grafana, kube-state-metrics, node-exporters і Prometheus (2/2) у Running.*

![Метрика застосунку в Prometheus](docs/screenshots/monitoring-query.png)

*`media_items_created_total`, зібрана з `media-api` через ServiceMonitor — весь шлях (застосунок → /metrics → Prometheus) перевірено.*

![Трейси в Tempo](docs/screenshots/tempo-traces.png)

*Спани `media-api` (`GET /healthz`, asyncpg `BEGIN`/`COMMIT`), експортовані через OTLP крізь колектор у Tempo — трейси перевірено через Tempo search API.*

## Витрати

Це trial-підписка з **безкоштовними кредитами $200** — картка ніколи не списується, поки явно
не знято spending limit. Поточна інфраструктура коштує **~$218/міс**, тому кластер вмикають
тільки під час роботи. Повна таблиця: [docs/costs.ua.md](docs/costs.ua.md).

## Індекс документації

| Документ | EN | UA |
|---|---|---|
| README | цей файл | [README.ua.md](README.ua.md) |
| Архітектура | [architecture.md](docs/architecture.md) | [architecture.ua.md](docs/architecture.ua.md) |
| Витрати | [costs.md](docs/costs.md) | [costs.ua.md](docs/costs.ua.md) |
| Плейбук | [playbook.md](docs/playbook.md) | [playbook.ua.md](docs/playbook.ua.md) |