#!/usr/bin/env bash
# Corvid: core, arayüz ve FFmpeg güncellemesi. İmaj derlemez, Docker imajı indirmez.
#
# Paketin içinden:
#   sudo bash update.sh               bu paketi kurar (core + arayüz + FFmpeg 9), konteyneri yeniden başlatır
# Kurulumdan sonra paket gerekmez; betik kendini /opt/corvid/update.sh olarak saklar (yalnızca root):
#   sudo bash /opt/corvid/update.sh --geri-al     bir önceki kurulan sürüme döner
#   sudo bash /opt/corvid/update.sh --eski-ffmpeg bu sürümde kalır ama imajdaki FFmpeg 6.1.1'i kullanır
#   sudo bash /opt/corvid/update.sh --kaldir      imajın içindeki core/arayüz/FFmpeg'e döner
#
# Nasıl çalışır: core programı, arayüz dosyaları ve FFmpeg sunucuda $OVERLAY klasörüne konur; bu
# klasör konteynere zaten /core/bin ve /core/ui olarak bağlıdır. FFmpeg 9 /core/bin/ffmpeg9 altına
# konur ve ayar dosyasındaki FFmpeg yolu (config.json → ffmpeg.binary) ona çevrilir. Aynı konteyner
# yalnızca yeniden başlatılır (yeniden oluşturulmaz). Kanallar ve ayarlar dokunulmadan kalır;
# FFmpeg değişince kayıtlı yayınların ayarları açılışta uyarlanır, öncesinin yedeği alınır
# (config/db.<zaman>.json).
#
# Yeni FFmpeg, kurulmadan ÖNCE çalışan konteynerin içinde ekran kartında denenir (NVENC, NVDEC,
# scale_cuda, overlay_cuda); yayınlara dokunulmaz. Deneme başarısızsa hiçbir şey değiştirilmez.
# Denemeyi atlamak için (ör. ekran kartı yoksa):  ATLA_GPU_TESTI=1 sudo bash update.sh
#
# Ayarlanabilir: OVERLAY (varsayılan: corvid konteynerinde /opt/corvid/overlay, eski kurulumda
# /opt/restreamer/overlay), MAIN_COMPOSE (compose dosyası; varsayılan: konteynerin oluşturulduğu
# dosya), CONTAINER (varsayılan: otomatik bulunur), PANEL_PORT (4501).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
USER_HOME="$(getent passwd "${SUDO_USER:-$(id -un)}" | cut -d: -f6)"
PORT="${PANEL_PORT:-4501}"

die() { echo "HATA: $*" >&2; exit 1; }
command -v docker >/dev/null || die "docker bulunamadı"

# Docker erişimi: hatayı yutma, nedenini söyle.
if ! err="$(docker info 2>&1 >/dev/null)"; then
    case "$err" in
    *ermission*) die "bu kullanıcının Docker izni yok. Şöyle çalıştırın:  sudo bash update.sh" ;;
    *) die "Docker'a ulaşılamadı: $(echo "$err" | tail -n 1)" ;;
    esac
fi

# Konteyneri bul: verilen ad, 'corvid' (temiz kurulum), 'restreamer' (eski kurulum), imajdan ya da
# panel portundan.
find_container() {
    if [ -n "${CONTAINER:-}" ]; then
        docker inspect "$CONTAINER" >/dev/null 2>&1 && echo "$CONTAINER"
        return 0
    fi
    for n in corvid restreamer; do
        if docker inspect "$n" >/dev/null 2>&1; then
            echo "$n"
            return 0
        fi
    done
    {
        docker ps -a --filter ancestor=corvid:v1 --format '{{.Names}}'
        docker ps -a --filter ancestor=restreamer:nvidia --format '{{.Names}}'
        docker ps -a --filter "publish=$PORT" --format '{{.Names}}'
    } | sort -u
}
found="$(find_container)"
if [ -z "$found" ]; then
    echo "Mevcut konteynerler:" >&2
    docker ps -a --format '  {{.Names}}  ({{.Image}}, {{.Status}})' >&2
    die "Corvid konteyneri bulunamadı. Yukarıdaki listeden adını verin:  CONTAINER=<ad> sudo bash update.sh"
