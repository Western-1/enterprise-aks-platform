# Плейбук — кожна команда пояснена

[English version](playbook.md)

Команди запускаються з PowerShell на Windows. Усе нижче перевірено.

## 1. Вхід і підписка

```powershell
az login --use-device-code   # якщо браузерне вікно WAM не відкрилось — цей прапорець примусово вмикає device-code flow
az account show              # яка підписка зараз
az account set --subscription "<назва>"   # перемкнути, якщо їх декілька
```

> **Порада**: якщо `az login` зависає, а в `--debug` видно `Broker enabled? True`,
> вимкніть WAM-брокер один раз: `az config set core.broker=off`.

## 2. Підняття інфраструктури (Terraform)

```powershell
cd terraform/environments/dev

# один раз: завантажити провайдерів
terraform init

# створити локальний файл секретів (ніколи не комітити)
# terraform.tfvars з subscription_id — вже у .gitignore
terraform fmt -recursive    # форматування
terraform validate          # статичні перевірки
terraform plan              # подивитись, що зміниться
terraform apply             # застосувати (додайте -auto-approve, щоб пропустити підтвердження)
```

Очікуваний результат `apply`: ресурси створені в resource group `rg-dev-aks-ne`
(VNet, підмережі, ACR, Key Vault, PostgreSQL, AKS, Log Analytics).

## 3. Підключення kubectl

```powershell
az aks get-credentials --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --overwrite-existing
kubectl get nodes
kubectl get pods -A
```

Очікується: дві ноди `system` у статусі `Ready`, системні поди (cilium, gatekeeper,
`aks-secrets-store-csi-driver`, `ama-logs`) — усі `Running`.

## 4. Робота з Key Vault

```powershell
# список назв секретів (значення ніколи не друкуються в репозиторій)
az keyvault secret list --vault-name kv-dev-media-ne --query "[].name" --output table
```

Пароль PostgreSQL і connection string Terraform пише автоматично
(`db-password`, `db-url`) — ніколи не кладіть їх у файли, що потрапляють у git.

## 5. Масштабування / зупинка / запуск кластера (економія)

```powershell
# зменшити user pool до 0 (він і сам так робить)
kubectl scale --replicas=0 deployment/<назва>

# зменшити ноди system pool (економить ~$92/міс за ноду)
az aks scale --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --node-pool system --node-count 1

# повне знесення всього
cd terraform/environments/dev
terraform destroy
```

> Кластер коштує ~$210/міс при роботі 24/7. Зупиняйте його після роботи.
> `terraform destroy` видаляє всі ресурси і state — наступний `terraform apply`
> перебудує ту саму платформу.

## 6. Часті перевірки

```powershell
az aks show --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --query "{state:provisioningState, version:kubernetesVersion}"
az postgres flexible-server show --name psql-dev-media-ne --resource-group rg-dev-aks-ne --query "{state:state, version:version}"
az acr show --name acrdevmedia --query "{loginServer:loginServer, sku:sku.name}"
```

## 7. Перевірка витрат

```powershell
# у порталі: Cost Management + Billing → Cost analysis → фільтр rg-dev-aks-ne
# після цього оновіть docs/costs.md і docs/costs.ua.md
```

## 8. Argo CD (GitOps)

UI Argo CD публічний через Azure Load Balancer (Standard, frontend IP з кластерного
outbound LB):

```powershell
# відкрийте в браузері (admin / початковий пароль із секрету нижче)
# URL: http://<frontend-ip>/ — отримайте його:
kubectl get svc argocd-server -n argocd -o jsonpath="{.status.loadBalancer.ingress[0].ip}"

# початковий пароль адміністратора
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# CLI (argocd.exe)
argocd login <frontend-ip>:80 --username admin --password <пароль> --insecure
argocd app list                     # застосунки та їхній sync-статус
argocd app sync <app-name>          # примусова синхронізація
argocd app get cluster-config       # деталі та ресурси
```

> Примітка: сервер працює з `server.insecure: true` (чистий HTTP) для демо — у проду
> Argo CD сам обслуговує TLS, зазвичай за ingress з SSO.
>
> Примітка: `kubectl port-forward` до Argo CD на цьому кластері не працює — датаплейн
> Cilium відкидає трафік на порт сервісу на IP ноди (backend LB = порт сервісу з
> floating IP; перехоплюється тільки nodePort). Підтримуваний шлях — LoadBalancer-сервіс.
> NSG `nsg-aks` дозволяє 80/443 з Інтернету для frontend LB — для інших портів розширте
> `lb_ingress_ports` у Terraform.

### Як додати новий застосунок у кластер

1. Запуште маніфести в `enterprise-aks-gitops` (наприклад, `apps/media-api/`).
2. Додайте маніфест `Application` у `enterprise-aks-gitops/infrastructure/argocd/`.
3. Пуш. Argo CD синхронізує новий застосунок протягом хвилини — **kubectl apply не потрібен**.