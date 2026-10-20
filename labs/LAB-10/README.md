# LAB-10-OBSERVABILITY — İleri Gözlemlenebilirlik: Prometheus, Grafana, Alertmanager ve SRE (SLI/SLA/SLO) Yönetimi

> [!IMPORTANT]
> ## Ortam Ön Koşulu — Kind için inotify sınırı
>
> Aynı makinede başka bir Kind/Kubernetes kümesi veya çok sayıda konteyner çalışıyorsa, Kind düğümleri `Too many open files` hatasıyla başlayamayabilir. LAB-10'a başlamadan önce bu sınırı yükseltin:
>
> ```bash
> sudo sysctl -w fs.inotify.max_user_instances=512
> printf 'fs.inotify.max_user_instances = 512\n' | sudo tee /etc/sysctl.d/99-novashop-kind.conf >/dev/null
> sudo sysctl --system
> ```
>
> Doğrulama:
>
> ```bash
> sysctl fs.inotify.max_user_instances
> # Beklenen: fs.inotify.max_user_instances = 512
> ```
>
> ### İsteğe bağlı: 8 GiB swap alanı
>
> Swap, RAM'in yerine geçmez; disk üzerinde ek bellek alanıdır. 8 GiB'tan az RAM'i olan veya aynı anda ELK, Jenkins ve birden fazla Kind kümesi çalıştıran eğitim makinelerinde kullanılabilir. Mevcut swap alanını önce kontrol edin:
>
> ```bash
> free -h
> swapon --show
> ```
>
> `/swapfile` henüz etkin değilse aşağıdaki komutlar 8 GiB swap oluşturur ve yeniden başlatmalarda etkin kalmasını sağlar:
>
> ```bash
> if ! swapon --show=NAME | grep -qx '/swapfile'; then
>   if [ ! -e /swapfile ]; then sudo fallocate -l 8G /swapfile; fi
>   sudo chmod 600 /swapfile
>   sudo mkswap /swapfile
>   sudo swapon /swapfile
> fi
> grep -qF '/swapfile none swap sw 0 0' /etc/fstab || \
>   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
> free -h
> ```

| Seviye | Profil / Araçlar | Açık Portlar |
|---|---|---|
| Orta - İleri | Prometheus, Grafana, Alertmanager, Jaeger, OTel | 19090 (Prometheus), 13000 (Grafana), 16686 (Jaeger), 4466 (OTel ingest) |

> **Komutların çalışma dizini:** Aşağıdaki `scripts/...`, `deploy/...` ve `charts/...` yolları repo köküne göredir. Komutlardan önce `cd ~/novashop` çalıştırın. LAB-10 klasörünün içindeyseniz `cd ../..` ile köke dönün.

---

### Amaç

NovaShop mikroservis ekosistemindeki tüm servisleri (**UI, Catalog, Cart, Orders, Checkout**); **Prometheus** ile zaman serisi metrik toplama (RED ve USE metotları), **Grafana** ile operasyonel izleme panoları ve canlı alarm kuralları tanımlama, **Alertmanager** ile çok kanallı alarm yönlendirme ve kontrollü yük oluşturarak **SRE Hizmet Seviyesi Hedefleri (SLO)** ile **Hata Bütçesi (Error Budget)** yönetimini hem komut satırından (CLI) hem de web kullanıcı arayüzünden (UI) uçtan uca doğrulamaktır.

Laboratuvarın **Bonus Bölümü** ile mikroservisler arası istek yolculuklarını izleyen **OpenTelemetry (OTel) Collector & Jaeger Distributed Tracing** altyapısı incelenir.

---

### Gözlemlenebilirlik ve SRE Temel İlkeleri

Modern bulut-yerlisi sistemlerin izlenmesinde 3 temel sütun ve 2 metodoloji esastır:

#### 1. Gözlemlenebilirliğin 3 Temel Sütunu (The Three Pillars)
* **Metrikler (Metrics):** Zaman içinde toplanan sayısal verilerdir (CPU %, istek sayısı, gecikme). Sistemin *"Şu anda bir sorun var mı?"* sorusuna en hızlı ve en hafif cevabı verir (Prometheus).
* **Günlükler (Logs):** Belirli bir zaman damgasında gerçekleşen tekil olay kayıtlarıdır. *"Ne oldu, hata mesajı nedir?"* sorusunu yanıtlar (ELK Stack / LAB-11).
* **İzler (Traces):** Tek bir kullanıcı isteğinin mikroservisler arasındaki uçtan uca yolculuğudur. *"Gecikme hangi mikroserviste ve hangi SQL sorgusunda yaşandı?"* sorusunu yanıtlar (Jaeger / OpenTelemetry).