fi
[ "$(echo "$found" | wc -l)" -eq 1 ] || die "birden fazla aday konteyner var: $(echo $found). Birini seçin:  CONTAINER=<ad> sudo bash update.sh"
CONTAINER="$found"
if [ -z "${OVERLAY:-}" ]; then
    if [ "$CONTAINER" = corvid ]; then OVERLAY=/opt/corvid/overlay; else OVERLAY=/opt/restreamer/overlay; fi
fi
case "$OVERLAY" in /*/*) ;; *) die "OVERLAY tam bir alt klasör olmalı (şu an: '$OVERLAY')";; esac
EXTRA="$OVERLAY/docker-compose.overlay.yml"

# Compose dosyası: konteyner hangi dosyayla oluşturulduysa o (etiketinden okunur).
label() { docker inspect -f "{{index .Config.Labels \"$1\"}}" "$CONTAINER" 2>/dev/null || true; }
if [ -z "$(label com.docker.compose.project)" ]; then
    die "'$CONTAINER' docker compose ile oluşturulmamış; bu betik onu güvenle yeniden oluşturamaz. Kullandığınız docker run komutunu bana gönderin."
fi
if [ -z "${MAIN_COMPOSE:-}" ]; then
    MAIN_COMPOSE="$(label com.docker.compose.project.config_files | tr ',' '\n' | grep -v 'docker-compose.overlay.yml' | head -n 1)"
fi
[ -n "$MAIN_COMPOSE" ] || MAIN_COMPOSE="$USER_HOME/restreamer-build/src/restreamer/docker-compose.nvidia.yml"
MAIN="$MAIN_COMPOSE"
[ -f "$MAIN" ] || die "compose dosyası yok: $MAIN  (MAIN_COMPOSE=/yol/docker-compose.yml sudo bash update.sh)"
PROJECT="$(label com.docker.compose.project)"
SERVICE="$(label com.docker.compose.service)"
[ -n "$SERVICE" ] || SERVICE=restreamer
IMAGE="$(docker inspect -f '{{.Config.Image}}' "$CONTAINER")"
echo ">> Konteyner: $CONTAINER   imaj: $IMAGE   compose: $MAIN"

SUDO=""
if ! { mkdir -p "$OVERLAY" 2>/dev/null && [ -w "$OVERLAY" ]; }; then SUDO=sudo; fi

compose() { docker compose -p "$PROJECT" -f "$MAIN" "$@"; }

# Konteynerin içinde gerçekten beklenen dosyalar mı çalışıyor: core'un sağlaması ve FFmpeg sürümü.
# (Panel API'si oturum açılmadan sürüm bildirmez, bu yüzden doğrudan konteynere bakılır.)
wait_ready() { # $1 = core'un beklenen sha256'sı (boş: herhangi), $2 = beklenen FFmpeg sürümü (boş: herhangi)
    local want_core="${1:-}" want_ff="${2:-}" core="" ff="" code=""
    for _ in $(seq 1 45); do
        if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = true ]; then
            code="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/api" 2>/dev/null || true)"
            core="$(docker exec "$CONTAINER" sha256sum /core/bin/core 2>/dev/null | cut -d' ' -f1 || true)"
            ff="$(docker exec "$CONTAINER" "$(ffmpeg_binary)" -hide_banner -version 2>/dev/null | sed -n '1s/^ffmpeg version \([^ ]*\).*/\1/p' || true)"
            if [ "$code" = 200 ] && { [ -z "$want_core" ] || [ "$core" = "$want_core" ]; } &&
                { [ -z "$want_ff" ] || [ "${ff%%-*}" = "$want_ff" ]; }; then
                echo ">> Corvid çalışıyor (panel $PORT, FFmpeg ${ff%%-*})."
                return 0
            fi
        fi
        sleep 2
    done
    echo "UYARI: Corvid 90 sn içinde beklenen sürümle başlamadı (panel: ${code:-yok}, FFmpeg: ${ff:-?})." >&2
    echo "       Kontrol: docker logs --tail 50 $CONTAINER     Geri dönmek için: sudo bash update.sh --geri-al" >&2
    return 1
}

