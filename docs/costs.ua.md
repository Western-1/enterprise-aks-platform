# Витрати Azure — Enterprise AKS Platform

Усі суми приблизні, взяті з [тарифів Azure](https://azure.microsoft.com/en-us/pricing/)
для регіону **northeurope**, dev-середовище. Фактичні суми беруться з
Azure Cost Management (`Cost analysis`) і оновлюються тут.

Ціни з позначкою `approx` — оціночні; остаточний рахунок може відрізнятися на кілька доларів.
Підписка зараз працює на **безкоштовних кредитах $200** — картка не списується,
поки ліміт витрат (spending limit) не знято явно.

## Поточна інфраструктура (dev)

| Ресурс | Конфігурація | Орієнтовна вартість | Фактична вартість | Нотатки |
|---|---|---|---|---|
| Resource group | `rg-dev-aks-ne` | $0 | | Безкоштовно |
| VNet + підмережі + NSG | `vnet-dev-aks-ne` | $0 | | Безкоштовно |
| Private DNS зони | `privatelink.*` | $0 | | Безкоштовно |
| Private endpoints | Key Vault | $0 | | Безкоштовно |
| Container Registry | `acrdevmedia` (Basic) | ~$3 / міс | | Сховище та пуши — копійки |
| Key Vault | `kv-dev-media-ne` (standard) | ~$0–1 / міс | | Безкоштовний тариф 10k транзакцій |
| Log Analytics | `la-dev-aks-ne`, збереження 30 днів | ~$3 / міс | | Оплата за ГБ |
| AKS control plane | Free tier | $0 | | |
| AKS system pool | 2× `Standard_EC2as_v5` | ~$184 / міс | | Confidential compute — єдина родина VM, яку дозволяє trial-підписка |
| AKS user pool | `Standard_EC2as_v5`, 0–1 ноди (автоскейлінг) | $0–92 / міс | | $0 у простої |
| **Разом, у простої** | | **~$190 / міс** | | |
| **Разом, під навантаженням** | | **~$282 / міс** | | |

## Заплановані ресурси (ще не створені)

| Ресурс | Конфігурація | Орієнтовна вартість | Нотатки |
|---|---|---|---|
| PostgreSQL Flexible Server | Basic `B1ms`, 32 ГБ | ~$16 / міс | Тільки якщо застосунку потрібна БД у dev |

## Як вимірюються витрати

1. Azure portal → **Cost Management + Billing** → *Cost analysis* → фільтр за resource group `rg-dev-aks-ne`.
2. Експортувати місячні суми й оновити колонку «Фактична вартість».
3. Перед створенням чогось нового — спочатку додати рядок у *Заплановані ресурси*.

## Прибирання

- Після завершення задачі: `terraform destroy` у `terraform/environments/dev`, потім оновити цей файл.
- User pool масштабується до **0** у простої — сам кластер продовжує працювати.
- Повний цикл життя — у `docs/playbook.md`.
