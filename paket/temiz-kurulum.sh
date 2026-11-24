#!/usr/bin/env bash
# Corvid: temiz kurulum (FFmpeg 9.0.2).
#
#   sudo bash temiz-kurulum.sh              kurar (ayarlar ve kanallar taşınır)
#   sudo bash temiz-kurulum.sh --ayarlar    yalnızca sunucu ayarlarını taşır, kanallar boş başlar
#   sudo bash temiz-kurulum.sh --sifirdan   hiçbir şey taşımaz (parola, anahtarlar, kanallar yeniden)
#   sudo bash temiz-kurulum.sh --geri-don   Corvid'i durdurur, eski "restreamer" konteynerini açar
#   sudo bash temiz-kurulum.sh --eskiyi-sil Corvid çalışırken eski kurulumun kalıntılarını siler
#                                           (önce listeler, "SIL" yazılınca siler; geri alınamaz)
#
# Ne yapar:
#   1. corvid:v1 imajını kaynaktan derler (bu klasördeki yamalarla, FFmpeg 9.0.2). Eski kurulum bu
#      sırada yayına devam eder. FFmpeg imajı sunucuda varsa yeniden derlenmez.
#   2. Ayarları (ve istenirse kanalları, dosyaları) /opt/restreamer'dan /opt/corvid'e kopyalar.
#      /opt/restreamer'a dokunmaz.
#   3. Eski "restreamer" konteynerini durdurur (silmez), "corvid" konteynerini başlatır. Kesinti
#      yalnızca bu geçişte olur (yaklaşık 10-30 sn).
#   4. Corvid 2 dakika içinde yanıt vermezse eskisini kendiliğinden geri açar.
#
# Ayarlanabilir: OLD (eski konteyner, varsayılan restreamer; klasörleri onun bağlarından okunur),
# NEW_DIR (/opt/corvid), PANEL_PORT (4501), FFMPEG (9; 6 = önceki FFmpeg 6.1.1, o zaman CUDA 11|12),
# IMAGE (derlemek yerine hazır imajı indirir, ör. IMAGE=ghcr.io/mosyokuzgun/corvid:latest).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OLD="${OLD:-restreamer}"
NEW_DIR="${NEW_DIR:-/opt/corvid}"
PORT="${PANEL_PORT:-4501}"
NEW=corvid
COMPOSE="$NEW_DIR/docker-compose.yml"

die() { echo "HATA: $*" >&2; exit 1; }
step() { echo; echo "== $*"; }

[ "$(id -u)" -eq 0 ] || die "root olarak çalıştırın:  sudo bash temiz-kurulum.sh"
command -v docker >/dev/null || die "docker bulunamadı"
docker info >/dev/null 2>&1 || die "Docker'a ulaşılamadı"
docker compose version >/dev/null 2>&1 || die "docker compose eklentisi yok"
command -v git >/dev/null || die "git bulunamadı (sudo apt install git)"
command -v curl >/dev/null || die "curl bulunamadı (sudo apt install curl)"

old_exists() { docker inspect "$OLD" >/dev/null 2>&1; }
mount_of() { docker inspect -f "{{range .Mounts}}{{if eq .Destination \"$1\"}}{{.Source}}{{end}}{{end}}" "$OLD"; }
OLD_CFG=""
OLD_DATA=""
if old_exists; then
    OLD_CFG="$(mount_of /core/config)"
    OLD_DATA="$(mount_of /core/data)"
fi

ready() { # panel yanıt veriyor mu
    curl -fsS -o /dev/null "http://localhost:$PORT/api" 2>/dev/null
}

wait_ready() {
    for _ in $(seq 1 60); do
        ready && return 0
        sleep 2
    done
    return 1
}

start_old() {
    if old_exists; then
        docker update --restart=unless-stopped "$OLD" >/dev/null
        docker start "$OLD" >/dev/null
    fi
}

