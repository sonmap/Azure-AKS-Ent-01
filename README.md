# Azure-AKS-Ent-01

Azure AKS 2-node 환경에서 기존 온프레미스의 `L4 → Apache WEB → Tomcat WAS → MySQL DB` 구조를 재현하는 마이그레이션 PoC입니다.

## 구성 범위

```text
00-bootstrap            Resource Group, Log Analytics, Terraform State Storage
10-network-security     Hub/Spoke VNet, Subnet, NSG, VNet Peering
20-aks-platform         AKS 2 nodes, ACR, Key Vault, ACR Pull 권한
30-platform-addons      Jenkins, Argo CD Helm 배포
apps/legacy-app         Apache/Tomcat 컨테이너 소스와 MySQL 초기 SQL
deploy/tc01             Deployment, Service, StatefulSet, NetworkPolicy
pipelines               Azure DevOps Terraform Pipeline
argocd                  Argo CD Application
Jenkinsfile             Image Build/Push 및 AKS 배포 Pipeline
```

## 아키텍처

```text
사용자
  ↓
Azure Standard Load Balancer
  ↓
apache-service :80
  ↓
Apache Deployment × 2
  ↓
tomcat-service :8080
  ↓
Tomcat Deployment × 2
  ↓
mysql-service :3306
  ↓
MySQL StatefulSet × 1 + Azure Disk PVC
```

## 배포 순서

각 디렉터리는 별도 Terraform 상태로 관리하는 것을 권장합니다.

```bash
export ARM_SUBSCRIPTION_ID='<subscription-id>'
export TF_VAR_subscription_id="$ARM_SUBSCRIPTION_ID"

cd 00-bootstrap
terraform init
terraform plan
terraform apply

cd ../10-network-security
terraform init
terraform plan
terraform apply

cd ../20-aks-platform
terraform init
terraform plan \
  -var='ssh_public_key=ssh-rsa AAAA...'
terraform apply \
  -var='ssh_public_key=ssh-rsa AAAA...'

cd ../30-platform-addons
terraform init
terraform plan
terraform apply
```

## 이미지 Build 위치

컨테이너 이미지는 AKS Worker Node에서 만들지 않습니다.

```text
GitHub Source
   ↓
Azure DevOps Agent 또는 Jenkins Agent
   ├─ docker build
   ├─ docker tag
   └─ docker push
   ↓
Azure Container Registry
   ↓
AKS가 이미지를 Pull하여 Pod 실행
```

수동 Build 예시는 다음과 같습니다.

```bash
ACR_NAME=acraksent01dev
ACR_SERVER="${ACR_NAME}.azurecr.io"

az acr login --name "$ACR_NAME"

docker build \
  -t "$ACR_SERVER/tc01/apache:v1.0" \
  apps/legacy-app/apache

docker build \
  -t "$ACR_SERVER/tc01/tomcat:v1.0" \
  apps/legacy-app/tomcat

docker push "$ACR_SERVER/tc01/apache:v1.0"
docker push "$ACR_SERVER/tc01/tomcat:v1.0"
```

## Kubernetes 배포

Manifest의 `ACR_LOGIN_SERVER`를 실제 ACR 주소로 치환합니다.

```bash
ACR_SERVER=acraksent01dev.azurecr.io
sed "s#ACR_LOGIN_SERVER#$ACR_SERVER#g" \
  deploy/tc01/legacy-stack.yaml \
  > deploy/tc01/legacy-stack.rendered.yaml

az aks get-credentials \
  --resource-group rg-aks-ent01-dev-krc \
  --name aks-aks-ent01-dev-krc \
  --overwrite-existing

kubectl apply -f deploy/tc01/legacy-stack.rendered.yaml
kubectl get pods,svc,pvc -n tc01
```

## 접속 확인

```bash
kubectl get service apache-service -n tc01
kubectl get endpoints apache-service -n tc01
kubectl get endpoints tomcat-service -n tc01
```

`apache-service`의 External IP를 브라우저에서 열면 Apache가 Tomcat으로 요청을 전달하며, 페이지에 처리한 Tomcat Pod 이름이 표시됩니다.

## 보안 주의

`deploy/tc01/legacy-stack.yaml`의 MySQL 비밀번호는 PoC용 Placeholder입니다. 실제 사용 시 다음 방식으로 변경해야 합니다.

- Azure Key Vault
- Secrets Store CSI Driver
- Workload Identity
- Git 저장소에 평문 Secret 저장 금지

## 2차 테스트 권장

TC-01 완료 후 MySQL StatefulSet을 Azure Database for MySQL Flexible Server로 교체하여 다음을 비교합니다.

- DB 운영 부담
- 백업 및 Point-in-Time Restore
- 장애조치
- Private DNS와 사설 연결
- 애플리케이션 연결 문자열 변경 범위
