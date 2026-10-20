#!/usr/bin/env bash
# ==============================================================================
# NovaShop — Canlı Trafik ve Gözlemlenebilirlik Veri Jeneratörü (Shell Wrapper)
# Kullanım:
#   bash scripts/simulate-traffic.sh               # 30 adet hızlı veri üretir
#   bash scripts/simulate-traffic.sh --continuous   # Arka planda sürekli veri üretir
#   bash scripts/simulate-traffic.sh --error-burst  # SLO alarmını tetikleyecek hata üretir
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/simulate-traffic.py"

if ! command -v python3 &> /dev/null; then
    echo "❌ Hata: python3 bulunamadı."
    exit 1
fi

python3 "$PYTHON_SCRIPT" "$@"