# Konteynerin bağları overlay dosyasındakilerle aynı mı (aynıysa yalnızca yeniden başlatılır)?
mounted() {
    local m
    m="$(docker inspect -f '{{range .Mounts}}{{.Destination}} {{end}}' "$CONTAINER")"
    echo "$m" | grep -q '/core/bin' || return 1
    if [ -e /etc/localtime ]; then echo "$m" | grep -q '/etc/localtime' || return 1; fi
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then echo "$m" | grep -q '/host/sys/cpu' || return 1; fi
    # Önceki bir deneme sürümünün FFmpeg bağı/ortam değişkeni varsa bir kez temizlenir.
    echo "$m" | grep -q '/core/ffmpeg' && return 1
    docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$CONTAINER" | grep -q '^CORE_FFMPEG_BINARY=' && return 1
    return 0
}

# Ayar dosyası (sunucudaki yolu konteynerin /core/config bağından okunur).
CONFIG_DIR="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/core/config"}}{{.Source}}{{end}}{{end}}' "$CONTAINER")"
CONFIG="$CONFIG_DIR/config.json"

ffmpeg_binary() {
    sed -n 's/^ *"binary": *"\([^"]*\)".*/\1/p' "$CONFIG" 2>/dev/null | head -n 1
}

# config.json → ffmpeg.binary. Yalnızca bu alan değişir; öncesinin kopyası config.json.<zaman>.
set_ffmpeg_binary() { # $1 = yol
    [ -f "$CONFIG" ] || die "ayar dosyası yok: $CONFIG"
    [ "$(grep -c '"binary": *"' "$CONFIG")" = 1 ] || die "ayar dosyasında FFmpeg yolu bulunamadı: $CONFIG"
    [ "$(ffmpeg_binary)" = "$1" ] && return 0
    $SUDO cp -a "$CONFIG" "$CONFIG.$(date +%Y%m%d-%H%M%S)"
    $SUDO sed -i "s|\"binary\": *\"[^\"]*\"|\"binary\": \"$1\"|" "$CONFIG"
    [ "$(ffmpeg_binary)" = "$1" ] || die "FFmpeg yolu ayar dosyasına yazılamadı"
    echo ">> FFmpeg yolu: $1"
}

FF9=/core/bin/ffmpeg9/ffmpeg

restart_with_overlay() {
    if mounted; then
        echo ">> Konteyner yeniden başlatılıyor ..."
        docker restart "$CONTAINER" >/dev/null
    else
        echo ">> Konteyner yeni bağlarla yeniden oluşturuluyor (imaj indirilmez, birkaç saniye sürer) ..."
        compose -f "$EXTRA" up -d
    fi
}

# Bir klasörün dosyalarını hedefe koyar. Çalışan bir programın üstüne yazılamaz: her dosya yanına
# yazılıp adı değiştirilir (çalışan işlemler eski dosyayla devam eder). Hedefteki fazlalar silinir.
sync_dir() { # $1 = kaynak, $2 = hedef
    local src="$1" dst="$2" f rel
    $SUDO mkdir -p "$dst"
    (cd "$src" && find . -type d) | while read -r rel; do $SUDO mkdir -p "$dst/$rel"; done
    (cd "$src" && find . -type f) | while read -r rel; do
        f="$dst/$rel"
        # İzinler paketten değil buradan: arşiv başka bir sistemde (ör. rar) yeniden paketlenmiş olabilir.
        local mode=0644
        [ "$rel" = ./ffmpeg ] && mode=0755
        $SUDO install -m "$mode" "$src/$rel" "$(dirname "$f")/.$(basename "$f").new"
        $SUDO mv -f "$(dirname "$f")/.$(basename "$f").new" "$f"
    done
    (cd "$dst" && find . -type f) | while read -r rel; do
        [ -e "$src/$rel" ] || $SUDO rm -f "$dst/$rel"
    done
}

install_into() { # $1 = kaynak klasör (bin/, ui/ ve isteğe bağlı ffmpeg/ içerir)
    $SUDO mkdir -p "$OVERLAY/bin" "$OVERLAY/ui"
    for f in core import ffmigrate run.sh; do
        $SUDO install -m 0755 "$1/bin/$f" "$OVERLAY/bin/.$f.new"
        $SUDO mv -f "$OVERLAY/bin/.$f.new" "$OVERLAY/bin/$f"
    done
    # Klasörün kendisi konteynere bağlı: içini değiştir, klasörü değil.
    $SUDO find "$OVERLAY/ui" -mindepth 1 -delete
    $SUDO cp -a "$1/ui/." "$OVERLAY/ui/"
    if [ -f "$1/ffmpeg/ffmpeg" ]; then
        sync_dir "$1/ffmpeg" "$OVERLAY/bin/ffmpeg9"
    elif [ -f "$1/bin/ffmpeg9/ffmpeg" ]; then
        sync_dir "$1/bin/ffmpeg9" "$OVERLAY/bin/ffmpeg9"
    else
        $SUDO rm -rf "$OVERLAY/bin/ffmpeg9"
    fi
    $SUDO rm -rf "$OVERLAY/ffmpeg"   # önceki bir deneme sürümünün yeri
    if [ -f "$1/VERSION" ]; then $SUDO cp "$1/VERSION" "$OVERLAY/VERSION"; fi
    return 0
}

# Sunucunun kök adresindeki sayfa: yalnızca datarhei'nin hazır sayfası ("Did you mean to go to the
# admin panel?") Corvid'inkiyle değiştirilir; oynatıcı sitesi ya da elle konmuş bir sayfa kalır.
landing_page() {
    local data
    data="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/core/data"}}{{.Source}}{{end}}{{end}}' "$CONTAINER")"
    [ -n "$data" ] && [ -f "$HERE/ui-root/index.html" ] || return 0
    if [ ! -f "$data/index.html" ] || grep -q "Did you mean to go to the admin panel" "$data/index.html"; then
        $SUDO install -m 0644 "$HERE/ui-root/index.html" "$data/index.html"
        $SUDO rm -f "$data/index_icon.svg"
        echo ">> Kök adresteki sayfa Corvid sayfasıyla değiştirildi."
    fi
}

