# NovaShop DevOps, Cloud & DevSecOps Labs

NovaShop e-ticaret platformu üzerinde adım adım uygulanan, kurumsal standartlara uygun uygulamalı laboratuvarlar serisi.

Tüm laboratuvarlar **Ubuntu sunucusu** üzerinde koşar ve iki erişim modelini (`Doğrudan IP:Port` ve `Kurumsal DNS+SSL`) destekler.

---

## Laboratuvar Yol Haritası (LAB-00 - LAB-14)

> [!NOTE]
> **Çalışma ve Ortam Kılavuzu:**
> - **Çekirdek Laboratuvarlar (`*` işaretli):** Platformun omurgasını oluşturan temel modüllerdir.
> - **Yerel Ortam Laboratuvarları (`LAB-00`, `LAB-01`, `LAB-03`, `LAB-06`, `LAB-07`, `LAB-08`, `LAB-09`, `LAB-10`, `LAB-11`):** Harici bulut hesabı gerektirmez; yerel Docker motoru, Kind Kubernetes kümesi ve sistem araçları üzerinde koşar.
> - **AWS Cloud Laboratuvarları (`LAB-02`, `LAB-04`, `LAB-05`, `LAB-12`, `LAB-13`, `LAB-14`):** Canlı AWS hesabı, IAM API anahtarları veya AWS kredisi gerektirir.
> - **Bellek ve Kaynak Yönetimi:** Sunucu kaynaklarını korumak için bağımlı olmayan profilleri tamamlandığında durdurunuz (`docker compose stop`). `LAB-11` (ELK) öncesinde önceki ağır servisleri kapatmanız önerilir.
> - **Port Eşleme Standardı:** NovaShop Storefront UI kurumsal platform matrisinde `19001` (App1 slotu) ve `8888` (yerel) portlarından yayınlanır; Kind üzerinde ise NodePort `30080` ile sunulur.

| No | Laboratuvar | Başlık | Kapsam / Ana Konular | Rehber Bağlantısı |
| :---: | :--- | :--- | :--- | :--- |
| **00** | [LAB-00](LAB-00-PLATFORM-SETUP/README.md) | Platform Kurulumu & DevOps Araçları | GitLab CE, Harbor OCI Registry, SonarQube, Jenkins, Nginx Reverse Proxy | [LAB-00 Rehberi](LAB-00-PLATFORM-SETUP/README.md) |
| **01** | **[LAB-01*](LAB-01/README.md)** | Git & GitHub Temelleri | Branch yönetimi, PR, izole merge conflict çözümü (`products.json`), PAT yapılandırması | [LAB-01 Rehberi](LAB-01/README.md) |
| **02** | [LAB-02](LAB-02/README.md) | AWS 2-Tier Altyapı | VPC, EC2 Web, Single-AZ RDS MySQL, Güvenlik Grupları, Terraform IaC | [LAB-02 Rehberi](LAB-02/README.md) |
| **03** | **[LAB-03*](LAB-03/README.md)** | Docker & Docker Compose | Multi-stage build (Java 21), non-root appuser güvenliği, Compose overlay (`starter.secure.yml`) | [LAB-03 Rehberi](LAB-03/README.md) |
| **04** | [LAB-04](LAB-04/README.md) | AWS 3-Tier Production | Production compose, Nginx reverse proxy, TLS, CloudWatch loglama | [LAB-04 Rehberi](LAB-04/README.md) |
| **05** | **[LAB-05*](LAB-05/README.md)** | GitHub Actions CI/CD | Docker Hub / ECR imaj dağıtımı, automated release, rollback mekanizması | [LAB-05 Rehberi](LAB-05/README.md) |
| **06** | **[LAB-06*](LAB-06/README.md)** | Kubernetes Core & Helm | Kind K8s kümesi, Pods, Services, Traefik Ingress, Helm Chart mikroservis dağıtımı | [LAB-06 Rehberi](LAB-06/README.md) |
| **07** | **[LAB-07*](LAB-07/README.md)** | Kurumsal CI/CD Hattı | GitLab CI, Jenkins, Docker-in-Docker derleme, Harbor Private Registry & Immutable Tags | [LAB-07 Rehberi](LAB-07/README.md) |
| **08** | **[LAB-08*](LAB-08/README.md)** | DevSecOps Güvenlik Kapıları | SonarQube SAST, Trivy imaj ve dosya taraması, Secret scanning, CycloneDX SBOM üretimi | [LAB-08 Rehberi](LAB-08/README.md) |
| **09** | **[LAB-09*](LAB-09/README.md)** | GitOps & Argo CD | Declarative GitOps, continuous reconciliation, self-healing, automated sync | [LAB-09 Rehberi](LAB-09/README.md) |
| **10** | **[LAB-10*](LAB-10/README.md)** | Observability & İzleme | Prometheus metrikleri, Grafana panoları, OpenTelemetry / Jaeger trace, SLO yönetimi | [LAB-10 Rehberi](LAB-10/README.md) |
| **11** | **[LAB-11*](LAB-11/README.md)** | Merkezi Loglama (ELK Stack) | Fluent Bit, Elasticsearch, Kibana; Docker mikroservisleri, K8s podları ve host logları | [LAB-11 Rehberi](LAB-11/README.md) |
| **12** | **[LAB-12*](LAB-12/README.md)** | Terraform IaC (Altyapı Kod Olarak) | Modüler Terraform, AWS EC2, RDS MySQL, Cloud-Init, plan/apply/idempotency | [LAB-12 Rehberi](LAB-12/README.md) |
| **13** | [LAB-13](LAB-13/README.md) | Kurumsal Amazon EKS | Managed NodeGroups, eksctl, IRSA IAM rolleri, AWS Load Balancer Controller | [LAB-13 Rehberi](LAB-13/README.md) |
| **14** | [LAB-14](LAB-14/README.md) | Amazon ECS Fargate | Serverless konteynerler, ALB, CloudWatch Container Insights, Blue/Green CI/CD | [LAB-14 Rehberi](LAB-14/README.md) |

