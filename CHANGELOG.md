# Corvid — Değişiklik günlüğü

Corvid, açık kaynaklı **datarhei Restreamer** (arayüz) ve **datarhei Core** (sunucu) üzerine
geliştirildi; ikisi de Apache License 2.0 lisanslıdır. datarhei ile bir bağı yoktur.
Bu günlük, ilk NVIDIA yamasından bugüne yapılan her şeyi sırasıyla anlatır.
v1'den önceki sürümler "Paket 1–34" adıyla dağıtıldı.

---

## v1.9.2 — 24 Kasım 2026

**Bir kanal başka bir kanalın yayınını kaynak olarak kullanabilir** (ör. A yatay, B dikey)
- Kaynak → Ağ kaynağı → Alma modu → SRT/RTMP → "Girdi akışı" listesinde diğer kanallar artık
  adıyla görünür, o an kimse göndermiyor olsa da:
  - "A: kaynağı" — OBS'in A'ya gönderdiği yayının aynısı (SRT veya RTMP). A kapalıyken de
    çalışır; yalnız A'nın yedeği bu kanala geçmez.
  - "A: yayın çıkışı (yedek ve bekleme görseliyle)" — RTMP altında; A'nın yayına verdiği görüntü.
    A'nın yedeği ve bekleme görseli de gelir; A'nın bağlı olması gerekir.
- Önceden listede yalnızca o an gönderilen yayınlar uzun kodlarıyla çıkıyordu, iç yedek yayınları
  da karışıyordu. Kanalın kendi yayını "Akışı adrese gönder ..." olarak kalır.
- Yalnızca panel değişti; v1.9 veya v1.9.1 kuruluysa yayınlar kesilmeden kurulur.

---

## v1.9.1 — 24 Kasım 2026

**OBS paneli genişledi** (`.../ui/#/dock`)
- Önizleme penceresi (sessiz). Göz simgesiyle gizlenip açılır; seçim o bilgisayarda hatırlanır.
- Bağlan / Bağlantıyı kes / Yeniden bağlan. "Bağlantıyı kes" önce "Yayın bitirilsin mi?" diye
  sorar; 5 saniye içinde yeniden tıklanmazsa vazgeçilir. Bitirince ana sayfadaki gibi kaynak,
  yedek, kayıt ve yayınlar durur.
- Kayıt başlat/durdur (kanalda kayıt ayarlıysa).
- Yayınlar listesi: her hedefin durumu (Yayında, Bağlanıyor, Hata...) ve aç/kapa düğmesi;
  sunucudaki izleyici sayısı.
- Düğmeler operatör ve yönetici hesaplarında görünür; "İzleyici" hesabı yalnızca izler.

**Kurulum**
- Paket yalnızca paneli değiştiriyorsa (core ve FFmpeg aynıysa) `update.sh` konteyneri yeniden
  başlatmaz; yayınlar kesilmez. v1.9 kuruluysa v1.9.1 böyle kurulur.

---

## v1.9 — 24 Kasım 2026

**Yayın öncesi otomatik kontrol** (Sistem → Sunucu)
- Seçilen saatlerde ve günlerde (ör. her gün 08:30) sunucu kendini kontrol eder; "Şimdi kontrol
  et" ile istendiği an da çalışır. Panelin açık olması gerekmez. Yayına hiçbir şey çıkmaz.
- Kontrol edilenler: ekran kartı kodlayıcısı (2 saniyelik deneme kodlaması; kart zaten
  kodluyorsa ek oturum açılmaz), boş disk alanı, RTMP/SRT yayın anahtarı ve her kanal için ana
  kaynak ile yedek yayının bağlı olup olmadığı ve hat kalitesi, bekleme görselinin dosyası,
  yayın hedeflerine (ör. YouTube) bağlantı kurulup kurulamadığı. Hedeflerin yayın
  anahtarları sonuçlarda görünmez.
- Yayından önce kimsenin göndermiyor olması sorun sayılmaz ("Bakılmadı").
- Son 30 kontrol saklanır; son sonuç ve geçmiş bu bölümde görünür. Sorun bulan bir kontrolden
  sonra ana sayfada kırmızı bir şerit çıkar (kapatılabilir; yeni bir sorun çıkana kadar
  gizli kalır). Bildirim gönderilmez.