write_extra() {
    {
        echo "# update.sh tarafından yazıldı: core ve arayüz imajdan değil bu klasörden gelir."
        echo "services:"
        echo "  $SERVICE:"
        echo "    volumes:"
        echo "      - $OVERLAY/bin:/core/bin:ro"
        echo "      - $OVERLAY/ui:/core/ui:ro"
        # Sunucunun saat dilimi: kayıt dosya adları ve loglar UTC yerine yerel saatle yazılır.
        if [ -e /etc/localtime ]; then echo "      - /etc/localtime:/etc/localtime:ro"; fi
        # İşlemci performans modu (Ayarlar → Sunucu): konteyner işlemci frekans ayarlarını yazabilsin.
        if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then echo "      - /sys/devices/system/cpu:/host/sys/cpu"; fi
    } | $SUDO tee "$EXTRA" >/dev/null
}

# Yeni FFmpeg'i kurmadan önce çalışan konteynerin İÇİNDE ekran kartında dener: dosyalar geçici olarak
# $OVERLAY/bin/.ffmpeg9-deneme altına konur (konteynerde /core/bin/.ffmpeg9-deneme), deneme bitince
# silinir. Yayınlara, core'a ve ayarlara dokunulmaz.
gpu_test() { # $1 = paketteki ffmpeg klasörü
    local log="/tmp/corvid-gpu-testi.log" ok=1 stage="$OVERLAY/bin/.ffmpeg9-deneme" ff=/core/bin/.ffmpeg9-deneme/ffmpeg
    if [ -n "${ATLA_GPU_TESTI:-}" ]; then
        echo ">> Ekran kartı denemesi atlandı (ATLA_GPU_TESTI)."
        return 0
    fi
    [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" = true ] || die "konteyner çalışmıyor; önce başlatın: docker start $CONTAINER"
    mounted || die "konteyner henüz overlay bağlarıyla çalışmıyor; önce FFmpeg olmadan bir kez kurun ya da ATLA_GPU_TESTI=1 ile çalıştırın"
    echo ">> Yeni FFmpeg çalışan konteynerin içinde ekran kartında deneniyor (yayınlara dokunulmaz, ~20 sn) ..."
    $SUDO rm -rf "$stage"
    sync_dir "$1" "$stage"
    : > "$log"
    t() { # açıklama, ffmpeg seçenekleri...
        local name="$1"; shift
        echo "== $name: $*" >>"$log"
        if timeout 120 docker exec "$CONTAINER" "$ff" -hide_banner -nostdin -nojsonstats -loglevel error -y "$@" >>"$log" 2>&1; then
            echo "   tamam  $name"
        else
            echo "   HATA   $name"
            ok=0
        fi
    }
    local src=(-t 3 -f lavfi -i testsrc2=size=1280x720:rate=25)
    t "NVENC H.264" "${src[@]}" -c:v h264_nvenc -gpu 0 -preset:v p4 -tune:v ll -rc:v cbr -b:v 3000k -f null -
    t "NVENC örnek dosya" "${src[@]}" -c:v h264_nvenc -gpu 0 -g 25 -f mp4 /tmp/corvid-gpu-testi.mp4
    t "NVDEC + scale_cuda + NVENC" -init_hw_device cuda=gpu:0 -filter_hw_device gpu \
        -hwaccel cuda -hwaccel_device gpu -hwaccel_output_format cuda -extra_hw_frames 8 -i /tmp/corvid-gpu-testi.mp4 \
        -vf "scale_cuda=w='trunc(min(640,360*dar)/2)*2':h=360:format=yuv420p:interp_algo=lanczos" -c:v h264_nvenc -gpu 0 -f null -
    t "Tuval: hwupload + overlay_cuda" -init_hw_device cuda=gpu:0 -filter_hw_device gpu "${src[@]}" \
        -t 3 -f lavfi -i "color=c=red@0.5:size=320x180:rate=25,format=yuva420p" -filter_complex \
        "[0:v]format=yuv420p,hwupload,scale_cuda=w=1920:h=1080:format=yuv420p:interp_algo=nearest[b];[1:v]format=yuva420p,hwupload[l];[b][l]overlay_cuda=x=40:y=40:eof_action=repeat[v]" \
        -map "[v]" -c:v h264_nvenc -gpu 0 -f null -
    docker exec "$CONTAINER" rm -f /tmp/corvid-gpu-testi.mp4 >/dev/null 2>&1 || true
    $SUDO rm -rf "$stage"
    if [ $ok = 1 ]; then return 0; fi
    echo >&2
    tail -n 15 "$log" >&2
    echo >&2
    echo "Yeni FFmpeg bu sunucuda ekran kartıyla çalışmadı; HİÇBİR ŞEY DEĞİŞTİRİLMEDİ, yayınlar sürüyor." >&2
    echo "Ayrıntı: $log  (bu dosyayı bana gönderin)" >&2
    echo "Not: GeForce kartlarda aynı anda açık NVENC oturumu sınırlıdır; sınır doluysa deneme de başarısız" >&2
    echo "     olur. Bu durumda yayın sayısı azken tekrar deneyin." >&2
    exit 1
}

# Bu betiği Corvid'in klasörüne (overlay'in bir üstü, ör. /opt/corvid/update.sh) yalnızca root'un
# okuyup çalıştırabileceği biçimde koyar: geri alma ve diğer işlemler paket olmadan da yapılabilir.
keep_self() {
    local dst
    dst="$(dirname "$OVERLAY")/update.sh"
    [ "$(readlink -f "$0")" = "$(readlink -f "$dst")" ] && return 0
    local run=""
    [ "$(id -u)" = 0 ] || run="sudo -n"
    if $run install -o root -g root -m 0700 "$0" "$dst.new" 2>/dev/null && $run mv -f "$dst.new" "$dst"; then
        echo ">> Yönetim betiği: $dst   (ör. sudo bash $dst --geri-al)"
        return 0
    fi
    echo "UYARI: yönetim betiği $dst olarak kopyalanamadı; kurulum etkilenmedi." >&2
    return 0
}

# Paket zaten kurulu olanla aynı mı (core, arayüz, FFmpeg ve ayarlar)?
already_installed() { # $1 = "noui": the panel files may differ
    local f
    for f in core import ffmigrate run.sh; do cmp -s "$HERE/bin/$f" "$OVERLAY/bin/$f" || return 1; done
    if [ "${1:-}" != noui ]; then diff -rq "$HERE/ui" "$OVERLAY/ui" >/dev/null 2>&1 || return 1; fi
    if [ -f "$HERE/ffmpeg/ffmpeg" ]; then
        diff -rq "$HERE/ffmpeg" "$OVERLAY/bin/ffmpeg9" >/dev/null 2>&1 || return 1
        [ "$(ffmpeg_binary)" = "$FF9" ] || return 1
    fi
    mounted || return 1
    [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = true ] || return 1
    return 0
}

package_ffmpeg_version() { sed -n 's/^ffmpeg=//p' "$HERE/VERSION" 2>/dev/null | head -n 1; }

case "${1:-}" in
--geri-al)
    [ -x "$OVERLAY/prev/bin/core" ] || die "geri dönülecek önceki sürüm yok"
    echo ">> Önceki sürüme dönülüyor ..."
    install_into "$OVERLAY/prev"
    if [ -f "$OVERLAY/bin/ffmpeg9/ffmpeg" ]; then set_ffmpeg_binary "$FF9"; else set_ffmpeg_binary ffmpeg; fi
    write_extra
    restart_with_overlay
    wait_ready "$(sha256sum "$OVERLAY/bin/core" | cut -d' ' -f1)" ""
    echo ">> Bitti. Panelde Ctrl+F5."
    exit 0
    ;;
