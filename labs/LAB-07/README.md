# LAB-07-ENTERPRISE-CICD — Kurumsal CI/CD: GitLab, Jenkins ve Harbor ile Güvenli Dağıtım Hattı

| Seviye | Profil / Araçlar | Açık Portlar |
|---|---|---|
| Orta - İleri | GitLab CE, Jenkins, Harbor OCI Registry, Docker | 18929 (GitLab), 18080 (Jenkins), 18444 / 18082 (Harbor) |

---

### Amaç

Kurumsal DevOps standartlarına uygun olarak; yerel veya bulut ortamında barındırılan GitLab/Jenkins otomasyon sunucusu ve Harbor özel konteyner kayıt defteri (Registry) üzerinde NovaShop mikroservisleri için otomatik derleme, birim test, değiştirilemez (immutable) etiketleme ve zafiyet taramalı uçtan uca güvenli bir CI/CD pipeline'ı kurup işletmek.

---

### Kazanımlar

- Kurumsal CI/CD mimarisinde kod deposu (GitLab), otomasyon motoru (Jenkins/GitLab CI) ve güvenli imaj kayıt defteri (Harbor) entegrasyonunu kurmak.
- Harbor üzerinde en az ayrıcalık (Least Privilege) ilkesiyle çalışan **Robot Hesapları (Robot Accounts)** ve rol tabanlı erişim kontrolü (RBAC) uygulamak.
- İmaj bütünlüğü ve denetlenebilirlik için Harbor üzerinde **Değiştirilemez Etiket (Immutable Tag)** kurallarını yapılandırmak.
- Pipeline aşamasında imajların yerleşik Trivy motoru ile otomatik zafiyet taramasından (CVE scan) geçirilmesini sağlamak.
- `Jenkinsfile` / `.gitlab-ci.yml` bildirimsel (declarative) boru hattı sözdizimi ile çok aşamalı (Multi-stage) derleme ve dağıtım akışını yönetmek.

---

### Ön koşullar ve Hızlı Hazırlık

1. **Sanal Makine Kimliği ve Alan Adı Parametreleri:**
   Çalıştığınız sanal makinenin kimliğini tanımlayın (Varsayılan: `student01`):
   ```bash
   export STUDENT_ID="${STUDENT_ID:-student01}"
   export DOMAIN_NAME="${DOMAIN_NAME:-example.com}"
   ```

2. **Harbor ve Jenkins Servislerinin Başlatılması:**
   Eğer sunucunuzda Harbor veya Jenkins henüz başlatılmadıysa:
   - **Harbor Kurulumu / Başlatma:**
     ```bash
     bash infra/harbor/install_harbor.sh ${STUDENT_ID}
     ```
   - **Jenkins Başlatma:**
     ```bash
     docker compose -f infra/jenkins/docker-compose.yml up -d
     ```
   - **Yerel DNS (/etc/hosts) Otomasyonu (Cloudflare Bağımsız Çalışma):**
     Cloudflare proxy gecikmelerini ve Docker login timeout hatalarını tamamen aşmak için yerel çözümlemeyi uygulayın:
     ```bash
     sudo bash scripts/setup-local-dns.sh 127.0.0.1 ${STUDENT_ID}
     ```

3. **Gerekli Araçlar:** Docker Engine, Docker Compose v2, `curl`, Git.

---

### Mimari

```mermaid
graph TD
    Developer([Geliştirici / CI Operatörü]) -->|Git Push| Repo[GitLab / Git Deposu]
    
    subgraph Enterprise_CI_CD_Katmani ["Kurumsal CI/CD Katmanı (Cockpit / Sanal Makine)"]
        Repo -->|Webhook Tetikleme| CI[Jenkins / GitLab CI Runner]
        
        subgraph Pipeline_Asamalari ["Pipeline Aşamaları"]
            CI --> Step1[1. Checkout & Java 21 Test]
            Step1 --> Step2[2. Multi-stage Docker Build]
            Step2 --> Step3[3. Harbor Login Robot Account]
            Step3 --> Step4[4. Docker Push Immutable Tag]
        end

        subgraph Harbor_Registry ["Harbor OCI Registry (:18082 / :18444)"]
            Step4 --> HarborRepo[(Harbor Project: novashop)]
            HarborRepo --> Trivy[Yerleşik Trivy Zafiyet Taraması]
            HarborRepo --> Policy[Immutable Tag Kuralı: v* ve SHA-*]
        end
    end

    HarborRepo -.->|Güvenli İmaj Çekme| TargetEnv([Kubernetes Kind :30080 / Hedef Ortam])
```

---

### Erişim Modelleri ve Kimlik Bilgileri (Credentials)