- Saatler panelin açıldığı bilgisayarın saat dilimine göre kaydedilir.

**OBS paneli** (`http://<sunucu>:4501/ui/#/dock`)
- OBS'te özel tarayıcı paneli olarak eklenecek dar görünüm: yayın şeridi (kaynak / yedek /
  bekleme görseli, hat kalitesiyle), bit hızı, fps, yayın süresi, kayıt durumu, ses seviyesi
  ve sessizlik/siyah/donma uyarıları, son kontrolün sonucu ve "Kontrol et" düğmesi.
- Başlık, alt bilgi ve açılır pencereler yok; 300 piksel genişlikte kaydırmadan okunur.
- Yalnızca gösterir; ana sayfanın da yaptığı gibi yayına çıkan kanalın yedeklerini başlatır.

**Diğer**
- Tarayıcı dili "tr-TR" gibi bölgeli olduğunda panel artık Türkçe açılır (önceden İngilizce).
- Tanılama dosyasına kontrol sonuçları da eklendi.

---

## v1.8.1 — 23 Kasım 2026

**Kurulum düzeni**
- Güncelleme paketi ev klasörüne değil `/opt/corvid/paket` klasörüne açılır ve kurulumdan sonra
  silinir; sunucuda Corvid'e ait her şey `/opt/corvid` altında durur.
- `update.sh` kurulumdan sonra kendini `/opt/corvid/update.sh` olarak saklar (sahibi root, yalnızca
  root okuyup çalıştırabilir). Geri alma (`--geri-al`), imajdaki FFmpeg'e dönme (`--eski-ffmpeg`)
  ve kaldırma (`--kaldir`) için paket gerekmez.
- Kurulu sürümle aynı bir paket konteyneri yeniden başlatmaz; yayınlar kesilmez.

---

## v1.8 — 23 Kasım 2026

**Hat kalitesi** (ana ekrandaki yayın şeridi)
- Kaynak ve yedek yayın bölümlerinde, yayının bu sunucuya son 10 dakikada ne kadar düzgün geldiği
  yazıyor: "Hat iyi", "Hat dalgalı", "Hat zayıf"; şu an veri gelmiyorsa "N sn'dir veri gelmiyor".
- Üzerine gelince (ya da klavyeyle odaklanınca) ayrıntılar: kaç kez veri gelmedi (en uzun ve toplam
  süre), bağlantı kaç kez koptu, sonuncusu ne zaman.
- Ölçülen: 1 saniye ve üstü veri boşlukları ve bir dakika içinde geri bağlanan kopmalar. Bilerek
  durdurulan bir yayın kopma sayılmaz. "Zayıf": 2 kopma, toplam 10 sn veri boşluğu, 5 sn'lik bir
  boşluk ya da şu an 5 sn'dir veri gelmemesi.
- Bu sunucuya RTMP ya da SRT ile gönderilen yayınlar için gösterilir (ana kaynak ve yedek); başka
  bir adresten çekilen kaynaklarda gösterilmez. Tanılama dosyası bu bilgiyi de içeriyor.

---

## v1.7 — 23 Kasım 2026

**Yedeğe geçiş süreleri panelde** (Sistem → Sunucu → "Yedeğe geçiş")
- Bağlı kalıp görüntü göndermeyen bir kaynağın ne kadar bekleneceği artık iki ayrı ayar: ana kaynak →
  yedek (varsayılan 3 sn; 0 = yalnızca bağlantı koptuğunda) ve yedek → bekleme görseli (varsayılan 3 sn).
  Önceden ikisi aynı süreydi ve yalnızca sunucu ayarından (`CORE_RTMP_FAILOVER_STALL_SECONDS`) değişiyordu.
- Kararsız bir yedek hattı (ör. mobil internet) için yedek süresi uzatılırsa kısa kesintilerde
  izleyiciler bekleme görseline atlamaz; görüntü o sırada donar.
- Değişiklik hemen geçerli olur, şu an izleyenler için de; yeniden başlatma gerekmez. Ayar
  `/opt/corvid/config/failover.json` dosyasında saklanır.
- Kanalın yedek bölümünde bu ayara bağlantı var. Tanılama dosyası bu ayarları da içeriyor.

