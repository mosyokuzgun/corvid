# Corvid v1.9.2

NVIDIA ekran kartıyla çalışan canlı yayın sunucusu: [datarhei Restreamer](https://github.com/datarhei/restreamer)
üzerine yamalar. Ekran kartında kodlama (NVENC/NVDEC, `scale_cuda`, `overlay_cuda`), FFmpeg 9.0.2, kaynak
kesilince yedek yayına ve bekleme görseline geçiş, hat kalitesi göstergesi, yayın öncesi otomatik kontrol,
OBS paneli (`/ui/#/dock`) ve Türkçe arayüz.

## Docker imajı

Her `main` güncellemesinde GitHub Actions imajı derleyip GitHub Container Registry'ye koyar:

```bash
docker pull ghcr.io/mosyokuzgun/corvid:latest      # ya da sürümle: ghcr.io/mosyokuzgun/corvid:1.9.2
```

Gerekenler: NVIDIA sürücüsü 560 veya üstü ve [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

İlk kurulum (eski bir Restreamer kurulumu varsa ayarları ve kanalları taşır):

```bash
git clone https://github.com/mosyokuzgun/corvid.git && cd corvid/paket
sudo IMAGE=ghcr.io/mosyokuzgun/corvid:latest bash temiz-kurulum.sh
```

`IMAGE` verilmezse imaj bu depodaki yamalarla sunucuda derlenir (`build.sh`, ilk derleme 20-40 dk).
Panel: `http://<sunucu>:4501/ui/`, RTMP `1935`, SRT `6000/udp`. Klasörler: `/opt/corvid/config`, `/opt/corvid/data`.

Kurulu bir Corvid'i yeni sürüme geçirmek için Releases'teki güncelleme paketi (`update.sh` ile, aynı
konteynerde) kullanılır; ayrıntılar `paket/BENIOKU.txt` ve `CHANGELOG.md`.

## Depo

- `patches/` — datarhei `core`, `restreamer-ui`, `restreamer` ve `ffmpeg` depolarına uygulanan yamalar
  (temel commit'ler `build.sh` içinde).
- `build.sh` — kaynakları indirir, yamaları uygular, FFmpeg ve Corvid imajlarını derler
  (`TAG=...` ile imaj adı).
- `paket/` — `temiz-kurulum.sh` (ilk kurulum / geçiş), `update.sh` (aynı konteynerde güncelleme), `BENIOKU.txt`.
- `.github/workflows/docker.yml` — imajı derleyip `ghcr.io`'ya gönderir.

Lisans: Apache License 2.0, temel aldığı datarhei projeleri gibi (`LICENSE`). datarhei ile bir bağı yoktur.

## Teknik ayrıntılar

Bu, `datarhei/core` + `datarhei/restreamer-ui` + `datarhei/restreamer` (bundle) üzerine yamalardır.
Yeni bir uygulama değil, Restreamer'ın kendisi:

- **Aynı süreçler:** `restreamer-ui:ingest:<kanal>`, `…_snapshot`, `restreamer-ui:egress:<servis>:<kanal>`.
  Tek yeni süreçler, fallback açıksa oluşan `restreamer-ui:ingest:<kanal>_fallback` (yedek yayın), `…_fallback2` (bekleme görseli)
  ve `…_hls` (kanalın HLS'ini yedeğin geçtiği yoldan yazan kopyalama süreci); snapshot süreci gibi çalışırlar.
- **Aynı arayüz** ve aynı Ayarlar/Yayınlar akışı. Mevcut kanallar ve `/core/config`, `/core/data` olduğu gibi kullanılır.
- **Portlar:** panel `4501 → 8080`, RTMP `1935`, SRT `6000/udp`. Yalnızca bu üçü yayınlanır.
- **FFmpeg 9.0.2 (v1.6'dan beri):** datarhei'nin JSON istatistik ve HLS yamaları FFmpeg 9.0'a taşındı
  (`ffmpeg/contrib/ffmpeg-9.0-*.patch`; core'un okuduğu satırlar ve alanlar aynı). NVENC/NVDEC açık; `scale_cuda` ve
  `overlay_cuda` nvcc yerine clang ile derleniyor (`--enable-cuda-llvm`), bu yüzden `--enable-nonfree` gerekmiyor ve imaj
  dağıtılabilir (Docker Hub'da herkese açık paylaşılabilir). CUDA araç takımı gerekmez; sürücü kütüphanelerini NVIDIA container
  toolkit bağlar. NVENC başlıkları 12.1.14.0 (sürücü 530+). Eski yol `FFMPEG=6 ./build.sh` ile durur (6.1.1, nvcc, nonfree).
- FFmpeg 7'den itibaren kaldırılan `-vsync` ve eski NVENC preset/hız kontrolü adları, kayıtlı yayınlarda konteyner açılırken
  `ffmigrate` tarafından uyarlanır (öncesinin yedeği `config/db.<zaman>.json`). Yeni seçenekler 6.1'de de geçerlidir; geri dönüş çalışır.

## Kurulum

```bash
sudo bash temiz-kurulum.sh     # imajı derler (build.sh), eski kurulumdan ayarları taşır, corvid konteynerine geçer
```

`build.sh` FFmpeg 9.0.2 imajını (`corvid-ffmpeg:9.0.2`) derler; ilk derleme 20-40 dakika sürer, sonra yeniden kullanılır
(`REBUILD_FFMPEG=1` ile yeniden derlenir). Sürücü 560 ve üstüyse çalışma tabanı `nvidia/cuda:12.6.1-runtime-ubuntu24.04`,
daha eskiyse düz `ubuntu:24.04` olur (FFmpeg CUDA çalışma kütüphanesi kullanmaz). Derleme sonunda `scale_cuda`, `overlay_cuda`,
`h264_nvenc` ve `hevc_nvenc` kontrol edilir, nonfree bir derleme reddedilir. `FFMPEG=6 ./build.sh` önceki 6.1.1 imajını
(`CUDA=11|12` ile) derler.

### Derlemeden güncelleme (önerilen)

Güncelleme paketi derlenmiş core programını, arayüz dosyalarını ve (v1.6'dan beri) kendi kütüphaneleriyle birlikte FFmpeg'i içerir.
`sudo bash update.sh` bunları `/opt/corvid/overlay` klasörüne koyar; klasör konteynere `/core/bin` ve `/core/ui` olarak bağlıdır.
FFmpeg `/core/bin/ffmpeg9` altına gider ve `config.json` → `ffmpeg.binary` ona çevrilir. Aynı konteyner yalnızca yeniden başlatılır.
Yeni FFmpeg kurulmadan önce çalışan konteynerin içinde ekran kartında denenir (NVENC, NVDEC, `scale_cuda`, `overlay_cuda`);
başarısızsa hiçbir şey değişmez. `--geri-al` önceki sürüme (v1.5 ve imajdaki FFmpeg 6.1.1 dahil), `--eski-ffmpeg` bu sürümde
kalıp imajdaki FFmpeg'e, `--kaldir` imajın kendi core/arayüz/FFmpeg'ine döner.
Paket `/opt/corvid/paket` altına açılıp kurulur ve silinir; `update.sh` kendini `/opt/corvid/update.sh` (root, 0700) olarak saklar,
bu işlemler paket olmadan yapılır. Kurulu sürümle aynı bir paket konteyneri yeniden başlatmaz. FFmpeg kütüphanelerini kendi yanında arar
(`$ORIGIN/lib`), imajdakilerle karışmaz.

### Güncelleme: her seferinde `build.sh` gerekir mi?

Yalnızca kodu değiştiren yeni bir yama paketi aldığınızda. Ayar, kanal ve yayın değişiklikleri arayüzden yapılır, derleme gerekmez;
kanallarınız `/core/config` ve `/core/data` birimlerinde durur ve yeniden oluşturmada korunur.

Sık duyulan yavaşlık FFmpeg değildir (o yalnızca bir kez derlenir). Yavaş olan, arayüzün npm paketlerinin her derlemede baştan inmesiydi.
Dockerfile artık bağımlılıkları ayrı bir katmanda kurar ve yarn / Go / arayüz derleme önbelleklerini BuildKit önbelleğinde tutar:

- İlk derleme bu değişiklikten sonra **bir kez** eskisi kadar sürer (önbellek dolar).
- Sonraki derlemeler yalnızca değişen kısmı derler (genellikle birkaç dakika).
- Önbellek disk kullanır; yer açmak için `docker builder prune` çalıştırabilirsiniz (sonraki derleme yine uzun sürer).
- Sadece yeniden başlatmak için `docker compose -f src/restreamer/docker-compose.nvidia.yml up -d --force-recreate` yeterlidir.

Hostta NVIDIA Container Toolkit olmalı.

Kendi `docker run` komutunuzu kullanıyorsanız şunu ekleyin:
`--gpus all -e NVIDIA_DRIVER_CAPABILITIES=compute,video,utility`.
`video` olmadan NVENC/NVDEC kütüphaneleri konteynere bağlanmaz. `utility` olmadan da `nvidia-smi` (GPU izleme) çalışmaz.

## Ne değişti

### 1. NVENC / NVDEC / zero-copy (UI)
| Dosya | Değişiklik |
|---|---|
| `src/misc/coders/Encoders/video/nvenc.js` (yeni) | p1–p7 preset, tune (hq/ll/ull/lossless), RC (CBR/VBR/CQP), multipass (disabled/qres/full), B-frame, lookahead, Spatial/Temporal AQ, **GPU seçimi** (Otomatik veya 0, 1, 2…). Eski `slow/medium/llhq…` preset'leri ve `cbr_ld_hq` gibi eski RC değerleri yeni karşılıklarına otomatik çevrilir. ll/ull seçilince B-frame 0 olur, `-zerolatency 1 -delay 0` eklenir. |
| `h264_nvenc.js`, `hevc_nvenc.js`, `av1_nvenc.js` | Ortak modülü kullanan encoder'lar. HEVC ve AV1 yeni (Restreamer'da yalnızca H.264 vardı). |
| `Decoders/video/nvdec.js` | Zero-copy: `-init_hw_device cuda=gpu:{gpu} -filter_hw_device gpu -hwaccel cuda -hwaccel_device gpu -hwaccel_output_format cuda -extra_hw_frames 8`. Decoder, CUDA filtreleri ve NVENC tek CUDA context'ini paylaşır. |
| `utils/metadata.js` → `buildVideoFilterGraph` | Kareler CPU ile GPU arasında geçerken `hwdownload`/`hwupload` otomatik eklenir. Stok Restreamer'da NVDEC + CPU filtresi ("Impossible to convert") ya da NVDEC + libx264 kırılıyordu; artık çalışıyor. |

### 2. Canvas / dikey video (UI)
`src/misc/filters/video/Canvas.js`: profil düzenleyicideki filtreler arasında **Canvas (GPU)** ve
`ScaleCUDA.js` ile **Ölçekle (GPU)**. 9:16, 1:1, 4:5 ve 16:9 hazır boyutlar; sürükle-bırak önizleme;
X/Y/genişlik/yükseklik; contain/cover/stretch sığdırma. Arka plan bulanık video, renk ya da yüklenen görsel olabilir.
Hepsi `scale_cuda` + `overlay_cuda` ile, ingest'in mevcut `-filter:v` seçeneği içinde çalışır; süreç yapısı değişmez.
Arka plan görseli VRAM'e bir kez yüklenir. Filtreler yalnızca FFmpeg'te `scale_cuda`/`overlay_cuda` varsa görünür.
Çıkış kare pikselle (`setsar=1`) üretilir. Önceki sürümlerde kanvas 1080x1920 piksel olsa da kaynaktan 256:81 piksel oranını
miras alıyordu; oynatıcılar ve platformlar bu yüzden görüntüyü 16:9'a basık gösteriyordu. Video kutusu da artık görüntü oranına
(`dar`) göre yerleşir, yani kanvastan önce "Ölçekle 1080x1920" kullanılmış olsa bile video kutuyu doğru doldurur.

### 3. Süreç yönetimi, gecikme, I/O (core + UI)
- `core/process/process.go`: **üstel backoff + jitter.** Süreç ayarındaki yeni alan "En uzun yeniden bağlanma beklemesi"
  (`reconnect_delay_max_seconds`). Varsayılan 3 sn'den başlar ve iki katına çıkarak en fazla 10 sn'ye uzar
  (stok Restreamer sabit 15 sn bekler; bu hiçbir zaman ondan yavaş değildir). Sağlıklı çalışmış bir süreçte sayaç sıfırlanır.
  0 = eski sabit bekleme. İlk sürümlerdeki 60 sn varsayılanı kesintiden sonra her kanalın bir dakikaya kadar geç dönmesine yol
  açıyordu (zincirleme kanallarda her adım için bir dakika); kayıtlı 60 değerleri kanal kaydedilirken 10'a çevrilir.
- Core'un mevcut süreç yönetimi (tek `Wait`, stale timeout, limitler) korundu. Her başlatmadan önce çalışan
  yeni `OnBeforeStart` kancası GPU atamasını yapar.
- HLS zaten core'un RAM içi `memfs`'inde (Restreamer varsayılanı), diske yazılmıyor. Bu yüzden tmpfs'e gerek yok.

### 4. Enterprise
- **Çoklu GPU yük dengeleme** (`core/gpu/`): `{gpu}` yer tutucusu, her başlatmada en uygun GPU'nun numarasıyla değiştirilir.
  Skor NVENC/NVDEC kullanımı, VRAM, oturum sayısı ve sıcaklıktan hesaplanır. Fazla ısınmış (≥85°C), VRAM'i dolmuş ya da
  kodlayıcısı dolu GPU'ya, boşta başka GPU varsa iş verilmez; hiçbiri uygun değilse en az yüklü olan yine kullanılır
  (önceden başlatma reddediliyordu, tek GPU'lu sunucuda yük anında hiçbir süreç yeniden başlayamıyordu).
  Yalnızca elle ayarlanan NVENC oturum limiti (`CORE_GPU_MAX_ENCODER_SESSIONS`) kesin sınırdır. Kendi atamalarını da saydığı için aynı anda başlayan kanallar tek GPU'ya yığılmaz.
  `CUDA_DEVICE_ORDER=PCI_BUS_ID` ile nvidia-smi ve CUDA numaraları eşleşir.
  GPU'su olmayan sistemde `{gpu}` → 0 olur, davranış eskisiyle aynı kalır.
- **Kesintisiz failover** (`core/rtmp/failover.go`): Egress'ler `{rtmp,name=<kanal>.stream}` okur.
  Ana ingest koptuğunda core'un RTMP sunucusu aboneyi kapatmaz; sırayla `<kanal>_fallback.stream` (yedek yayın), o yoksa ya da sessizse
  `<kanal>_fallback2.stream`'e (bekleme görseli) anahtar karede geçer,
  zaman damgalarını sürekli tutar ve SPS/PPS'i akış içine ekler. Ana kaynak 2 sn kararlı kalınca geri döner.
  YouTube/Twitch bağlantısı kopmaz. Fallback tanımlı değilse oynatıcı 10 sn bekletilir
  (`CORE_RTMP_FAILOVER_GRACE_SECONDS`), böylece kısa ingest yeniden başlatmaları da yayınları düşürmez.
  UI tarafı: Kanal düzenle → İşleme ve Kontrol → **Yedek (Fallback)**. Bekleme görseli yükleyin ya da yedek yayın URL'si girin;
  yedek yayın seçiliyken bir görsel de yüklerseniz o **son çare** olur (yedek yayına ulaşılamazsa görüntü kararmaz).
  **Yedeği kontrol et** düğmesi RTMP sunucusunu, yardımcı süreçleri ve her yayın hedefinin nereden okuduğunu gösterir.
  Fallback açık kanallarda egress kaynağı otomatik olarak dahili RTMP'ye çevrilir. RTMP sunucusunun Ayarlar'dan açık olması gerekir.
- **Backoff:** yukarıda (madde 3).

### 5. İzleme
- `GET /api/v3/gpu`: canlı GPU değerleri ve dengeleyicinin sıralaması, gerekçeleriyle.
- Core'un mevcut metrik sistemine `gpu` eklendi, `/metrics` (Prometheus) altında: `gpu_temperature_celsius`,
  `gpu_memory_used_bytes`, `gpu_encoder_utilization_percent`, `gpu_decoder_utilization_percent`, `gpu_encoder_sessions`,
  `gpu_assigned_processes` ve diğerleri. Akış FPS/bitrate/düşen kare metrikleri Restreamer'da zaten vardı
  (`restream_process…`); bunlara dokunmadım.
- UI: kanal sayfasında Yayınlar'ın altında **GPU paneli** (NVENC, NVDEC, VRAM çubukları, 2 dk'lık mini grafikler,
  oturum ve atama sayıları). GPU yoksa panel görünmez.

Ortam değişkenleri: `CORE_GPU_ENABLE=auto|true|false`, `CORE_GPU_NVIDIA_SMI`, `CORE_GPU_MAX_ENCODER_SESSIONS`,
`CORE_RTMP_FAILOVER=false`, `CORE_RTMP_FAILOVER_GRACE_SECONDS`.

## Doğrulama
Bu ortamda NVIDIA GPU ve Docker daemon yoktu. Doğrulananlar:
- **Core:** `go vet` temiz. Değişen paketlerin testleri geçiyor (yeni testler: backoff, nvidia-smi XML ayrıştırma,
  dengeleyici, failover geçişi/geri dönüşü/bekleme süresi).
- **Gerçek core binary'siyle uçtan uca:** core API'si üzerinden ingest, fallback ve egress süreçleri kuruldu.
  Ingest durdurulup yeniden başlatıldı. Egress 29 sn boyunca hiç kopmadı; çıktı kare kare
  ana yayın → slate → ana yayın oldu, decode hatası çıkmadı. Sahte bir `nvidia-smi` ile `{gpu}` boştaki GPU'ya çözüldü;
  `/api/v3/gpu` ve `/metrics` doğru değerleri verdi.
- **UI:** 105 test geçiyor. Canvas grafiklerinin 9 kombinasyonu aynı topolojideki CPU filtreleriyle gerçek FFmpeg'te
  çalıştırıldı (çıktı 1080×1920). Production build uyarısız. Arayüz core tarafından sunulurken headless Chrome'da açıldı.
- Yamalar upstream'in temiz checkout'una sorunsuz uygulanıyor; core yamalardan derleniyor.

GPU'lu sunucuda kontrol (derlemeden sonra):

```bash
docker exec restreamer ffmpeg -hide_banner -filters | grep -E "scale_cuda|overlay_cuda"   # ikisi de görünmeli
curl -s http://localhost:4501/api/v3/gpu                                                  # GPU listesi
```

## Yedek (fallback) nasıl çalışır, neyi kapsar

- Geçiş, core'un dahili RTMP sunucusunda olur; yani **RTMP'den okuyan yayınlar** (YouTube, Twitch vb. yayın hedefleri) kopmadan yedeğe geçer.
- **İşlenmiş yayın (program) yedeklenir, ham giriş değil.** Kaynağı Restreamer'ın kendi RTMP adresine gönderiyorsanız (OBS vb. → `rtmp://sunucu/<uygulama>/<kanal>.stream`),
  o adreste ham 16:9 giriş durur. Bu modda ingest, Canvas/ölçekleme/yeniden kodlamadan geçmiş yayını ayrıca `<kanal>_program.stream` yoluna verir;
  yayın hedefleri ve yedek görsel bu yolu kullanır. Böylece 9:16'ya çevirdiğiniz görüntü yayın hedeflerine de 9:16 gider.
  Kaynağı Restreamer çekiyorsa (RTMP/SRT/HLS/RTSP/kamera) program zaten `<kanal>.stream` yolundadır.
- **Yedek zinciri**: `_fallback` (yedek yayın) tercih edilir, `_fallback2` (görsel) son çaredir. Yedek yayın kayıtlı ama sessizse
  (ör. SRT adresi reddediliyorsa) atlanır ve görsele geçilir; yedek yayın sonradan gelirse görselden ona yükselinir,
  ana kaynak dönünce ana yayına dönülür. **Önemli:** yedek yayın adresi gerçekten yayın yapan bir kaynağa işaret etmelidir;
  Restreamer'ın kendi SRT/RTMP sunucusuna bakıyorsa o adreste biri yayın yapıyor olmalı, yoksa süreç "Peer rejected connection" ile düşer.
- **Kaynak kesilince**: bağlantı kapanırsa hemen, ingest bağlı kalıp sessizleşirse (kaynağı çekerken olağan durum) `CORE_RTMP_FAILOVER_STALL_SECONDS`
  (varsayılan 3 sn) sonra yedeğe geçilir. Kaynak 2 sn boyunca düzgün akınca ana yayına dönülür.
- Kanalı kaydedince: ingest dahili RTMP'ye yayın yapmaya başlar (kanalda "RTMP" ayrıca açık olmasa bile) ve **mevcut yayınlar** otomatik olarak
  HLS yerine RTMP girişine çevrilir. Yedek kapatılırsa HLS'e geri döner.
- **Ayarlar → RTMP** kapalıysa yedek çalışamaz; kanal sayfasında uyarı çıkar.
- **Önizleme, gömülü oynatıcı ve anlık görüntü de yedeğe geçer.** Yedek açıkken kanalın HLS'ini ingest değil `<kanal>_hls`
  süreci yazar: işlenmiş yayını dahili RTMP'den (yedeğin geçiş yaptığı yerden) kopyalar. Dosya adları ve temizlik kuralları aynıdır.
  Bu süreç yeniden başlarsa listeye "yayın bitti" yazılmaz, izleyiciler kopmadan devam eder.
- Geçişte zaman damgalarında boşluk bırakılmaz. Önceki sürümde kesintinin algılandığı 3 sn zaman çizgisine ekleniyordu;
  tarayıcıdaki HLS oynatıcısı bu boşlukta son karede donuyor, yedeği çok geç gösteriyordu. Bu, paketteki arayüz gerçek
  Chrome'da tıklanarak denenirken bulundu: düzeltmeden sonra önizleme kesintiden ~6 sn sonra yedeği, kaynak dönünce ~10 sn
  sonra ana yayını takılmadan gösteriyor (CPU kodlayıcı, tek kanal, RTMP kaynağı).
- **"Bağlantıyı kes"** yalnızca kaynağı keser. Yedek süreçleri, HLS ve yayın hedefleri çalışmaya devam eder; kanal kartı
  önizlemeyi "Yedek yayında" etiketiyle gösterir. Yayını tamamen bitirmek için yayın hedeflerini ayrıca durdurun ya da yedeği kapatın.
- Yedekler ana yayınla aynı kodlayıcı ayarlarıyla kodlanır; SPS/PPS birebir aynı olduğu için tarayıcı oynatıcıları geçişte takılmaz.
- Ana yayına dönüş, kaynak 3 sn gerçek zamanlı akınca olur (`CORE_RTMP_FAILOVER_RECOVER_SECONDS`). Yeniden başlayan bir ingest'in
  birikmiş eski görüntüyü hızla oynatması (ör. başka kanalın HLS'ini okuyan kanal) ana yayın sayılmaz, izleyiciler eski kare görmez.

- **Arka plan görseli (Canvas):** Yayın (publication) ekranlarında da yükleme çalışır. Önceden bu ekranlarda yükleme sessizce boş dönüyor ve
  bulanık arka plana düşülüyordu; artık yükleme başarısızsa hata görünür.

Bu akış gerçek core + FFmpeg ile uçtan uca denendi (GPU olmadan, CPU kodlayıcıyla): itme modu, çekme modu ve yedek sonradan açılan kanal.
Ayrıca iki kanallı zincir: A kanalı kamerayı alır, D kanalı A'nın HLS'ini HTTP ile okuyup Ölçekle 1080x1920 + 9:16 kanvas uygular;
D'nin yedeği ulaşılamayan bir SRT yayını ve bekleme görselidir. Kamera 60 sn kesildiğinde yayın hedefi kopmadan 3 sn içinde
görsele geçti, kamera dönünce 7–12 sn içinde ana yayına döndü (önceki sürümde 90 sn'den uzun sürüyordu ve yayın hedefi düşüyordu).
Kayıt baştan sona 1080x1920, SAR 1:1, DAR 9:16; ileri sarıldığında da çözme hatası yok.
Üçünde de yayın hedefi 1080×1920 canvas'ı aldı, kaynak kesilince bekleme görseli geldi, kaynak dönünce ana görüntüye dönüldü.

## Paket 1 (kayıt, kırpma bayrağı, uyarılar)

- **Yayın kaydı:** kanal başına `<id>_record` yardımcı işlemi, yayına çıkan görüntüyü yeniden kodlamadan `/core/data/recordings/<kanal>_<gizli ek>/` altına sabit uzunlukta dosyalar olarak yazar. Saklama süresi core'un `cleanup` kuralıyla uygulanır. Disk dosya sistemi HTTP ile sunulduğu için klasör adında rastgele bir ek vardır.
- **H.264 kırpma bayrağı:** çıkış genişliği açıkça ayarlanmışsa (kanvas ya da sabit ölçek) ve 16'ya bölünmüyorsa kodlayıcı çıkışına `-bsf:v h264_metadata=crop_right=N` eklenir.
- **Adres denetimi:** `src/utils/address.js`; **güvenlik uyarıları:** `src/utils/security.js`.
- **Core:** `FAILOVER` log satırları geçişin nedenini içerir.