#### 2. RED Metodu (Mikroservis ve İstek Odaklı İzleme)
* **R — Rate (İstek Hızı):** Saniyedeki istek sayısı (Requests per Second - RPS).
* **E — Errors (Hata Oranı):** Başarısız istek sayısı (özellikle HTTP 5xx ve 4xx durum kodları).
* **D — Duration (Gecikme / Süre):** İsteklerin yanıtlanma süresi (p50, p90, p95, p99 persentilleri).

#### 3. USE Metodu (Altyapı ve Kaynak Odaklı İzleme)
* **U — Utilization (Kullanım):** Kaynağın kullanım yüzdesi (Örn: %75 CPU, %80 RAM doluluğu).
* **S — Saturation (Doygunluk):** İşlenemeyip kuyrukta bekleyen iş miktarı (CPU Load Average, Disk I/O Wait).
* **E — Errors (Hatalar):** Donanım veya çekirdek düzeyindeki hata sayaçları (Ağ paket düşmesi, disk I/O hatası).

#### 4. SRE Sözlüğü (SLI, SLO, SLA, Error Budget)
* **SLI (Service Level Indicator):** Ölçülen anlık gerçek performans metriği (Örn: *"Son 30 günde 200 dönen isteklerin oranı %99.78"*).
* **SLO (Service Level Objective):** Mühendislik ekibinin kendi kendine koyduğu iç kalite hedefi (Örn: *"Aylık başarı oranı en az %99.5 olmalıdır"*).
* **SLA (Service Level Agreement):** Müşteriler veya iş birimleriyle yapılan yasal taahhüt (Örn: *"Aylık başarı %99.0'ın altına düşerse %15 fatura iadesi yapılır"*).
* **Hata Bütçesi (Error Budget):** İzin verilen maksimum hata payı:
  $$\text{Error Budget} = 100\% - \text{SLO} = 100\% - 99.5\% = \%0.5$$
* **Burn Rate:** Hata bütçesinin harcanma hızı. 1x normal tüketimi, 14.4x ise bütçenin birkaç saat içinde tükeneceğini ve acil müdahale gerektiğini belirtir.

---

### Ön Koşullar ve Hızlı Hazırlık

NovaShop ekosistemindeki 5 mikroservisi (**UI, Catalog, Cart, Orders, Checkout**) aşağıdaki aşamaları sırayla izleyerek ayrı `novashop-cluster` kümesine dağıtın. Küme düğümleri `Ready` olmadan namespace ve Helm kurulumuna geçmeyin:

```bash
cd ~/novashop
set -e

# 1. LAB-10 kümesini oluşturun. Varsa yeniden oluşturmaz; diğer cluster'lara dokunmaz.
if ! kind get clusters | grep -qx novashop-cluster; then
  kind create cluster --config deploy/k8s/kind-cluster-config.yaml
fi

# 2. kubectl'i LAB-10 kümesine yönlendirin.
kubectl config use-context kind-novashop-cluster

# 3. Tüm düğümler hazır olana kadar bekleyin; sonra durumlarını kontrol edin.
kubectl wait --for=condition=Ready nodes --all --timeout=5m
kubectl get nodes -o wide

# 4. Namespace'i hazırlayın.
kubectl get namespace novashop >/dev/null 2>&1 || kubectl create namespace novashop

# 5. Beş servisi dağıtın; pod'lar hazır değilse Helm 10 dakikaya kadar bekler.
helm upgrade --install novashop charts/novashop \
  --namespace novashop --wait --timeout 10m

# 6. Kurulum sonucunu doğrulayın.
kubectl get pods -n novashop -o wide
```

Kurulum betiğini tercih ederseniz `bash scripts/setup-kind-cluster.sh` aynı işlemleri yapar; düğümlerin `Ready` olmasını beklemeden dağıtıma geçmez.

#### Kubernetes Cluster Seçimi

`kind-novashop-cluster` yalnızca LAB-10 için oluşturulmuştur. Diğer lablarda mevcut `kind-k8s-labs` cluster'ını kullanın. Aktif context'i ve kullanılabilir cluster'ları görmek için:

```bash
kubectl config get-contexts
```

Önceki/diğer lab cluster'ına geçiş:

```bash
kubectl config use-context kind-k8s-labs
kubectl config current-context
```

LAB-10 cluster'ına geri dönmek için:

```bash
kubectl config use-context kind-novashop-cluster
kubectl config current-context
```

Beklenen context listesi (aktif olan satırdaki `*` işaretlidir):

```text
CURRENT   NAME                    CLUSTER                 AUTHINFO
          kind-k8s-labs           kind-k8s-labs           kind-k8s-labs
*         kind-novashop-cluster   kind-novashop-cluster   kind-novashop-cluster
```

#### Mikroservis Endpoint ve Metrik Port Eşleme Tablosu

| Mikroservis | Teknoloji | NodePort | Doğrudan Erişim | Metrik Endpoint'i |
|---|---|:---:|---|---|
| **`novashop-ui`** | Java 21 / Spring Boot | `30080` | `http://localhost:30080` | `/actuator/prometheus` |
| **`novashop-catalog`** | Go / Gin | `30081` | `http://localhost:30081` | `/metrics` |
| **`novashop-cart`** | Java 21 / Spring Boot | `30082` | `http://localhost:30082` | `/actuator/prometheus` |
| **`novashop-orders`** | Java 21 / Spring Boot | `30083` | `http://localhost:30083` | `/actuator/prometheus` |
| **`novashop-checkout`** | Node.js / Express | `30085` | `http://localhost:30085` | `/metrics` |

---

### Mimari

[![LAB-10 gözlemlenebilirlik mimarisi — tam boyut için görsele tıklayın](architecture-lab10.jpg)](architecture-lab10.jpg)

NovaShop servis metrikleri, Node Exporter ve cAdvisor Prometheus'a gider; Grafana panoları Prometheus'tan beslenir ve Prometheus alarmları Alertmanager'a yönlendirir. Dağıtık izler OTel Collector üzerinden Jaeger UI'da incelenir.

---

### Erişim Modelleri ve Kimlik Bilgileri

| Servis | Model B: Kurumsal DNS + SSL | Model A: Doğrudan IP:Port | Kullanıcı Adı | Parola |
|---|---|---|:---:|:---:|
| **Grafana Panosu** | `http://<SUNUCU_IP>:13000` | Port `13000` | `admin` | `.env` içindeki `GRAFANA_ADMIN_PASSWORD` |
| **Prometheus Web UI** | `http://<SUNUCU_IP>:19090` | Port `19090` | - | Kimlik doğrulama yok |
| **Jaeger UI (Tracing)** | `http://<SUNUCU_IP>:16686` | Port `16686` | - | Kimlik doğrulama yok |
| **OTel trace alıcısı** | `http://<SUNUCU_IP>:4466/v1/traces` | Port `4466` | - | Eğitim ağı erişimi |

Alertmanager, Node Exporter ve cAdvisor host portu yayınlamaz; yalnızca Compose'un özel ağında erişilir. Bu, Nginx port listesini ve mevcut servisleri korur.

---

## Adım Adım Uygulama Rehberi (CLI & UI)

---

### BÖLÜM 1: Komut Satırından (CLI) Otomasyon ve Kurulum

#### 1.1 Gözlemlenebilirlik Profilini Başlatma

```bash
cd ~/novashop
if [ ! -f .env ]; then
  cp config/project.env.example .env
  sed -i "s|^GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=$(openssl rand -hex 24)|" .env
fi
chmod 600 .env

# Compose yapılandırmasını doğrulayın, ardından Prometheus/Grafana/Jaeger yığınını başlatın:
bash scripts/compose-observability.sh config
bash scripts/compose-observability.sh up
```

**Konteyner Durumlarını Denetleyin:**
```bash
bash scripts/compose-observability.sh ps
```
*Beklenen konteynerler:* `novashop-prometheus`, `novashop-grafana`, `novashop-alertmanager`, `novashop-node-exporter`, `novashop-cadvisor`.

---

#### 1.2 5 Mikroservisin Prometheus Scrape Hedeflerini Doğrulama (CLI)

Tüm mikroservislerin Prometheus tarafından başarıyla dinlendiğini terminalden API ile sorgulayın:

```bash
curl -s http://localhost:19090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health) (\(.scrapeUrl))"'
```

*Beklenen çıktı:*
```text
prometheus: up (http://localhost:9090/metrics)
node-exporter: up (http://node-exporter:9100/metrics)
cadvisor: up (http://cadvisor:8080/metrics)
novashop-ui: up (http://host.docker.internal:30080/actuator/prometheus)
novashop-catalog: up (http://host.docker.internal:30081/metrics)
novashop-cart: up (http://host.docker.internal:30082/actuator/prometheus)
novashop-orders: up (http://host.docker.internal:30083/actuator/prometheus)
novashop-checkout: up (http://host.docker.internal:30085/metrics)
```
Tüm servislerin **up** olduğunu ve hiçbir servisin kırmızı (down) olmadığını teyit edin.