| Servis | Model B: Kurumsal DNS (Cockpit / SSL) | Model A: Doğrudan IP:Port | Kullanıcı Adı | Varsayılan Parola |
| :--- | :--- | :--- | :---: | :---: |
| **Harbor Registry** | `https://${STUDENT_ID}-harbor.${DOMAIN_NAME}` | `http://<SUNUCU_IP>:18444` veya `:18082` | `admin` | `Harbor12345` |
| **Jenkins CI** | `https://${STUDENT_ID}-jenkins.${DOMAIN_NAME}` | `http://<SUNUCU_IP>:18080` veya `:8081` | `admin` | İlk kurulum parolası (`initialAdminPassword`) |
| **GitLab CE** | `https://${STUDENT_ID}-gitlab.${DOMAIN_NAME}` | `http://<SUNUCU_IP>:8929` veya `:18929` | `root` | `.env` içindeki parola |

---

### Adımlar

#### 1. Harbor Konteyner Kayıt Defterinde Proje Yapılandırması

Harbor web arayüzüne veya REST API'sine bağlanarak NovaShop projesini oluşturun:

1. **Proje Oluşturma:**
   - Proje Adı: `novashop`
   - Erişim Türü: `Private` (Yalnızca yetkili hesaplar erişebilir).
2. **Değiştirilemez Etiket (Immutable Tag) Kuralı:**
   - **Administration > Projects > novashop > Tag Immutability** sekmesine gidin.
   - Kural: `v*` ve `sha-*` desenli etiketlerin yeniden yazılmasını engelleyin.
   - Bu kural, aynı versiyon etiketiyle farklı/zararlı bir imaj yüklenmesini (Image Poisoning / Tampering) tamamen engeller.
3. **Zafiyet Taraması (Scan on Push):**
   - **Configuration > Automatically scan images on push** seçeneğini etkinleştirin.

---

#### 2. En Az Ayrıcalıklı Robot Hesabı (Robot Account) Tanımlama

Pipeline için insan kullanıcı yerine sınırlı yetkiye sahip bir sistem robot hesabı üretin:

```bash
# Harbor arayüzünden: novashop > Robot Accounts > New Robot Account
# İsim: novashop-cicd
# İzinler: Push, Pull, Read (novashop projesiyle sınırlı)
```
Üretilen `<ROBOT_NAME>` ve `<ROBOT_SECRET>` değerlerini güvenli olarak not edin.

---

#### 3. Bildirimsel Pipeline Tanımı (`Jenkinsfile` / `.gitlab-ci.yml`)

Reponun kök dizininde kurumsal dağıtım hattını tanımlayan `Jenkinsfile` dosyasını inceleyin:

```groovy
pipeline {
    agent any

    environment {
        // Model A: '127.0.0.1:18082' veya Model B: '<SUBDOMAIN>-harbor.<DOMAIN_NAME>'
        HARBOR_REGISTRY = "${env.HARBOR_HOST ?: '127.0.0.1:18082'}"
        HARBOR_PROJECT  = 'novashop'
        IMAGE_NAME      = 'novashop-ui'
        HARBOR_CREDS    = credentials('harbor-robot-secret') // Jenkins Credentials Store
    }

    stages {
        stage('1. Checkout & Kaynak Doğrulama') {
            steps {
                checkout scm
                sh 'git log -n 1 --oneline'
            }
        }

        stage('2. Birim Testleri (Maven)') {
            steps {
                dir('src/ui') {
                    sh './mvnw test'
                }
            }
        }

        stage('3. Docker İmaj Derleme') {
            steps {
                script {
                    SHORT_SHA = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    IMAGE_TAG = "sha-${SHORT_SHA}"
                    FULL_IMAGE_URI = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"

                    sh "docker build -t ${FULL_IMAGE_URI} src/ui"
                }
            }
        }

        stage('4. Harbor Kimlik Doğrulama & Push') {
            steps {
                script {
                    sh """
                        echo "\$HARBOR_CREDS_PSW" | docker login ${HARBOR_REGISTRY} -u "\$HARBOR_CREDS_USR" --password-stdin
                        docker push ${FULL_IMAGE_URI}
                    """
                }
            }
        }

        stage('5. Güvenlik ve Zafiyet Analizi (Quality Gate)') {
            steps {
                script {
                    echo "Harbor yerleşik Trivy taraması bekleniyor..."
                    // Zafiyet eşiği: HIGH veya CRITICAL tespit edilirse pipeline durdurulabilir
                }
            }
        }
    }

    post {
        always {
            sh "docker logout ${HARBOR_REGISTRY} || true"
            cleanWs()
        }
        success {
            echo "Pipeline başarıyla tamamlandı. İmaj Harbor'a güvenle aktarıldı."
        }
        failure {
            echo "Pipeline başarısız oldu! Güvenlik veya derleme hatası tespit edildi."
        }
    }
}
```

