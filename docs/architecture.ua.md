# Архітектура — Enterprise AKS Platform

[English version](architecture.md)

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
- **Масштабування**: автоскейлер нод в обох пулах; HPA для подів (додамо разом із застосунком).

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

### Топологія мережі

```
                   10.0.1.0/24 snet-aks      ноди AKS + поді
VNet 10.0.0.0/16   10.0.2.0/24 snet-app       майбутні app-gateway / jumpbox
                   10.0.3.0/24 snet-private-endpoint   PE: KV, PostgreSQL

Private DNS зони: privatelink.vaultcore.azure.net, privatelink.postgres.database.azure.com
```

Key Vault і PostgreSQL доступні **лише** через private endpoints — без публічних IP.

## Заплановано (наступні ітерації)

- Argo CD + GitOps-репозиторій
- `media-api` (FastAPI) + `media-worker` + Redis, деплой через Argo CD
- HPA, PDB, NetworkPolicies, ResourceQuotas
- GitHub Actions CI/CD з Trivy, Helm lint, Checkov
- Prometheus + Grafana + OpenTelemetry
- Azure Front Door / Application Gateway перед ingress