--eski-ffmpeg)
    [ -x "$OVERLAY/bin/core" ] || die "önce bu paketi kurun: sudo bash update.sh"
    echo ">> İmajdaki FFmpeg'e dönülüyor (core ve arayüz bu sürümde kalır) ..."
    set_ffmpeg_binary ffmpeg
    write_extra
    restart_with_overlay
    wait_ready "" ""
    echo ">> Bitti. Yeni FFmpeg'e tekrar geçmek için: sudo bash update.sh"
    exit 0
    ;;
--kaldir)
    echo ">> İmajdaki core/arayüz/FFmpeg'e dönülüyor ..."
    set_ffmpeg_binary ffmpeg
    compose up -d
    wait_ready "" ""
    echo ">> $OVERLAY yerinde bırakıldı; tekrar kullanmak için: sudo bash update.sh"
    exit 0
    ;;
"") ;;
*) die "bilinmeyen seçenek: $1" ;;
esac

if [ ! -f "$HERE/SHA256SUMS" ] || [ ! -d "$HERE/bin" ]; then
    echo "Bu, kurulu Corvid'in yönetim betiği; yeni sürüm kurmak için paketin içindeki update.sh'ı çalıştırın." >&2
    echo "Buradan yapılabilecekler:  --geri-al  --eski-ffmpeg  --kaldir" >&2
    exit 1