---

#### 1.3 Yapay Trafik Simülatörünü Başlatma

Metriklerin Grafana üzerinde canlı dalgalanması için arka planda istek üreten simülatörü çalıştırın:

```bash
# E-ticaret sipariş, sepet ve gezinme trafiği üretir:
python3 scripts/simulate-traffic.py &
```

---

### BÖLÜM 2: Prometheus Web Arayüzü (UI) Kullanımı

1. Tarayıcınızdan `http://<SUNUCU_IP>:19090` adresine gidin.
2. Üst menüden **Status > Targets** sayfasına tıklayın:
   - `novashop-ui`, `novashop-catalog`, `novashop-cart`, `novashop-orders`, `novashop-checkout` hedeflerinin yeşil **UP (1/1)** olduğunu gözlemleyin.
3. Üst menüden **Graph** sekmesine geçin.

#### Kritik PromQL Sorgu Kütüphanesi:

Aşağıdaki sorguları `Expression` alanına yapıştırıp **Execute** butonuna basın ve **Graph** sekmesinde zaman serisi eğrilerini inceleyin:

* **Servis Başına İstek Hızı (RED - Rate / RPS):**
  ```promql
  sum by (job) (rate(http_server_requests_seconds_count[1m]))
  ```
* **HTTP 5xx Hata Oranı Yüzdesi (RED - Errors):**
  ```promql
  (sum(rate(http_server_requests_seconds_count{status=~"5.."}[1m])) / sum(rate(http_server_requests_seconds_count[1m]))) * 100
  ```
* **p95 Yanıt Gecikmesi (RED - Duration):**
  ```promql
  histogram_quantile(0.95, sum by (job, le) (rate(http_server_requests_seconds_bucket[1m])))
  ```
* **Host CPU Doluluk Oranı (USE - Utilization):**
  ```promql
  100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)
  ```
* **Host Kullanılabilir Bellek Yüzdesi (USE - Memory):**
  ```promql
  (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
  ```

---

### BÖLÜM 3: Grafana Web Arayüzü (UI) — Manuel Pano ve Alarm Oluşturma

1. Tarayıcınızda `http://<SUNUCU_IP>:13000` adresini açın.
2. Kullanıcı adı `admin`, şifre `.env` içindeki `GRAFANA_ADMIN_PASSWORD` değeridir.

#### 3.1 Arayüzden Sıfırdan Yeni Dashboard ve Panel Oluşturma (Manuel)

1. Sol menüden **Dashboards** sekmesine gelin, sağ üstteki **New > New Dashboard** butonuna tıklayın.
2. Açılan ekranda **+ Add visualization** seçeneğine tıklayın.
3. Veri kaynağı (Data source) olarak **Prometheus** seçin.
4. **Panel 1: Canlı İstek Hızı (Time Series):**
   - **Query (A):** `sum by (job) (rate(http_server_requests_seconds_count[1m]))`
   - **Legend:** `{{job}}`
   - Sağ panelden **Panel options > Title:** `Mikroservis İstek Hızları (RPS)` yazın.
   - Sağ üstteki **Apply** butonuna tıklayın.
5. **Panel 2: Toplam Başarılı İstek Sayacı (Stat Paneli):**
   - Dashboard'a dönüp **+ Add > Visualization** deyin.
   - **Query (A):** `sum(http_server_requests_seconds_count{status=~"2.."})`
   - Sağ paneldeki panel tipini **Time series** yerine **Stat** olarak değiştirin.
   - **Title:** `Toplam Başarılı İşlem (HTTP 200)` yazın ve **Apply** deyin.
6. **Panel 3: CPU Kullanım Kadranı (Gauge Paneli):**
   - **Query (A):** `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)`
   - Panel tipini **Gauge** seçin.
   - Sağ taraftaki **Standard options > Unit** alanından **Percent (0-100)** seçin.
   - **Thresholds:** `80` sarı, `90` kırmızı belirleyin.
   - **Title:** `Sunucu CPU Tüketimi` yazın ve **Apply** deyin.
7. Sağ üstteki **Disket (Save dashboard)** simgesine basarak panonuzu `NovaShop Canlı İzleme` adıyla kaydedin.

---

#### 3.2 Arayüzden Manuel Alarm Kuralı (Alert Rule) Tanımlama