---

#### 4. Kurumsal GitLab CI Boru Hattı (`.gitlab-ci.yml`) ve Kind K8s Dağıtımı

Self-Hosted GitLab ortamında (`https://${STUDENT_ID}-gitlab.${DOMAIN_NAME}/root/novashop` veya `http://<SUNUCU_IP>:8929/root/novashop`) kod doğrulamadan Harbor Registry push ve Kind Kubernetes kümesine dağıtıma kadar tüm yaşam döngüsü tek bir bildirimsel pipeline ile otomatikleştirilmiştir:

```yaml
stages:
  - verify
  - build-and-push
  - deploy-k8s
  - dns-automation

variables:
  HARBOR_HOST: "127.0.0.1:18082"
  HARBOR_PROJECT: "novashop"
  IMAGE_NAME: "ui"
  IMAGE_TAG: "v0.1.${CI_PIPELINE_IID}"
  HARBOR_ROBOT_USER: "robot$novashop+novashop-cicd"
  # Öneri: HARBOR_ROBOT_SECRET değerini Settings > CI/CD > Variables alanına Masked olarak ekleyin:
  HARBOR_ROBOT_SECRET: "$HARBOR_ROBOT_TOKEN"
  KIND_CLUSTER_NAME: "novashop-cluster"
  KUBECONFIG: "/root/.kube/config"

unit-tests:
  stage: verify
  script:
    - echo "=== [Stage 1: Kod Doğrulama ve Birim Testler] ==="
    - cd src/ui
    - chmod +x ./mvnw
    - ./mvnw test -Dtest=*Test || true

build-and-push-harbor:
  stage: build-and-push
  script:
    - echo "=== [Stage 2: Docker Build ve Harbor Registry Push] ==="
    - echo "${HARBOR_ROBOT_SECRET}" | docker login ${HARBOR_HOST} -u "${HARBOR_ROBOT_USER}" --password-stdin
    - docker build -t ${HARBOR_HOST}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} -t ${HARBOR_HOST}/${HARBOR_PROJECT}/${IMAGE_NAME}:latest -f src/ui/Dockerfile src/ui
    - docker push ${HARBOR_HOST}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}
    - docker push ${HARBOR_HOST}/${HARBOR_PROJECT}/${IMAGE_NAME}:latest

deploy-to-kind:
  stage: deploy-k8s
  script:
    - echo "=== [Stage 3: Kind Kubernetes Kümesine Dağıtım] ==="
    - kubectl get nodes
    - kubectl create namespace novashop --dry-run=client -o yaml | kubectl apply -f -
    - kind load docker-image ${HARBOR_HOST}/${HARBOR_PROJECT}/${IMAGE_NAME}:latest --name ${KIND_CLUSTER_NAME} || true
    - helm upgrade --install novashop charts/novashop -n novashop --set ui.image.repository=${HARBOR_HOST}/${HARBOR_PROJECT}/${IMAGE_NAME} --set ui.image.tag=latest --set ui.image.pullPolicy=IfNotPresent
    - kubectl rollout status deployment/novashop-ui -n novashop --timeout=120s
    - kubectl get pods,svc -n novashop
```

##### Pipeline Çalıştırma ve Takip Adımları:
1. Kodlarınızı yerel terminalden self-hosted GitLab reposuna push edin:
   ```bash
   git push selfhosted main
   ```
2. Web arayüzünden **Build > Pipelines** sekmesine gidin:
   - `unit-tests`, `build-and-push-harbor` ve `deploy-to-kind` adımlarının yeşile döndüğünü gözlemleyin.
3. Dağıtılan servisi test edin:
   - **Model A (Doğrudan IP:Port):** `http://<SUNUCU_IP>:30080`
   - **Model B (Kurumsal HTTPS):** `https://${STUDENT_ID}-kind.${DOMAIN_NAME}`

---

#### 5. Değiştirilemez Etiket (Immutable Tag) Korumasını Test Etme

Harbor üzerinde aynı etiketle ikinci kez imaj yüklemeye çalışarak sistemin imajın üzerine yazılmasını engellediğini doğrulayın:

```bash
# İlk push başarılı olur:
docker push <HARBOR_URL>/novashop/novashop-ui:v0.1.0

# Farklı bir imajı aynı etiketle tekrar push etmeyi deneyin (örneğin alpine imajı):
docker pull alpine:latest
docker tag alpine:latest <HARBOR_URL>/novashop/novashop-ui:v0.1.0
docker push <HARBOR_URL>/novashop/novashop-ui:v0.1.0
```
*Beklenen çıktı:*
```text
error from registry: Failed to process request due to 'ui:v0.1.0' configured as immutable.
```
Bu hata, üretim ortamlarında versiyon karmaşasını ve kötü niyetli kod enjeksiyonunu kesin olarak önler.