fi
[ "$(uname -m)" = x86_64 ] || die "bu paket x86_64 (amd64) sunucular içindir, bu sunucu: $(uname -m)"
(cd "$HERE" && sha256sum -c --quiet SHA256SUMS) || die "paket dosyaları bozuk, arşivi yeniden indirin"

if already_installed; then
    echo ">> Bu sürüm zaten kurulu; konteyner yeniden başlatılmadı, yayınlar kesilmedi."
    landing_page
    keep_self
    echo ">> Bitti. Paket artık gerekmez, silebilirsiniz:  sudo rm -rf $HERE"
    exit 0
fi

# Yalnızca panel (arayüz) değiştiyse: dosyaları yerinde değiştir, konteyneri yeniden başlatma.
if already_installed noui; then
    echo ">> Yalnızca panel değişti; konteyner yeniden başlatılmadan kuruluyor, yayınlar kesilmez."
    $SUDO find "$OVERLAY/ui" -mindepth 1 -delete
    $SUDO cp -a "$HERE/ui/." "$OVERLAY/ui/"
    if [ -f "$HERE/VERSION" ]; then $SUDO cp "$HERE/VERSION" "$OVERLAY/VERSION"; fi
    landing_page
    keep_self
    echo ">> Bitti. Panelde ve OBS panelinde Ctrl+F5 (OBS panelinde: sağ tık → Yenile)."
    echo ">> Paket artık gerekmez, silebilirsiniz:  sudo rm -rf $HERE"
    exit 0
