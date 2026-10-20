import base64
import subprocess
from PIL import Image

def get_base64(path):
    with open(path, "rb") as f:
        return f"data:image/png;base64,{base64.b64encode(f.read()).decode('utf-8')}"

ec2_b64 = get_base64("/tmp/icon_ec2.png")
rds_b64 = get_base64("/tmp/icon_rds.png")

html_content = f"""<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }}
  body {{
    width: 1200px;
    height: 720px;
    background-color: #ffffff;
    color: #16191f;
    padding: 24px 36px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
  }}

  /* Header */
  .header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 2px solid #eaeded;
    padding-bottom: 12px;
  }}
  .header-left {{
    display: flex;
    align-items: center;
    gap: 14px;
  }}
  .aws-badge {{
    background: #232f3e;
    color: #ff9900;
    font-weight: 800;
    font-size: 16px;
    padding: 6px 14px;
    border-radius: 6px;
    letter-spacing: 0.5px;
  }}
  .aws-badge span {{ color: #ffffff; font-weight: normal; }}
  .title-group h1 {{
    font-size: 21px;
    font-weight: 800;
    color: #16191f;
  }}
  .title-group p {{
    font-size: 13px;
    color: #545b64;
    margin-top: 2px;
  }}
  .header-badges {{
    display: flex;
    gap: 8px;
  }}
  .badge {{
    padding: 6px 12px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 700;
  }}
  .badge-az {{
    background: #e8f5e9;
    color: #1b5e20;
    border: 1px solid #a5d6a7;
  }}
  .badge-region {{
    background: #f2f3f3;
    color: #16191f;
    border: 1px solid #d5dbdb;
  }}

  /* Main Diagram Layout */
  .diagram-body {{
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    flex-grow: 1;
    margin: 12px 0;
  }}

  /* Internet / Client Bar */
  .client-bar {{
    display: flex;
    align-items: center;
    gap: 10px;
    background: #ffffff;
    border: 2px solid #0073bb;
    padding: 8px 32px;
    border-radius: 30px;
    box-shadow: 0 2px 6px rgba(0, 115, 187, 0.12);
  }}
  .client-bar .icon {{ font-size: 24px; }}
  .client-bar .text {{ font-size: 13.5px; font-weight: 800; color: #16191f; }}
  .client-bar .sub {{ font-size: 11px; color: #545b64; }}

  /* Ingress Flow Arrow */
  .ingress-arrow {{
    display: flex;
    flex-direction: column;
    align-items: center;
    font-size: 11px;
    font-weight: 700;
    color: #0073bb;
    gap: 2px;
  }}
  .arrow-line {{
    width: 2px;
    height: 16px;
    background: #0073bb;
  }}

  /* VPC Box */
  .vpc-box {{
    width: 100%;
    border: 2px solid #248814;
    border-radius: 12px;
    background: #ffffff;
    padding: 16px 24px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    position: relative;
    box-shadow: 0 4px 12px rgba(36, 136, 20, 0.08);
  }}
  .vpc-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 8px;
    border-bottom: 1px solid #e1e4e8;
  }}
  .vpc-label {{
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 15px;
    font-weight: 800;
    color: #16191f;
  }}
  .vpc-tag {{
    background: #248814;
    color: white;
    font-size: 11px;
    font-weight: 800;
    padding: 3px 8px;
    border-radius: 4px;
  }}
  .vpc-tags-right {{
    display: flex;
    gap: 8px;
    font-size: 12px;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-weight: 600;
  }}
  .tag-pill {{
    background: #f1f8f1;
    border: 1px solid #c8e6c9;
    color: #1b5e20;
    padding: 2px 8px;
    border-radius: 4px;
  }}

  /* IGW Bar */
  .igw-bar {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: #fff8e1;
    border: 1.5px solid #ffe082;
    border-radius: 8px;
    padding: 8px 16px;
  }}
  .igw-title {{
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    font-weight: 800;
    color: #b78103;
  }}
  .igw-info {{
    font-size: 12px;
    font-weight: 600;
    color: #795548;
  }}

  /* Availability Zone (Tek AZ) */
  .az-box {{
    border: 2px dashed #0073bb;
    border-radius: 10px;
    background: #fafbfc;
    padding: 16px;
    display: grid;
    grid-template-columns: 1fr auto 1fr;
    align-items: center;
    gap: 20px;
  }}
  .az-header {{
    grid-column: 1 / -1;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12.5px;
    font-weight: 800;
    color: #0073bb;
    padding-bottom: 8px;
    border-bottom: 1px dashed #d0d7de;
    margin-bottom: 4px;
  }}
  .az-badge-active {{
    background: #e1f5fe;
    color: #0277bd;
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 4px;
    font-weight: 800;
  }}

  /* Subnet Cards */
  .subnet-card {{
    border-radius: 8px;
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    background: #ffffff;
  }}
  .public-subnet {{
    border: 2px solid #2e7d32;
  }}
  .private-subnet {{
    border: 2px solid #1565c0;
  }}
  .subnet-head {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12px;
    font-weight: 800;
  }}
  .public-subnet .subnet-head {{ color: #2e7d32; }}
  .private-subnet .subnet-head {{ color: #1565c0; }}
  .subnet-cidr {{
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 11px;
    background: #f0f0f0;
    padding: 2px 6px;
    border-radius: 3px;
    color: #333;
  }}

  /* Resource Row */
  .resource-row {{
    display: flex;
    align-items: center;
    gap: 14px;
    background: #f8f9fa;
    border: 1px solid #e9ecef;
    border-radius: 8px;
    padding: 10px 14px;
  }}
  .res-icon {{
    width: 52px;
    height: 52px;
    border-radius: 8px;
    object-fit: cover;
    box-shadow: 0 2px 6px rgba(0,0,0,0.1);
  }}
  .res-meta {{
    flex-grow: 1;
  }}
  .res-title {{
    font-size: 14.5px;
    font-weight: 800;
    color: #16191f;
  }}
  .res-sub {{
    font-size: 12px;
    color: #545b64;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    margin-top: 2px;
  }}
  .res-badges {{
    display: flex;
    gap: 6px;
    margin-top: 5px;
    font-size: 11px;
    font-weight: 700;
  }}
  .pill-port {{
    background: #e3f2fd;
    color: #1565c0;
    padding: 2px 8px;
    border-radius: 4px;
  }}
  .pill-ssh {{
    background: #f5f5f5;
    color: #424242;
    padding: 2px 8px;
    border-radius: 4px;
  }}
  .pill-private {{
    background: #ffebee;
    color: #c62828;
    padding: 2px 8px;
    border-radius: 4px;
  }}

  /* SG / Route Notes */
  .info-bar {{
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: #555;
    background: #ffffff;
    border: 1px solid #e0e0e0;
    padding: 5px 10px;
    border-radius: 4px;
  }}

  /* Intra-AZ Connection Flow */
  .intra-flow {{
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    text-align: center;
    padding: 0 4px;
  }}
  .flow-pill {{
    background: #e8f0fe;
    border: 1.5px dashed #1a73e8;
    color: #1a73e8;
    font-size: 11.5px;
    font-weight: 800;
    padding: 6px 12px;
    border-radius: 6px;
    white-space: nowrap;
  }}
  .flow-arrow-h {{
    font-size: 20px;
    color: #1a73e8;
    font-weight: bold;
  }}

  /* Footer */
  .footer-note {{
    background: #f2f3f3;
    border: 1px solid #d5dbdb;
    border-radius: 8px;
    padding: 10px 18px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12.5px;
    color: #374151;
  }}
  .footer-note strong {{ color: #111827; }}
  .footer-highlight {{ color: #0073bb; font-weight: 800; }}
</style>
</head>
<body>

  <!-- Top Header -->
  <div class="header">
    <div class="header-left">
      <div class="aws-badge">AWS <span>Cloud</span></div>
      <div class="title-group">
        <h1>NovaShop 2-Katmanlı Temel Bulut Mimarisi (Web &amp; Database)</h1>
        <p>LAB-02 — Tek Availability Zone (Single-AZ) İçinde Public Web ve Private Database Katmanları</p>
      </div>
    </div>
    <div class="header-badges">
      <span class="badge badge-az">✓ Tek AZ (Single-AZ)</span>
      <span class="badge badge-region">📍 Bölge: us-east-1 (N. Virginia)</span>
    </div>
  </div>

  <!-- Main Architecture Area -->
  <div class="diagram-body">

    <!-- Internet & Client -->
    <div class="client-bar">
      <span class="icon">🌐</span>
      <div>
        <span class="text">İstemci / Web Tarayıcısı (Internet Users)</span>
        <span class="sub">&bull; HTTP :80 (Web Ziyaretçileri) &bull; SSH :22 (Yönetici)</span>
      </div>
    </div>

    <!-- Arrow down to VPC -->
    <div class="ingress-arrow">
      <div class="arrow-line"></div>
      <div>▼ HTTP :80 Girişi</div>
    </div>

    <!-- VPC Box -->
    <div class="vpc-box">
      <div class="vpc-header">
        <div class="vpc-label">
          <span class="vpc-tag">VPC</span>
          <span>Sanal Özel Bulut (Virtual Private Cloud)</span>
        </div>
        <div class="vpc-tags-right">
          <span class="tag-pill">Console: novashop-console-vpc (10.0.0.0/16)</span>
          <span class="tag-pill">Terraform: novashop-tf-vpc (10.1.0.0/16)</span>
        </div>
      </div>

      <!-- IGW -->
      <div class="igw-bar">
        <div class="igw-title">
          <span>🚪</span>
          <span>Internet Gateway (IGW) &mdash; novashop-*-igw</span>
        </div>
        <div class="igw-info">0.0.0.0/0 Dış Ağ Çıkışı ve Giriş Kapısı</div>
      </div>

      <!-- Single AZ Box (us-east-1a) -->
      <div class="az-box">
        <div class="az-header">
          <span>Availability Zone: us-east-1a</span>
          <span class="az-badge-active">TEK AZ (Aktif Altyapı)</span>
        </div>

        <!-- Katman 1: Public Subnet (Web) -->
        <div class="subnet-card public-subnet">
          <div class="subnet-head">
            <span>🔒 Katman 1: Public Subnet (Web Tier)</span>
            <span class="subnet-cidr">10.0.1.0/24 (Console) | 10.1.1.0/24 (TF)</span>
          </div>

          <div class="resource-row">
            <img src="{ec2_b64}" class="res-icon" alt="EC2">
            <div class="res-meta">
              <div class="res-title">1x EC2 Web Sunucusu (Nginx)</div>
              <div class="res-sub">Ubuntu 22.04 LTS &bull; t3.medium</div>
              <div class="res-badges">
                <span class="pill-port">HTTP :80 (Nginx)</span>
                <span class="pill-ssh">SSH :22</span>
                <span style="color:#2e7d32; font-weight:700;">Public IP</span>
              </div>
            </div>
          </div>

          <div class="info-bar">
            <span>Security Group: <strong>web-sg</strong></span>
            <span style="color:#2e7d32; font-weight:700;">Dış İnternete Açık (IGW Rotası)</span>
          </div>
        </div>

        <!-- Intra-AZ Connection Flow -->
        <div class="intra-flow">
          <div class="flow-pill">MySQL Port 3306</div>
          <div class="flow-arrow-h">&rarr;</div>
          <div style="font-size:10.5px; color:#545b64; font-weight:600;">Aynı AZ İçi<br/>Özel Ağ İletişimi</div>
        </div>

        <!-- Katman 2: Private Subnet (Database) -->
        <div class="subnet-card private-subnet">
          <div class="subnet-head">
            <span>🗄️ Katman 2: Private Subnet (Database Tier)</span>
            <span class="subnet-cidr">10.0.10.0/24 (Console) | 10.1.10.0/24 (TF)</span>
          </div>

          <div class="resource-row">
            <img src="{rds_b64}" class="res-icon" alt="RDS">
            <div class="res-meta">
              <div class="res-title">1x RDS MySQL 8.0 Instance</div>
              <div class="res-sub">MySQL 8.0 &bull; db.t3.small &bull; Single-AZ</div>
              <div class="res-badges">
                <span class="pill-port">MySQL :3306</span>
                <span class="pill-private">Dışa Kapalı (Private)</span>
              </div>
            </div>
          </div>

          <div class="info-bar">
            <span>Security Group: <strong>rds-sg</strong> (Yalnızca web-sg)</span>
            <span style="color:#c62828; font-weight:800;">Dış İnternet Erişimi: YASAK</span>
          </div>
        </div>

      </div>

    </div>

  </div>

  <!-- Footer -->
  <div class="footer-note">
    <div>
      <strong>Mimari Kuralı:</strong> LAB-02 altyapısı <span class="footer-highlight">2-Katmanlıdır (1x Web + 1x RDS)</span>. Her iki kaynak da aynı Availability Zone (us-east-1a) içinde koşar.
    </div>
    <div>
      3-Katmanlı Mikroservis Mimarisi (Web + Catalog API + RDS) <strong>LAB-04</strong>'te devreye alınır.
    </div>
  </div>

</body>
</html>
"""

html_path = "/tmp/clean_lab02.html"
png_path = "/tmp/clean_lab02.png"
jpg_path = "/tmp/clean_lab02.jpg"

with open(html_path, "w", encoding="utf-8") as f:
    f.write(html_content)

chrome_cmd = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "--headless",
    "--disable-gpu",
    "--window-size=1200,720",
    "--screenshot=" + png_path,
    "file://" + html_path
]

print("Rendering clean 2-tier architecture diagram...")
subprocess.run(chrome_cmd, check=True)

im = Image.open(png_path)
rgb_im = im.convert("RGB")
rgb_im.save(jpg_path, quality=95)
print(f"Generated clean diagram at {jpg_path}")