1. Sol menüden **Alerting > Alert rules** sayfasına gidin.
2. **+ New alert rule** butonuna tıklayın:
   - **Rule name:** `NovaShopHighErrorRateAlert`
   - **Query (A):**
     ```promql
     sum(rate(http_server_requests_seconds_count{status=~"5.."}[1m])) / sum(rate(http_server_requests_seconds_count[1m])) * 100
     ```
   - **Condition (C):** `Input: A`, `IS ABOVE: 5` (Hata oranı %5'in üzerine çıkarsa alarm ver).
   - **Evaluation interval:** `1m` (Her 1 dakikada bir kontrol et).
   - **Folder:** `NovaShop Alerts` oluşturun.
   - **Rule group:** `ecommerce-errors` yazın.
3. Sayfanın en altındaki **Save rule and exit** butonuna basarak kuralı aktifleştirin.

---

#### 3.3 Hazır Dashboard JSON Dosyalarını İçe Aktarma (Import)

Hazır profesyonel panoları tek tıkla Grafana'ya yükleyin:

1. Sol menüden **Dashboards > New > Import** yolunu izleyin.
2. **Upload dashboard JSON file** butonuna tıklayarak depodaki şu dosyaları yükleyin:
   - `deploy/observability/grafana/provisioning/dashboards/json/novashop-services-overview.json`
   - `deploy/observability/grafana/provisioning/dashboards/json/docker-container-host-overview.json`
3. Veri kaynağı olarak **Prometheus** seçin ve **Import** butonuna basın.
4. Tüm mikroservislerin RED metrikleri, e-ticaret sepet verileri ve alarm listeleri tek bir ekranda belirecektir.

---

### BÖLÜM 4: SRE Uygulaması — SLI, SLO ve Hata Bütçesi Hesaplama

Grafana'da açtığınız panoya yeni bir **Gauge** paneli ekleyin:

1. **SLO Formülü (PromQL):**
   ```promql
   (sum(rate(http_server_requests_seconds_count{status!~"5.."}[30d])) 
   / 
   sum(rate(http_server_requests_seconds_count[30d]))) * 100
   ```
2. **Threshold Eşikleri:**
   - `0 - 99.0`: Kırmızı (SLA İhlali — Müşteriye ceza/iade riski)
   - `99.0 - 99.9`: Sarı (SLO İhlal Riski — Hata Bütçesi tükeniyor)
   - `99.9 - 100.0`: Yeşil (SLO Başarılı — Sistem sağlıklı)

#### Kontrollü Hata Bütçesi Tüketme Deneyi:
Terminalden bilerek 500 hataları üreterek hata bütçesini eritin ve Grafana kadranının sarıya/kırmızıya döndüğünü gözlemleyin:
```bash
for i in {1..50}; do curl -s http://localhost:30080/api/invalid-endpoint > /dev/null & done
```

---

### BÖLÜM 5: Bonus Dağıtık İzleme (OpenTelemetry & Jaeger Tracing)

Kullanıcı tek bir satın alma işlemi yaptığında istek arka planda `UI -> Cart -> Orders -> Checkout` zincirini takip eder.

1. **Örnek Dağıtık İz Üretme (CLI):**
   ```bash
   python3 scripts/generate-sample-traces.py
   ```
2. **Jaeger Web Arayüzünde Şelale (Waterfall) Analizi:**
   - Tarayıcınızda `http://<SUNUCU_IP>:16686` adresini açın.
   - **Service:** `novashop-checkout` seçin ve **Find Traces** butonuna tıklayın.
   - Gelen span bloklarına tıklayarak sürenin kaç milisaniyesinin HTTP ağ gecikmesinde, kaç milisaniyesinin iç işlemde harcandığını waterfall diyagramında analiz edin.

---

### Doğrulama ve Cleanup

`scripts/...` komutları yalnızca repo kökünde çalışır. Terminal `~/novashop/labs/LAB-10` içindeyse iki kez `cd ..` yapmayın; doğrudan repo köküne dönün:

```bash
cd ~/novashop
pwd
# Beklenen: /home/student/novashop

# 1. Otomatik laboratuvar doğrulama testini çalıştırın:
bash scripts/verify/verify-lab-10.sh 30080 localhost

# 2. Çalışma bittiğinde kaynakları serbest bırakın:
# Bu komut sadece Docker Compose gözlemlenebilirlik servislerini kapatır; Kind cluster'ını silmez.
bash scripts/compose-observability.sh down
```