**RTMP düzeltmesi**
- Sunucunun yayıncılara gönderdiği alındı onayı, spesifikasyondaki gibi toplam alınan bayt sayısını
  taşımıyordu (her onayda sıfırlanan bir sayaç gidiyordu). Onaylara göre akış denetimi yapan bazı
  donanım kodlayıcıları bu yüzden takılabiliyordu. OBS bu onayları kullanmadığı için etkilenmiyordu.

**Güncelleme (`update.sh`)**
- Paketteki FFmpeg kurulu olanla aynıysa ekran kartı denemesi atlanır.

---

## v1.6 — 20 Kasım 2026

**FFmpeg 9.0.2** (önceki: 6.1.1, datarhei'nin son derlemesi)
- datarhei'nin FFmpeg'e eklediği iki yama 9.0'a taşındı: paneldeki kbit/s, FPS, kare, GOP, boyut
  ve akış bilgilerini üreten JSON istatistik yaması (FFmpeg 7'de yeniden yazılan, iş parçacıklı
  yapıya göre) ve HLS yaması (kopyalanan yayında bant genişliği tahmini, akış haritası). Core'un
  okuduğu satırlar ve alanlar aynı; aynı komutlar 6.1.1 ve 9.0.2 ile çalıştırılıp core'un
  sonuçları karşılaştırıldı (HLS/tee, yeniden kodlama, filtre grafiği, MP3, SRT, RTMP, prob).
- NVENC/NVDEC ve GPU tuvali (`scale_cuda`, `overlay_cuda`) duruyor. CUDA filtreleri artık nvcc
  yerine clang ile derleniyor; FFmpeg "nonfree" değil, imaj dağıtılabilir (Docker Hub'da herkese
  açık paylaşılabilir). Kullanılmayan libfdk-aac ve libnpp çıkarıldı.
- GTX 1050 / sürücü 580 ile uyumlu: NVENC başlıkları aynı (12.1.14.0), CUDA araç takımı
  gerekmiyor.
- Süre gösterimi düzeltmesi: eski yama saniyenin yüzde birlerini sıfırsız yazıyordu (20,03 sn
  "20.3" görünüyordu). Kare hızı/GOP tahmini artık ilk anahtar kareden değil ikinciden başlıyor
  (ilk ölçüm zaman damgası 0'dan hesaplanıp ortalamayı bozuyordu).

**Kayıtlı yayınlar otomatik uyarlanır**
- FFmpeg 7'de kaldırılan `-vsync` ve eski NVENC preset/hız kontrolü adları (hp, hq, ll, llhq,
  llhp, lossless…, cbr_ld_hq, cbr_hq, vbr_hq), konteyner açılırken `p1…p7` + ayar ve `cbr`/`vbr`
  karşılıklarına çevrilir. Öncesinin yedeği alınır. Yeni adlar 6.1.1'de de geçerli: geri dönüşte
  yayınlar çalışmaya devam eder.
- Bilinmeyen, daha yeni bir FFmpeg sürümü konteynerin açılmasını artık engellemiyor.

**Panel**
- FFmpeg 7, 8 ve 9 kabul ediliyor (önceden yalnızca 5.1 ve 6.1).
- MP3, Opus, Vorbis ses kodlayıcıları FFmpeg 7 ve sonrasında artık `-vsync` eklemiyor (bu seçenekle
  yayın açılmazdı). Opus gecikme ayarı FFmpeg'e yanlış (tiresiz) geçiyordu, düzeltildi.

**Core**
- FFmpeg 7 ve sonrasının filtre ve format listeleri okunuyor. (Okunmasaydı panel filtreleri,
  GPU tuvalini ve çıkış formatlarını göremezdi.)

**Güncelleme (`update.sh`)**
- FFmpeg güncelleme paketiyle gelir ve aynı `corvid` konteynerinde kullanılır: kütüphaneleriyle
  birlikte konteynere zaten bağlı olan `/opt/corvid/overlay/bin/ffmpeg9` klasörüne konur, ayar
  dosyasındaki FFmpeg yolu (`config.json` → `ffmpeg.binary`) `/core/bin/ffmpeg9/ffmpeg` olur.
  Konteyner yalnızca yeniden başlatılır; yeniden oluşturulmaz, imaj değişmez, sunucuda derleme yok.
- Yeni FFmpeg, kurulmadan önce çalışan konteynerin içinde ekran kartında denenir (NVENC, NVDEC,
  `scale_cuda`, `overlay_cuda`); başarısızsa hiçbir şey değişmez.
- `--eski-ffmpeg`: bu sürümde kalıp imajdaki FFmpeg 6.1.1'e döner. `--geri-al` v1.5'e döner.
- "Çalışıyor mu" kontrolü konteynerin içindeki dosyalara bakıyor; panel API'si oturum açmadan sürüm
  bildirmediği için önceki sürümlerde 90 sn sonra gereksiz bir uyarı çıkabiliyordu.

**Kaynak**
- `build.sh` artık FFmpeg 9.0.2 imajını (`corvid-ffmpeg:9.0.2`) derliyor; `FFMPEG=6` ile önceki
  6.1.1 imajı derlenebilir.

---

## v1.5 — 18 Kasım 2026

- Uygulamanın adı her zaman **Corvid**; Ayarlar → Genel'deki "Uygulama adı" alanı kaldırıldı
  (destek metni duruyor). Önceden kaydedilmiş bir ad yok sayılır.
- Üst çubuktaki logo ve ad her sayfadan ana ekrana götürür.
- Ana ekranda "Adresi kopyala" satırında **Gönderme adresi**: kaynağı bu sunucunun RTMP ya da SRT
  sunucusuna gönderilen kanallarda OBS'e/kodlayıcıya girilecek adres, anahtarıyla birlikte tek
  tıkla kopyalanır (önceden kanal düzenlemeye girmek gerekiyordu).
- Ana ekranda **Paylaş** (yalnızca yönetici): her izleyiciye kendi kodu olan adresler verilir:
  oynatıcı bağlantısı, HLS (VLC, akıllı TV), RTMP ve SRT. İzleyicinin adı (isteğe bağlı) ve süresi
  (1 gün, 1 hafta, 30 gün) seçilir; kodlar listelenir ve tek tek kaldırılabilir. Kaldırılan kod yeni
  bağlantıları hemen durdurur (RTMP/SRT'de bağlı izleyici yeniden bağlanana kadar sürer).
- **Oynatıcı ve HLS yalnızca kodla** (kanal başına, isteğe bağlı, kapalı başlar): açıkken kodsuz
  oynatıcı/HLS adresleri, gömülü oynatıcılar ve oynatıcı sitesi çalışmaz. Kod adresin yolundadır
  (`/memfs/k/<kod>/<kanal>.m3u8`), böylece her oynatıcıda çalışır. Paneldeki önizleme kendi
  imzalı biletiyle çalışmaya devam eder (izleyici hesapları dahil).
- Kopyalama, tarayıcının panosu reddettiğinde (düz HTTP, izin) eski yönteme geçer; "kopyalanamadı"
  hatası yerine kopyalar.
- Erişilebilirlik: yalnızca simgeden oluşan düğmelerin (kanallar, menü, düzenle, yardım, ekle,
  kopyala) ve adres kutularının ekran okuyucu için adı var; seçili düğmelerde yazı okunaklı
  (karşıtlık 6,99:1); pencereler ekranın ortasında açılır, Esc ile kapanır, açılınca imleç ilk
  alanda. Ana sayfalar axe-core ile WCAG 2 AA denetiminden hatasız geçiyor.
- Adres kutularındaki kopyala düğmesi de panonun reddettiği durumda eski yönteme geçer.
- Durum ve araçlar: "SRT kaynağı" bölümü yalnızca kaynağı bu sunucunun SRT sunucusu olan kanallarda
  görünür.
- Yardım: yedek yayının adresinin nereden alınacağı (v1.3'teki düğmeler) anlatılıyor.

---

## v1.4 — 18 Kasım 2026

**İşlemci performans modu (isteğe bağlı)**
- Ayarlar → Sunucu: işlemcinin anlık hızı, kullanılan mod ve sürücü görünür; mod panelden
  seçilir: "Sistemin ayarı" (hiçbir şey değiştirilmez), "Performans (yayın için önerilen)",
  "Güç tasarrufu" ve sunucunun desteklediği diğerleri.
- Seçim saklanır, sunucu her açıldığında core tarafından yeniden uygulanır. "Sistemin ayarı"na
  dönülünce eski mod geri yüklenir. Değişiklik hemen geçerli olur, yayınlar kesilmez.
  Yalnızca yönetici değiştirebilir.
- Konteyner sunucunun işlemci frekans ayarlarına (`/sys/devices/system/cpu`) erişir; `update.sh`
  bu bağı ekler ve konteyneri bir kez yeniden oluşturur.

**Küçük düzeltmeler**
- Kanal düzenlemede sihirbaz ve düzenleme simgeleri parantezleriyle birlikte kalır, satır
  sonunda kopmaz; iki satırlık menü öğeleri sola hizalı.
- Türkçe metinlerde "akış anahtarı" yerine her yerde "yayın anahtarı"; yalnızca OBS'in kendi alan
  adı anılırken OBS'teki gibi "Akış Anahtarı".
- `update.sh` sonunda artık "kanalları yeniden kaydedin" demiyor (gerekmiyor).

---

## v1.3 — 18 Kasım 2026

- Kanalı düzenle → Yedek ve kayıt → Yedek yayın: "RTMP ile gönderilen yedek" ya da "SRT ile
  gönderilen yedek" seçilince, yedeği gönderecek ikinci cihazın (OBS, kodlayıcı) adresi ve
  anahtarı panelde oluşturulur ve kopyalanabilir; RTMP için OBS'in "Sunucu" ve "Akış anahtarı"
  alanları ayrı. Yedek `<kanal>-backup` adıyla bu sunucuya gönderilir, yedek süreci oradan okur.
  Sunucu kapalıysa ya da anahtarı yoksa aynı yerde açılır, anahtar oluşturulur.
- Başka bir yerden çekilen yedek için adres kutusu eskisi gibi kullanılabilir.

---

## v1.2 — 18 Kasım 2026

- Durum ve araçlar → "SRT kaynağı": kaynağı bu sunucunun SRT sunucusu olan kanallar artık
  tanınıyor ve gelen hız, kayıp paketler, gecikme penceresi gösteriliyor. Panel bu adresleri
  `{srt,name=...}` biçiminde sakladığı için önceden "dahili SRT sunucusundaki bir yayın değil"
  yazıyordu.
- Önizleme görüntüsü dakikada bir kare alıp kapanır; iki çalışma arasında kırmızı "çalışmıyor"
  yerine "bekliyor, N sn sonra çalışacak" görünür. Gerçekten hata verirse yine kırmızı görünür.
- Kanal düzenleme özetinde kaynak adresindeki yayın anahtarı gizlenir (••••), uzun adresler
  satır sonunda kırılır.

---

## v1.1 — 18 Kasım 2026

**Kaynak eklerken sunucu ve yayın anahtarı**
- Sihirbazda ve kanal düzenlemede "RTMP sunucusu" ya da "SRT sunucusu" seçilince, sunucu kapalıysa
  tek düğmeyle açılır ve aynı anda rastgele bir yayın anahtarı oluşturulur. Önceden yalnızca
  ayarlar sayfasına bir bağlantı vardı ve anahtar istenmiyordu.
- Sunucu açık ama anahtarsızsa ("adresi bilen herkes yayın gönderebilir") uyarı ve
  "Yayın anahtarı oluştur" düğmesi gösterilir.
- Ayarlar yeniden yüklenir; sihirbaz kaldığı yerden devam eder, adres anahtarla birlikte görünür.
  Bunu yalnızca yönetici yapabilir.
- RTMP adresinin altında OBS için ayrı "Sunucu" ve "Akış anahtarı" alanları (kopyalanabilir).

---

## v1 — 18 Kasım 2026

**Ad ve görünüm**
- Uygulamanın adı **Corvid**. Logo panelde, giriş sayfasında, tarayıcı sekmesinde ve uygulama
  simgesinde. Koyu zeminde tek renkli (beyaz), açık zeminde renkli logo; logonun arkasında zemin yok.
- Sürüm "paket N" yerine **v1** olarak gösterilir.
- Sunucuda eski varsayılan ad kayıtlıysa Corvid görünür; elle verilmiş bir ad korunur.
- datarhei'ye atıf alt bilgide ve Yardım → Hakkında'da.

**Kök adres**
- Sunucunun kök adresi yalnızca Corvid logosu ve adını gösterir: yönetim paneline bağlantı ve
  yazılım tanıtımı yok, arama motorlarına kapalı. Panel `/ui/` adresinde.

**Kurulum**
- Yeni imaj `corvid:v1`, konteyner `corvid`, klasörler `/opt/corvid/config` ve `/opt/corvid/data`.
- Yalnızca üç port yayınlanır: panel **4501**, RTMP **1935**, SRT **6000/udp**
  (HTTPS 8181 ve RTMPS 1936 kapatıldı).
- `temiz-kurulum.sh`: imajı derler (eski kurulum bu sırada yayına devam eder), ayarları ve
  istenirse kanalları taşır, kısa bir geçişle yeni konteynere geçer; açılmazsa eskisini geri açar.
  Eski kurulum ayrı bir komutla, onay alınarak silinir.
- `update.sh` sonraki güncellemeler için `corvid` konteynerini ve `/opt/corvid` klasörlerini bulur.

**Temizlik**
- Ölçüm betiği (`perf-check.sh`) ve core'daki ona ait işlemci profili tetikleyicisi kaldırıldı.
- Kaynak koddaki ve testlerdeki kuruma ait adlar, adresler ve örnekler genel örneklerle değiştirildi.
- Yama geçmişi her depo için tek bir "Corvid v1" yamasında toplandı.

---

## Temel: NVIDIA desteği (11–12 Kasım)

**Kodlama ve çözme**
- Güncel NVENC ayarları: p1–p7 hazır ayarları, tune (hq/ll/ull/lossless), CBR/VBR/CQP, multipass,
  B-frame, lookahead, uzamsal/zamansal AQ, GPU seçimi. HEVC ve AV1 NVENC eklendi.
  Eski hazır ayar adları yeni karşılıklarına kendiliğinden çevrilir.
- Kopyasız NVDEC: çözücü, CUDA filtreleri ve kodlayıcı aynı CUDA bağlamını paylaşır.
  Kareler CPU ile GPU arasında geçerken gereken dönüşümler kendiliğinden eklenir
  (NVDEC + CPU filtresi ya da NVDEC + libx264 artık çalışır).

**Kanvas ve dikey video**
- GPU'da ölçekleme ve kanvas: 9:16, 1:1, 4:5, 16:9, 720p hazır boyutları; sürükle-bırak önizleme;
  arka plan bulanık video, renk ya da yüklenen görsel. Kare piksel çıktısı, görüntü oranına
  göre doğru yerleşim.
- FFmpeg 6.1, CUDA filtreleri (`scale_cuda`, `overlay_cuda`) ile derlenir; filtreler yoksa
  imaj derlemesi hata verir. FFmpeg CUDA sürümü sürücüye göre seçilir.

**Süreç yönetimi**
- Yeniden bağlanmada üstel bekleme: 3 sn'den başlayıp en fazla 10 sn.
- GPU izleme, kodlayıcı oturumu sınırı ve birden fazla GPU arasında yük dağıtımı; meşgul bir GPU
  hiçbir başlatmayı engellemez.

**Kesintisiz yedek (failover)**
- Kaynak düşer ya da takılırsa (bağlı kalıp veri göndermezse) yayın aynı RTMP adında kesintisiz
  olarak yedek yayına, o da yoksa bekleme görseline geçer. Kaynak gerçek zamanlı akmaya
  başlayınca geri döner. YouTube gibi hedefler, önizleme, oynatıcı ve kayıt hep yayına çıkan
  akışı alır. Geçişlerin nedeni günlüğe yazılır.
- Docker imajı ve derleme önbellekleri: sonraki derlemeler yalnızca değişen kısmı derler.

---

## Paket 1–8: Kayıt, kanvas katmanları, araçlar (12–13 Kasım)

- 1080x1920 kanvasta sağ kenardaki yeşil çizgi düzeltildi.
- **Kayıt:** kanal başına kayıt, dosya adı ön eki, en fazla dosya sayısı, tek dosya seçeneği;
  oynatıcının altında başlat/durdur düğmesi ve geçen süre.
- Kaynak ve yedek adreslerinde hata uyarısı (ör. SRT `mode:publish`); yayın anahtarı ve HTTP
  güvenlik uyarısı.
- **Kanvas katmanları:** başlık yazısı, logo, ek görseller; tüm kanallarda kullanılabilen şablonlar.
- **Durum ve araçlar:** SRT bağlantı istatistikleri, yayın hedeflerinin durumu, son olaylar
  (yedek geçişleri ve nedenleri), yapılandırma yedeği, kanalı kopyalama, kanalın FFmpeg süreçleri.
- "Bağlantıyı kes" yayını tümüyle bitirir: kaynak, yedekler, önizleme, kayıt ve yayın hedefleri.
- Yedek yayın takılan bağlantıdan 10 sn'de vazgeçer, sessiz bağlantıyı 15 sn'de yeniler.
- Yayın anahtarı aracı; konteyner sunucunun saat dilimini kullanır.
- Yedek yayındayken süre, kbit/s ve FPS yayına çıkan akışı gösterir.

## Paket 9–14: Konuk anahtarları ve oynatıcı (13 Kasım)

- **Konuk anahtarları:** bir dış kaynağın belirli bir yayın adına sınırlı süre gönderebilmesi ya da
  izleyebilmesi için ayrı anahtarlar (gönderme ve izleme ayrı türler).
- Panel oynatıcısı hata sonrası akışı kendiliğinden yeniden yükler, akış gelene kadar sessizce
  dener; hata yazısı göstermez.
- Kanalın kendi yayın adına gönderme anahtarı verilemez.
- Bağlanınca önce ana yayın yayına girer; yedekler ondan sonra başlar.

## Paket 15: Yeni tasarım (13 Kasım)

- Sade gri arka plan; renk yalnızca durum için (yeşil yayında, turuncu yedek/dikkat, kırmızı
  hata/kayıt). Barlow yazı tipi, büyük harf yok, Türkçe büyük/küçük harfler doğru.
- Oynatıcının altında yayın şeridi: kaynak / yedek yayın / bekleme görseli, hangisi yayındaysa yanar.
- Klavye odağı görünür.

## Paket 16: Güvenlik (14 Kasım)

- 15 dakikada 5 yanlış parola o adresi 15 dakika kilitler.
- İstemci adresi sahte `X-Forwarded-For` başlığıyla değiştirilemez.
- Panel başka bir sitenin içinde gösterilemez; oynatıcı gömülebilir kalır.
- Yanlış yayın anahtarı denemelerinde anahtar günlüğe yazılmaz; süreç ayrıntılarında anahtarlar gizli.
- Yeni panel parolası en az 12 karakter, kolay tahmin edilen parolalar kabul edilmez.
- Panel ve core dış sunuculara bağlanmaz (sürüm denetimi kapalı).

## Paket 17: Ses ve görüntü bekçisi (16 Kasım)

- Ana ekranda ses seviyesi göstergesi (sol / sağ).
- İzleyicinin aldığı yayında uzun süre ses yoksa, görüntü kararırsa ya da donarsa uyarı (ekranda
  yazı, uyarı sesi, sekme başlığında işaret). Yalnızca uyarır, yayını değiştirmez.
- **Yayın öncesi kontrol:** kaynak, ses, yedekler, yayın hedeflerine erişim, kayıt için disk,
  sunucu saati, kodlayıcı yükü.

## Paket 18–22: Arayüzün yeniden düzenlenmesi (16 Kasım)

- Uygulamanın kendi adı ve simgesi (Sistem → Genel'den değiştirilebilir), datarhei'ye atıf,
  uygulama içi Yardım ve "Destek metni".
- Ana ekranda **Sunucu** kartı: işlemci, bellek, ağ, disk, ekran kartı (NVENC/NVDEC/VRAM, sıcaklık).
- **Durum ve araçlar** ayrı sayfa; her sürecin ayrıntı sayfasında FFmpeg komutu bölüm bölüm
  açıklamalı, günlük ve iki adımlı yeniden başlatma.
- **Yayın ekleme/düzenleme** tek sayfa; sık kullanılan hedefler önde, arama, "Komutu önizle".
- **Kanal düzenleme** bölümlere ayrıldı; kayıt için disk tahmini; komut önizleme.
- **Ayarlar** bölümlere ayrıldı; yayın anahtarları kartı; **izleme anahtarı** (internetten izlemek
  için ayrı anahtar, bu anahtarla yayın gönderilemez); ayar dosyası dışa/içe aktarma.
- Her yeniden düzenlemede eski ve yeni sayfanın birebir aynı ayarları yazdığı denetlendi.

## Paket 23–24: Performans (16–17 Kasım)

- Bekleme görseli bir kez çözülüp ölçeklenir, aynı kare tekrarlanır (büyük bir fotoğrafta işlemci
  %100'den %4'e indi).
- Görüntü ve sesi aynı adresten alan kanallar kaynağa tek bağlantı açar.
- Panel kanal süreçlerinin durumunu tek istekle okur (istek sayısı yarıdan aza indi).
- NVENC ile kodlanan görüntü NVDEC ile GPU'da çözülür; yedek yayın da.
- Sunucunun kendi RTMP/SRT sunucusuna dış adresle yazılmış kaynaklar yerel adresten okunur.

## Paket 25–27: Şifreli RTMP (rtmps) köprüsü (17 Kasım)

- rtmps:// hedeflere (YouTube, Facebook) giden yayınlar core içindeki bir köprüden gider: FFmpeg
  şifresiz olarak sunucunun içine gönderir, core büyük parçalar hâlinde şifreleyip iletir.
  Karşı sunucunun sertifikası doğrulanır; doğrulanamazsa o sunucuya bir saat doğrudan bağlanılır.
- YouTube'a resmî şifreli adı (`a.rtmps.youtube.com`, yedek `b.rtmps.youtube.com`) ile bağlanılır.
- FFmpeg büyük parçalarla gönderir; yazma çağrıları yaklaşık 30 kat azaldı.

## Paket 28–29: İşlemci verimliliği (17 Kasım)

- GPU izleme tek, sürekli açık bir `nvidia-smi` ile, yalnızca kullanılan değerlerle yapılır.
- Ayarlar yeniden yüklenince eski GPU izleyicisi ve köprü kapıları kapatılır (sızıntı düzeltildi).
- Ses/görüntü göstergesi tek iş parçacığıyla çalışır; bekleme görseli resmi GPU'ya bir kez yükler.

## Paket 30–32: Kesintisiz kaydetme ve düzenleme (17 Kasım)

- Yayın sürerken kanal kaydedilince ana süreç durdurulmaz: yeni ayarlı süreç eskisinin yanında
  başlar, bir anahtar karede ona geçilir, eskisi kapanır. Bekleme görseli görünmez.
  (Kanalın kendi SRT çıkışı açıksa eskisi gibi yeniden başlar.)
- Kaydetmede değişmeyen süreçlere dokunulmaz.
- Yayın sürerken Video ayarları açılınca kanal durdurulmaz (kamera/ses kartı gibi cihaz
  kaynakları hariç).
- Yayın anahtarı düğmesi yalnızca tıklandıktan sonra, sonuç gelene kadar kilitlenir.

## Paket 33: Hesaplar, şifreli dışa aktarma, tanılama (17 Kasım)

- **Kullanıcılar ve yetkiler:** yönetici, operatör (kanal ve yayınları yönetir, sistem ayarlarına
  giremez), izleyici (yalnızca bakar; anahtarlar ve adresler gizli). Kısıtlamaları core uygular.
  Parolalar Argon2id ile saklanır.
- **Şifreli dışa aktarma:** parola verilirse yapılandırma dosyası AES-256-GCM ile şifrelenir.
- **Tanılama paketi:** sürümler, ayarlar, süreç durumları, günlük, GPU/RTMP/SRT durumu tek dosyada;
  parolalar ve anahtarlar çıkarılmış.
- **FFmpeg dosya sınırı:** FFmpeg yalnızca veri klasörü, `/dev` ve yazı tipi dosyalarını açabilir;
  bir kanal ayarıyla yapılandırma dosyası okunamaz.
- Sunucunun kendisinden gelen isteklerde gönderilen giriş anahtarı her zaman denetlenir.

## Paket 34: Bağlantı kesme düzeltmesi (17 Kasım)

- "Bağlantıyı kes" sonrası yedek yayın ve bekleme görseli bazen yeniden başlıyordu (panelin
  yoklaması kapatmanın ortasına denk gelince). Artık önce kaynak durdurulur, kapatma bitene kadar
  yoklama yedeklere dokunmaz.