fi

FFV=""
if [ -f "$HERE/ffmpeg/ffmpeg" ]; then
    FFV="$(package_ffmpeg_version)"
    chmod 0755 "$HERE/ffmpeg/ffmpeg" 2>/dev/null || $SUDO chmod 0755 "$HERE/ffmpeg/ffmpeg"
    # Aynı FFmpeg zaten kurulu ve kullanılıyorsa yeniden denemeye gerek yok.
    if cmp -s "$HERE/ffmpeg/ffmpeg" "$OVERLAY/bin/ffmpeg9/ffmpeg" && [ "$(ffmpeg_binary)" = "$FF9" ]; then
        echo ">> FFmpeg $FFV zaten kurulu ve aynı; ekran kartı denemesi gerekmiyor."
    else
        gpu_test "$HERE/ffmpeg"
    fi
fi

# Geri dönüş için şu an kurulu olanı sakla (aynı sürüm yeniden kuruluyorsa önceki yedek korunur).
if [ -x "$OVERLAY/bin/core" ] && ! cmp -s "$OVERLAY/bin/core" "$HERE/bin/core"; then
    $SUDO rm -rf "$OVERLAY/prev"
    $SUDO mkdir -p "$OVERLAY/prev"
    $SUDO cp -a "$OVERLAY/bin" "$OVERLAY/ui" "$OVERLAY/prev/"
    # İmajdaki FFmpeg kullanılıyorduysa önceki sürüme FFmpeg 9 dahil edilmez.
    if [ "$(ffmpeg_binary)" != "$FF9" ]; then $SUDO rm -rf "$OVERLAY/prev/bin/ffmpeg9"; fi
    if [ -f "$OVERLAY/VERSION" ]; then $SUDO cp "$OVERLAY/VERSION" "$OVERLAY/prev/VERSION"; fi
fi

echo ">> Dosyalar $OVERLAY klasörüne kopyalanıyor ..."
install_into "$HERE"
landing_page
if [ -n "$FFV" ]; then set_ffmpeg_binary "$FF9"; fi
write_extra
restart_with_overlay
wait_ready "$(sha256sum "$HERE/bin/core" | cut -d' ' -f1)" "$FFV"
keep_self
echo ">> Bitti. Panelde Ctrl+F5. Paket artık gerekmez, silebilirsiniz:  sudo rm -rf $HERE"
