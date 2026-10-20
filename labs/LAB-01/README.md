# LAB-01 — Git Temelleri, GitHub ve Kontrollü Merge Conflict Çözümü

| Seviye | Profil / Araçlar | Açık Portlar |
|---|---|---|
| Başlangıç | Git, GitHub, CLI | - |

---

## Amaç

Ubuntu sunucu ortamında Git sürüm kontrol sistemini sıfırdan başlatmak, GitHub üzerinde kişisel bir uzak depo oluşturup projeyi push etmek, bir feature branch açıp Pull Request (PR) süreci işletmek ve `labs/LAB-01/products.json` üzerinde kasıtlı oluşturulmuş bir merge conflict'i hem komut satırında hem de GitHub web arayüzünde gözlemleyip çözmek.

---

## Kazanımlar

1. Linux komut satırında `git init`, `.gitignore`, `git status`, `git add` (staging) ve anlamlı commit pratiklerini kazanmak.
2. GitHub üzerinde Personal Access Token (PAT) oluşturup terminalden uzak depoya ilk push işlemini gerçekleştirmek.
3. Feature branch yaşam döngüsünü (`git checkout -b`, değişiklik, commit, push, Pull Request) uygulamak.
4. İki farklı branch'te aynı satır değiştirildiğinde ortaya çıkan merge conflict yapısını (`<<<<<<<`, `=======`, `>>>>>>>`) hem terminalde hem de GitHub web arayüzünde incelemek ve çözmek.
5. `git log --graph --oneline` ile dal geçmişini terminalde görselleştirmek.

---

## Ön Koşullar

Laboratuvara başlamadan önce aşağıdaki hazırlıkları tamamlayın:

### 1. GitHub Hesabı ve Boş Depo (Repository) Oluşturma
1. [GitHub](https://github.com)'a giriş yapın.
2. Sağ üstteki **`+`** simgesine tıklayıp **New repository** seçin.
3. Repository name: **`novashop`** yazın.
4. Görünürlük: **Public** (veya isteğe bağlı Private) seçin.
5. ⚠️ **ÖNEMLİ:** *"Add a README file"*, *"Add .gitignore"* veya *"Choose a license"* seçeneklerinin **HİÇBİRİNİ İŞARETLEMEYİN**. Depo tamamen boş olmalıdır.
6. **Create repository** butonuna tıklayın.

### 2. GitHub Personal Access Token (PAT) Oluşturma
GitHub, terminalden parola ile push işlemlerini engellediği için bir erişim token'ı (PAT) oluşturmanız gerekir:
1. GitHub'da profil ikonunuza tıklayın -> **Settings** seçin.
2. Sol menünün en altındaki **Developer Settings** -> **Personal access tokens** -> **Tokens (classic)** seçeneğine tıklayın.
3. **Generate new token** -> **Generate new token (classic)** seçin.
4. **Note:** `novashop-lab` yazın.
5. **Expiration:** `30 days` seçin.
6. **Scopes:**
   - **`repo`** kutucuğunu işaretleyin (Tüm repository yönetim izinleri).
   - **`workflow`** kutucuğunu işaretleyin (⚠️ Depodaki `.github/workflows/` altındaki GitHub Actions iş akışlarını push edebilmek için zorunludur).
7. **Generate token** butonuna tıklayın.
8. Üretilen `ghp_xxxxxxxxxxxxxxxxxxxx` token'ını güvenli bir yere kopyalayın.

### 3. Ubuntu Sunucu Ortamı
- Ubuntu 22.04+ işletim sistemi (Cockpit web terminali veya SSH erişimi).
- Git kurulu olmalıdır (`git --version` >= 2.30).

### 4. Git Kimlik ve Parola Hatırlama (Credential Helper) Ayarı
Terminalden her `git push` veya `git pull` yaptığınızda GitHub'ın sürekli kullanıcı adı ve uzun PAT (Personal Access Token) sormasını engellemek için Git'in yerleşik kimlik saklama özelliğini tek komutla aktif edebilirsiniz:

```bash
git config --global credential.helper store
```

> **💡 Bu Ayar Ne İşe Yarar ve Neden Önemlidir?**  
> Bu ayar sayesinde, ilk `git push` sırasında kullanıcı adınızı ve PAT token'ınızı bir defaya mahsus girdiğinizde Git bu bilgileri oturumunuza güvenli bir şekilde kaydeder. Sonrasında terminali kapatsanız veya sunucuyu yeniden başlatsanız dahi GitHub size bir daha **asla şifre veya token sormaz**, tüm push/pull işlemleriniz kesintisiz ve otomatik tamamlanır.

---

## Kullanılan Placeholder'lar

| Placeholder | Anlamı | Örnek Değer |
|---|---|---|
| `<GITHUB_USERNAME>` | GitHub kullanıcı adınız | `johndoe` |
| `<YOUR_NAME>` | Git commit yazar adı | `Ahmet Yilmaz` |
| `<YOUR_EMAIL>` | Git commit yazar e-postası | `ahmet@example.com` |
| `<GITHUB_PAT_TOKEN>` | GitHub Personal Access Token | `ghp_1234567890abcdef...` |

---

## Adımlar

### Bölüm 1: Yerel Depoyu Başlatma ve İlk Commit

Bu bölümde, NovaShop kod tabanını sunucuda temiz bir Git geçmişiyle başlatıp kendi GitHub deponuza göndereceksiniz.

#### 1.1 Depoyu Klonlayın ve Sıfır Git Geçmişiyle Başlatın
```bash
# 1. NovaShop başlangıç reposunu home dizinine klonlayın:
cd ~
git clone https://gitlab.com/devops-practitioner-labs/novashop.git

# 2. Proje dizinine geçin:
cd ~/novashop

# 3. Mevcut Git geçmişini silerek projeyi sıfırdan kendi main dalınızla başlatın:
rm -rf .git
git init -b main
```
> [!NOTE]
> Mevcut `.git` dizinini silerek orijinal projenin geçmişini temizler ve deponun ilk mimarı olarak `main` dalıyla sıfırdan başlarsınız. Eğer mevcut bir `~/novashop` deponuz zaten varsa ve orijinal uzak bağlantısını korumak istiyorsanız, bu adımı geçici bir kopya dizinde (örn: `cp -r ~/novashop ~/novashop-git-practice && cd ~/novashop-git-practice`) uygulayabilirsiniz.

*Beklenen Çıktı:*
```text
Initialized empty Git repository in /home/.../novashop/.git/
```

#### 1.2 Depoya Özel (Local) Git Kimlik Bilgilerini Tanımlayın
```bash
git config --local user.name "<YOUR_NAME>"
git config --local user.email "<YOUR_EMAIL>"
```

*Doğrulama:*
```bash
git config --local --get user.name
git config --local --get user.email
```

#### 1.3 .gitignore Dosyasını İnceleyin
```bash
head -n 20 .gitignore
```

#### 1.4 Dosyaları Stage Alanına Alın ve İlk Commit'i Atın
```bash
git add .
git commit -m "feat: initial novashop starter repository with branding"
```

*Beklenen Çıktı:*
```text
[main (root-commit) 8a1b2c3] feat: initial novashop starter repository with branding
 ... files changed, ... insertions(+)
```

#### 1.5 GitHub Uzak Deposunu Ekleyin ve Push Edin
```bash
git remote add origin https://github.com/<GITHUB_USERNAME>/novashop.git
git push -u origin main
```
> **Kimlik Doğrulama:**  
> - **Username:** `<GITHUB_USERNAME>`  
> - **Password:** Oluşturduğunuz `<GITHUB_PAT_TOKEN>` değerini girin.

> [!TIP]
> **Olası Hata: `refusing to allow a Personal Access Token to create or update workflow... without workflow scope`**  
> Eğer bu hatayı alırsanız, token'ınızda `workflow` yetkisi eksiktir. GitHub'da **Settings -> Developer Settings -> Personal access tokens -> Tokens (classic)** sayfasına gidip token'ınızı düzenleyin, **`workflow`** kutucuğunu işaretleyip kaydedin. Ardından terminalde kayıtlı eski token'ı temizleyip (`rm -f ~/.git-credentials`) komutu tekrar çalıştırın.

**Web Arayüzü Kontrolü:**  
Tarayıcınızda `https://github.com/<GITHUB_USERNAME>/novashop` sayfasını açın. Dosyaların, `main` branch'inin ve commit geçmişinin listelendiğini doğrulayın.

---

### Bölüm 2: Feature Branch Açma ve Pull Request Süreci

Bu bölümde, ana dalı (`main`) izole tutarak yeni bir feature branch açacak, bir ürün fiyatını güncelleyecek ve GitHub üzerinde Pull Request (PR) oluşturacaksınız.

#### 2.1 Yeni Feature Branch Oluşturun
```bash
git checkout -b feature/update-mug-product
```

*Beklenen Çıktı:*
```text
Switched to a new branch 'feature/update-mug-product'
```

#### 2.2 Ürün Fiyatını Güncelleyin
`labs/LAB-01/products.json` dosyasındaki ilk ürünün (`Kubernetes Cluster Mug`) fiyatını `45` yerine `85` yapın:
```bash
sed -i 's/"price": 45/"price": 85/' labs/LAB-01/products.json
```

#### 2.3 Değişikliği İnceleyin, Commit Edin ve Push Edin
```bash
git diff labs/LAB-01/products.json
git add labs/LAB-01/products.json
git commit -m "feat(catalog): update kubernetes mug price to 85"
git push -u origin feature/update-mug-product
```

#### 2.4 GitHub Üzerinde Pull Request (PR) Açın
1. GitHub'da `https://github.com/<GITHUB_USERNAME>/novashop` sayfasına gidin.
2. Sayfanın üstünde sarı kutuda **`Compare & pull request`** butonunu göreceksiniz. Butona tıklayın.
3. PR başlığı: `feat(catalog): update kubernetes mug price to 85`
4. **Files changed** sekmesine tıklayıp satır farkını (`-45` -> `+85`) inceleyin.
5. Yeşil **`Create pull request`** butonuna tıklayın.
6. ⚠️ **DİKKAT:** PR'ı henüz merge etmeyin! Bir sonraki bölümde bu PR üzerinden çakışma senaryosu simüle edilecektir.

---

### Bölüm 3: Kontrollü Merge Conflict Simülasyonu ve Çözümü

#### Senaryo:
Siz `feature/update-mug-product` dalında fiyatı `85` yapıp PR açmışken, bir ekip arkadaşınız `main` dalında aynı ürünün fiyatını acil olarak `80` olarak değiştirip `main` dalına push etmiştir.

#### 3.1 `main` Dalına Geri Dönün ve Rakip Değişikliği Push Edin
```bash
git checkout main
sed -i 's/"price": 45/"price": 80/' labs/LAB-01/products.json
git commit -am "fix(pricing): adjust kubernetes mug price to 80 on main"
git push origin main
```

#### 3.2 GitHub PR Ekranını İnceleyin
1. GitHub'da açık bıraktığınız Pull Request sayfasına dönün ve sayfayı yenileyin (**F5**).
2. GitHub'ın otomatik olarak çakışmayı tespit ettiğini göreceksiniz:  
   ⚠️ **`This branch has conflicts that must be resolved`**
3. `Merge pull request` butonu devre dışı kalmıştır.

#### 3.3 Çakışmayı Terminalde Tetikleyin
```bash
git merge feature/update-mug-product
```

*Beklenen Çıktı:*
```text
Auto-merging labs/LAB-01/products.json
CONFLICT (content): Merge conflict in labs/LAB-01/products.json
Automatic merge failed; fix conflicts and then commit the result.
```

#### 3.4 Çakışmayı İnceleyin
```bash
git status
git diff labs/LAB-01/products.json
```
Dosyada conflict bloklarını göreceksiniz:
```json
<<<<<<< HEAD
    "price": 80,
=======
    "price": 85,
>>>>>>> feature/update-mug-product
```
- `<<<<<<< HEAD`: Mevcut daldaki (`main`) değer (`80`).
- `=======`: Ayrım çizgisi.
- `>>>>>>> feature/...`: Gelen daldaki değer (`85`).

#### 3.5 Çakışmayı Çözün
Ekip kararı gereği geçerli fiyatın **`85`** olduğunu kabul ediyoruz. Dosyayı düzenleyerek işaretçileri kaldırın ve sadece doğru satırı bırakın:

```bash
# nano ile açıp elle düzenleyebilirsiniz:
nano labs/LAB-01/products.json
```
*Veya komut satırından doğrudan temizleyin:*
```bash
sed -i '/<<<<<<< HEAD/d' labs/LAB-01/products.json
sed -i '/"price": 80,/d' labs/LAB-01/products.json
sed -i '/=======/d' labs/LAB-01/products.json
sed -i '/>>>>>>> feature\/update-mug-product/d' labs/LAB-01/products.json
```

**JSON Geçerliliğini Doğrulayın:**
```bash
jq . labs/LAB-01/products.json > /dev/null && echo "✅ JSON GEÇERLİ"
```

#### 3.6 Merge Commit'ini Tamamlayın ve Push Edin
```bash
git add labs/LAB-01/products.json
git commit -m "merge: resolve pricing conflict on kubernetes mug (set to 85)"
git push origin main
```

#### 3.7 Git Geçmişini Doğrulayın
```bash
git log --graph --oneline --decorate -n 6
```

#### 3.8 GitHub PR Ekranını Yenileyin ve Sonucu Gözlemleyin
GitHub'daki açık Pull Request sayfasına dönüp sayfayı yenileyin (**F5**).

> **💡 GitHub Ne Yaptı ve Neden Otomatik Kapanıp Merged Oldu?**  
> Çakışmayı terminalde `main` dalı üzerinde çözüp merge commit'ini doğrudan `origin main` dalına push ettiğiniz için; GitHub, `feature/update-mug-product` dalındaki commit'lerin artık `main` dalına dahil edildiğini algılar.  
> Bu sebeple PR manuel bir "Merge pull request" butonuna dönmez; GitHub PR'ı otomatik olarak **Merged (Mor)** statüsüne geçirir ve kapatır:  
> - **`Pull request successfully merged and closed`** mesajı görüntülenir.  
> - Dalın artık güvenle silinebileceğini belirten **`You're all set — the feature/update-mug-product branch can be safely deleted.`** uyarısı ve **Delete branch** butonu aktifleşir.

---

### Bölüm 4: Otomatik Doğrulama Betiğini Çalıştırma

Laboratuvar adımlarını başarıyla tamamladığınızı doğrulamak için doğrulama betiğini çalıştırın:

```bash
bash scripts/verify/verify-lab-01.sh
```

*Beklenen Çıktı:*
```text
=== [LAB-01] Doğrulama Başlatılıyor ===
✅ Git deposu mevcut.
✅ Local Git yapılandırması: <STUDENT_NAME> <<STUDENT_EMAIL>>
✅ Toplam commit sayısı: 4
✅ Çalışma ağacı temiz (clean working tree).
=== [LAB-01] Doğrulama Başarıyla Tamamlandı! ===
```

---

## 🧹 Temizlik (Cleanup)

İşiniz bittiğinde açtığınız geçici `feature/update-mug-product` dalını hem yerelden hem de uzak GitHub deposundan temizleyebilirsiniz:

### 1. Yerel (Local) Dalı Silme:
```bash
git branch -d feature/update-mug-product
```

### 2. Uzak (Remote - GitHub) Dalı Silme (Opsiyonel / İsteğe Bağlı):
Uzak depodaki dalı temizlemek için iki yöntemden birini seçebilirsiniz:
- **Terminalden Tek Komutla Silme:**
  ```bash
  git push origin --delete feature/update-mug-product
  ```
- **GitHub Web Arayüzünden Silme:**  
  Merge edilmiş Pull Request sayfanızın en altındaki **`Delete branch`** butonuna tıklayarak doğrudan tarayıcı üzerinden silebilirsiniz.