# Eski kurulumun kalıntıları: konteyner, imaj, klasörler, eski güncelleme paketleri ve raporlar.
remove_old() {
    ready && docker inspect -f '{{.State.Running}}' "$NEW" 2>/dev/null | grep -q true ||
        die "önce Corvid çalışıyor olmalı (sudo bash temiz-kurulum.sh). Eski kurulum yedek olarak duruyor."
    local home dirs=() files=() d f
    home="$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)"
    case "$home" in /?*) ;; *) home=/nonexistent-home ;; esac
    for d in "$OLD_CFG" "$OLD_DATA" /opt/restreamer "$home/restreamer-build" "$home/restreamer-nvidia-update" "$home/restreamer-nvidia" "$NEW_DIR".basarisiz-*; do
        [ -n "$d" ] && [ -d "$d" ] || continue
        case "$d" in /opt/?*/*|/opt/restreamer|"$NEW_DIR".basarisiz-?*|"$home"/?*) ;; *) echo "   atlandı (beklenmeyen yer): $d"; continue ;; esac
        case "$d" in "$NEW_DIR"|"$NEW_DIR"/*|"$HERE"|"$HERE"/*) continue ;; esac
        dirs+=("$d")
    done
    for f in "$home"/restreamer-nvidia-update*.zip "$home"/perf-check.sh "$home"/perf-rapor*.txt "$home"/core-cpu.pprof; do
        [ -f "$f" ] && files+=("$f")
    done
    echo "Silinecekler:"
    old_exists && echo "  konteyner: $OLD"
    docker image inspect restreamer:nvidia >/dev/null 2>&1 && echo "  imaj: restreamer:nvidia"
    for d in "${dirs[@]}"; do echo "  klasör: $d ($(du -sh "$d" 2>/dev/null | cut -f1))"; done
    for f in "${files[@]}"; do echo "  dosya: $f"; done
    echo "Kalanlar: Corvid ($NEW_DIR, corvid:v1) ve FFmpeg imajı (sonraki derlemeler için)."
    printf 'Geri alınamaz. Silmek için SIL yazın: '
    local answer=""
    read -r answer || true
    [ "$answer" = SIL ] || die "vazgeçildi, hiçbir şey silinmedi"
    if old_exists; then docker rm -f "$OLD" >/dev/null; fi
    docker image rm restreamer:nvidia >/dev/null 2>&1 || true
    for d in "${dirs[@]}"; do rm -rf -- "$d"; done
    for f in "${files[@]}"; do rm -f -- "$f"; done
    echo ">> Eski kurulum silindi."
}

case "${1:-}" in
--geri-don)
    step "Corvid durduruluyor, eski kurulum açılıyor"
    [ -f "$COMPOSE" ] && docker compose -f "$COMPOSE" stop || true
    [ -f "$COMPOSE" ] && docker update --restart=no "$NEW" >/dev/null 2>&1 || true
    old_exists || die "eski konteyner '$OLD' yok"
    start_old
    wait_ready && echo ">> Eski kurulum çalışıyor: http://<sunucu>:$PORT/ui/" || die "eski kurulum yanıt vermedi: docker logs --tail 50 $OLD"
    exit 0
    ;;
--eskiyi-sil)
    remove_old
    exit 0
    ;;
--ayarlar) MODE=settings ;;
--sifirdan) MODE=none ;;
"") MODE=all ;;
*) die "bilinmeyen seçenek: $1" ;;
esac

IMAGE="${IMAGE:-}"
BUILD=""
for b in "$HERE/kaynak/build.sh" "$HERE/../build.sh"; do
    if [ -f "$b" ]; then BUILD="$(cd "$(dirname "$b")" && pwd)/build.sh"; break; fi
done
[ -n "$IMAGE" ] || [ -n "$BUILD" ] || die "build.sh bulunamadı; zip'i eksiksiz açın ya da IMAGE=... ile hazır imajı verin"

# ---- 0. Durum --------------------------------------------------------------------------------
if docker inspect "$NEW" >/dev/null 2>&1; then
    die "'$NEW' konteyneri zaten var. Güncelleme için: sudo bash update.sh   Geri dönmek için: --geri-don"
fi
if [ -e "$NEW_DIR/config" ] || [ -e "$NEW_DIR/data" ]; then
    die "$NEW_DIR zaten dolu. Önceki bir denemeden kaldıysa ve içindekine ihtiyacınız yoksa:  sudo rm -rf $NEW_DIR"
fi
if old_exists && [ "$MODE" = none ]; then
    echo ">> Eski kurulum durdurulacak ama hiçbir şey taşınmayacak: Corvid boş başlar."
    echo "   UYARI: panel dışarıdan erişilebilir ve parolası yok. Kurulum biter bitmez"
    echo "   http://<sunucu>:$PORT/ui/ adresine girip yönetici parolasını belirleyin,"
    echo "   sonra Ayarlar → Yayın sunucuları'nda RTMP ve SRT'yi açıp anahtar verin."
elif old_exists; then
    [ -n "$OLD_CFG" ] && [ -f "$OLD_CFG/config.json" ] || die "eski kurulumun ayar klasörü bulunamadı ('$OLD' konteynerinin /core/config bağı: '${OLD_CFG}')"
    if [ "$MODE" = all ] && { [ -z "$OLD_DATA" ] || [ ! -d "$OLD_DATA" ]; }; then
        die "eski kurulumun veri klasörü bulunamadı ('$OLD' konteynerinin /core/data bağı)"
    fi
    echo ">> Eski kurulum: konteyner '$OLD', ayarlar $OLD_CFG, veriler $OLD_DATA"
    if [ "$MODE" = all ]; then
        echo ">> Taşınacak: ayarlar, kanallar, yayınlar, hesaplar ve veri klasörü ($(du -sh "$OLD_DATA" 2>/dev/null | cut -f1))"
    else
        echo ">> Taşınacak: yalnızca sunucu ayarları ve hesaplar (giriş, anahtarlar, portlar). Kanallar boş başlar."
    fi
else
    echo ">> Eski kurulum yok: boş kurulum yapılacak."
    echo "   UYARI: ilk açılışta panel parola belirlemenizi ister. Panel dışarıdan erişilebilir olduğu"
    echo "   için kurulum biter bitmez http://<sunucu>:$PORT/ui/ adresine girip parolayı belirleyin."
fi

# ---- 1. İmaj ---------------------------------------------------------------------------------
if [ -n "$IMAGE" ]; then
    step "1/4 imaj indiriliyor: $IMAGE (eski kurulum bu sırada çalışmaya devam eder)"
    docker pull "$IMAGE"
    docker tag "$IMAGE" corvid:v1
else
    step "1/4 corvid:v1 imajı derleniyor (eski kurulum bu sırada çalışmaya devam eder)"
    TAG=corvid:v1 WORK="$(dirname "$BUILD")/src" bash "$BUILD"
fi
docker image inspect corvid:v1 >/dev/null || die "imaj oluşmadı"

# ---- 2. Klasörler ----------------------------------------------------------------------------
step "2/4 $NEW_DIR hazırlanıyor"
mkdir -p "$NEW_DIR/config" "$NEW_DIR/data"
install -m 0644 "$HERE/kaynak/docker-compose.corvid.yml" "$COMPOSE"

copy_dir() { # $1 kaynak, $2 hedef, sonrakiler: hariç tutulacaklar
    local src="$1" dst="$2"; shift 2
    if command -v rsync >/dev/null; then
        local ex=()
        for e in "$@"; do ex+=(--exclude "$e"); done
        rsync -a --delete "${ex[@]}" "$src/" "$dst/"
    else
        cp -a "$src/." "$dst/"
        # shellcheck disable=SC2086
        for e in "$@"; do rm -rf "${dst:?}"/$e; done
    fi
}

sync_old() {
    old_exists || return 0
    [ "$MODE" = none ] && return 0
    if [ "$MODE" = all ]; then
        copy_dir "$OLD_CFG" "$NEW_DIR/config"
        copy_dir "$OLD_DATA" "$NEW_DIR/data"
    else
        # db.json: kanallar, yayınlar ve panel bilgileri. Yalnızca sunucu ayarları taşınır.
        copy_dir "$OLD_CFG" "$NEW_DIR/config" 'db.json*' 'db*.json'
    fi
}

if old_exists; then
    echo ">> Ön kopya (eski kurulum çalışırken) ..."
    sync_old
fi

# ---- 3. Geçiş --------------------------------------------------------------------------------
step "3/4 Geçiş: eski konteyner durduruluyor, Corvid başlatılıyor"
if old_exists; then
    docker stop -t 20 "$OLD" >/dev/null
    echo ">> Son değişiklikler kopyalanıyor ..."
    sync_old
fi
# datarhei'nin hazır kök sayfası ("Did you mean to go to the admin panel?") Corvid'inkiyle değişir.
if [ ! -f "$NEW_DIR/data/index.html" ] || grep -q "Did you mean to go to the admin panel" "$NEW_DIR/data/index.html"; then
    install -m 0644 "$HERE/ui-root/index.html" "$NEW_DIR/data/index.html"
    rm -f "$NEW_DIR/data/index_icon.svg"
fi

if ! docker compose -f "$COMPOSE" up -d || ! wait_ready; then
    echo "!! Corvid başlamadı ya da 2 dakika içinde yanıt vermedi. Eski kurulum geri açılıyor." >&2
    docker logs --tail 40 "$NEW" >&2 2>&1 || true
    docker compose -f "$COMPOSE" down >/dev/null 2>&1 || true
    start_old
    # yeni deneme yapılabilsin: kopya kenara alınır (eskisi zaten yerinde)
    failed="$NEW_DIR.basarisiz-$(date +%Y%m%d-%H%M%S)"
    mv "$NEW_DIR" "$failed"
    wait_ready && echo "!! Eski kurulum yeniden çalışıyor. Yukarıdaki günlüğü bana gönderin. (Denemenin kopyası: $failed)" >&2
    exit 1
fi

# Sunucu yeniden açıldığında eskisi de kalkıp portları kapmasın.
old_exists && docker update --restart=no "$OLD" >/dev/null

# ---- 4. Bitti --------------------------------------------------------------------------------
step "4/4 Bitti"
echo ">> Corvid çalışıyor: http://<sunucu>:$PORT/ui/   (Ctrl+F5)"
echo ">> Ayarlar ve veriler: $NEW_DIR   Sonraki güncellemeler: sudo bash update.sh"
if old_exists; then
    echo ">> Eski kurulum durduruldu ama silinmedi (konteyner '$OLD', klasörler $OLD_CFG, $OLD_DATA)."
    echo "   Geri dönmek için:  sudo bash temiz-kurulum.sh --geri-don"
    echo "   Bir hafta sorunsuz geçince silebilirsiniz:  docker rm $OLD  ve eski klasörler"
fi