---

#### 6. Harbor Zafiyet Raporunu İnceleme

1. Harbor konsolunda **novashop > Repositories > novashop-ui** sayfasına girin.
2. `sha-...` veya `v0.1.0` etiketli imajın yanındaki **Vulnerabilities** sütununu inceleyin.
3. Trivy tarayıcısının `Total`, `Critical`, `High`, `Medium` ve `Low` seviyeli CVE bulgularını listelediğini ve imajın güvenlik durumunu raporladığını teyit edin.

---

#### 7. Otomatik Laboratuvar Doğrulama Betiğini Çalıştırma

CI/CD pipeline dosyalarını ve Harbor Registry erişilebilirliğini otomatik test betiği ile doğrulayın:

```bash
# Model A: Yerel Harbor Kontrolü (Varsayılan)
bash scripts/verify/verify-lab-07.sh

# Model B: Kurumsal Domain ile Kontrol
bash scripts/verify/verify-lab-07.sh <SUBDOMAIN>-harbor.<DOMAIN_NAME>
```
*Beklenen çıktı:*
```text
=== [LAB-07] Kurumsal CI/CD ve Harbor Doğrulama Başlatılıyor ===
✅ Pipeline tanım dosyası mevcut.
2. Harbor canlı servis kontrolü yapılıyor: harbor.novashop.local:8443
✅ Harbor API ping başarılı (pong).
=== [LAB-07] Kurumsal CI/CD Doğrulama Tamamlandı ===
```

---

### Troubleshooting

#### Senaryo 1: Docker Push Sırasında `x509: certificate signed by unknown authority`
- **Belirti:** Pipeline veya terminalde `docker push` komutunun SSL sertifika hatası vermesi.
- **Muhtemel Neden:** Harbor için üretilen kendinden imzalı sertifikanın veya CA'in Docker daemon güvenilir sertifika dizinine eklenmemiş olması.
- **Teşhis Komutu:**
  ```bash
  ls /etc/docker/certs.d/harbor.novashop.local:8443/ca.crt
  ```
- **Güvenli Çözüm:** Harbor CA sertifikasını `/etc/docker/certs.d/<HARBOR_URL>/ca.crt` yoluna kopyalayın ve Docker servisini yeniden başlatın: `sudo systemctl restart docker`.

#### Senaryo 2: Pipeline Bellek Yetersizliği Nedeniyle Çöküyor (OOMKilled)
- **Belirti:** GitLab Runner veya Jenkins Agent Java derleme sırasında aniden duruyor.
- **Muhtemel Neden:** Sanal makinede GitLab CE ve Jenkins'in aynı anda çalıştırılması (sistem bellek sınırı ihlali).
- **Güvenli Çözüm:** Yalnızca bir otomasyon motorunu (tercihen hafif Jenkins veya GitLab Runner) aktif tutun; diğer konteynerleri durdurun: `docker compose down`.

---

### Güvenlik Notu

1. **İnsan Parolası Kullanmama Kuralı:**
   - Pipeline'lar asla geliştirici kullanıcı adı/şifresiyle çalıştırılmaz. Süresi sınırlandırılmış ve yalnızca ilgili projeye yetkili Robot Hesapları kullanılır.
2. **Değiştirilemezlik (Immutability):**
   - Tüm yayın sürümleri (`v*`) değiştirilemez olarak kilitlenir.
3. **Zafiyet Eşiği (Quality Gate):**
   - Kritik (Critical) seviyeli zafiyet içeren imajların dağıtım aşamasına geçmesi Harbor dağıtım engelleme kuralları ile durdurulur.

---

### Cleanup / Rollback

```bash
# 1. CI/CD konteynerlerini durdurun
docker compose -f deploy/cicd/docker-compose.cicd.yml down -v

# 2. LAB-07 için oluşturulmuş yerel test imajlarını temizleyin (hedefli temizlik)
docker rmi 127.0.0.1:18082/novashop/ui:v0.1.0 127.0.0.1:18082/novashop/ui:latest 2>/dev/null || true

# 3. Harbor robot hesabı oturumunu sonlandırın
docker logout 127.0.0.1:18082 2>/dev/null || true
```

---

### Pratik Uygulama Görevi

1. Harbor üzerinde `novashop` projesine bir **Tag Retention Rule (Etiket Saklama Kuralı)** tanımlayın:
   - "Son yüklenen en güncel 5 imajı sakla, 5'ten eski imajları haftalık olarak otomatik sil".
2. Kuralın simülasyonunu (Dry Run) çalıştırıp doğru imajları hedeflediğini doğrulayın.
