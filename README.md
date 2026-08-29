# discourse-crimson-server-list

Sürüm: **2.8.0**

Discourse için forum konu ve kategori tablolarından bağımsız çalışan; yönetici
onaylı, canlı durum destekli private oyun sunucusu top listesi.

## 2.8.0 scalable discovery

- `/servers` kataloğu artık ilk sınırlı bootstrap dilimini tarayıcıda filtrelemek yerine server-authoritative `/crimson-server-list/discovery.json` endpoint'ini kullanır.
- Oyun, etiket, durum, doğrulanmış sunucu, arama ve sıralama filtreleri pagination uygulanmadan önce sunucuda çalışır; sayfa boyutu varsayılan 24, hard limit 50'dir.
- Arama metni bounded tutulur, SQL wildcard karakterleri literal olarak escape edilir ve sıralama yalnız sabit whitelist üzerinden seçilir.
- Discovery sonuçları deterministik tie-break sırası kullanır; istemci sonraki sayfaları duplicate sunucu ID üretmeden ekler ve eski/stale AJAX yanıtlarının yeni filtre sonucunu ezmesini engeller.
- Public discovery serializer'ı host, bağlantı/sorgu portları ve probe/adapter diagnostic alanlarını ilan sahibi oturum açmış olsa bile katalog yanıtına eklemez.
- `/servers` ilk yüklemesi metadata-only `/crimson-server-list/bootstrap.json` endpoint'ine taşındı; game/tag sayaçları, toplu istatistikler, viewer yetkileri ve admin moderasyon kuyrukları korunurken katalog kartları bootstrap payload'ından çıkarıldı.
- Eski `/crimson-server-list.json` endpoint'i mevcut tüketiciler için geriye uyumlu bırakıldı.
- Server-side request spec'leri ile Ember Build/Plugin QUnit; filtreleme, pagination, debounce, stale-response koruması, bootstrap geriye uyumluluğu ve UI entegrasyonunu kapsar.

## 2.7.0 back-online bildirimleri

- Favoriye alınmış sunucularda `notifications_enabled` tercihi detay sayfasından ve özel Favorilerim panelinden yönetilebilir.
- Yalnız tercihi açık takipçiler, izlenen sunucu gerçek bir `back_online` geçişi yaptığında Discourse içi kalıcı bildirim alır.
- Aynı geçiş job'ı yeniden çalışırsa duplicate bildirim üretilmez; sunucu job çalışana kadar yeniden offline olmuşsa stale bildirim bastırılır.
- Büyük takipçi listeleri tek job içinde sınırsız fan-out yapmak yerine bounded batch'lerle devam ettirilir.
- Bildirim tercihi ve teslimat durumu kullanıcıya özeldir; public katalog serializer'ına takipçi bilgisi veya toplamı eklenmez.

## 2.6.0 favorites / follow backend

- Oturum açmış üyeler yayındaki sunucuları kendi özel favori listelerine kaydedebilir.
- Her kullanıcı ve sunucu çifti için yalnızca tek follow kaydı tutulur; tekrar kaydetme duplicate satır üretmez.
- Aynı ilişkideki `notifications_enabled` tercihi gelecekteki bildirim aboneliği için saklanır; bu sürüm bildirim göndermeye başlamaz.
- Kullanıcı başına en fazla 500 aktif favori tutulur ve başarılı state değişiklikleri saatte 120 işlem ile sınırlandırılır.
- Favori listesi yalnız ilgili kullanıcıya açıktır; başka kullanıcıların favori/takip bilgileri ve toplamları public serializer'a eklenmez.
- Yayından kaldırılan veya devre dışı bırakılan sunucular private favori listesinde gösterilmez; kullanıcı bu kayıtları yine unfollow ederek temizleyebilir.
- Sunucu veya kullanıcı silindiğinde foreign key `ON DELETE CASCADE` ile ilişki kaydı da temizlenir.

## 2.5.0 uptime history backend

- Başarılı ve başarısız Sidekiq probe sonuçları sunucu başına 10 dakikalık zaman bucket'larında geçmiş sağlık örneklerine dönüştürülür.
- Aynı sunucu ve aynı 10 dakikalık bucket için yalnızca tek kayıt tutulur; sık probe veya elle yenileme geçmiş tablosunu gereksiz büyütmez.
- Varsayılan retention 30 gündür ve yönetici tarafından 7–90 gün arasında ayarlanabilir. Günlük cleanup eski kayıtları 5.000 satırlık batch'lerle siler.
- Uptime yüzdesi yalnızca `online` ve `offline` örneklerinden hesaplanır; `unknown` ve `maintenance` yüzdesi yapay biçimde düşürmez/yükseltmez.
- Oyuncu sayısı desteği olmayan adaptörlerde geçmiş `players_online` / `players_max` değerleri `null` tutulur; sayı uydurulmaz.
- Public `/crimson-server-list/servers/:id/uptime.json` endpoint'i yalnız yayındaki sunuculara 24 saat, 7 gün veya 30 günlük geçmiş verir ve grafik serisini en fazla 240 noktaya sıkıştırır.
- History yazımı secondary telemetry'dir; geçmiş kaydı yazılamazsa canlı probe sonucu bozulmaz. Sunucu silinirse DB foreign key `ON DELETE CASCADE` ile geçmiş örnekleri de temizlenir.

## 2.4.1 anti-abuse iyileştirmeleri

- Sunucu sahibi kendi ilanına oy veremez ve kendi ilanını yıldız/yorum ile değerlendiremez; kontrol backend seviyesinde uygulanır.
- İlan sahibi detay JSON'unda oy ve değerlendirme aksiyonları kapalı döner; istemci yalnız bu server-authoritative durumu gösterir.
- Normal üyeler için Discourse `RateLimiter` tabanlı korumalar eklendi: günde 5 yeni sunucu başvurusu, günde 100 sunucu oyu, saatte 30 değerlendirme yazımı/güncellemesi ve günde 10 sahiplik talebi.
- Staff hesapları Discourse'un varsayılan rate-limit muafiyetini korur.
- Validation, duplicate oy veya mevcut pending claim nedeniyle reddedilen istekler limiter kotasını tüketmez.
- Anti-abuse hata yanıtları İngilizce ve Türkçe yerelleştirildi.

## 2.4.0 güven ve moderasyon

- Sunucu sahibi DNS TXT challenge ile alan adı kontrolünü kanıtlayabilir; plaintext challenge veritabanında saklanmaz, yalnız SHA-256 digest tutulur.
- Doğrulanmış sunucular liste ve detay sayfasında native Discourse uyumlu bir rozetle gösterilir.
- Host veya sahip değiştiğinde doğrulama otomatik olarak iptal edilir.
- Üyeler yayındaki sunucu ilanlarını sınırlı nedenlerle yönetici incelemesine raporlayabilir.
- Aynı kullanıcı ve sunucu için ikinci pending rapor DB seviyesinde engellenir; rapor oluşturma işlemleri kullanıcı ve sunucu bazında rate-limit edilir.
- Reporter kimliği ve rapor metni normal public server serializer'ına eklenmez.
- Yalnız admin pending rapor kuyruğunu görebilir ve raporu `resolved` veya `dismissed` olarak sonuçlandırabilir; rapor sayısı sunucuyu otomatik olarak kapatmaz veya silmez.
- Reporting UI ve Verified Server UI gerçek Discourse Ember Build + Plugin QUnit kapısından geçecek frontend testleriyle kapsanır.

## 2.2.2 iyileştirmeleri

- `/servers` ve sunucu detay sayfaları Discourse uygulama kabuğu, tema değişkenleri ve native yoğunlukla uyumlu hale getirildi.
- Resmî `Discourse Plugin` GitHub Actions iş akışı eklendi.
- Minimum Token Context v3 çalışma kuralları projeye dahil edildi; AI reviewer onayları varsayılan merge gate olmaktan çıkarıldı.
- Ruby lint ve schema annotation uyumluluğu resmî Discourse CI gereksinimlerine göre güncellendi.

## 2.2.1 düzeltmesi

- Sayfa yenilendiğinde sayaçlarda kalan fakat kart listesinden kaybolan sunucular düzeltildi.
- Katalog yanıtı URL'de kalmış eski filtrelerden ayrıldı ve dinamik JSON önbelleğe kapatıldı.

## 2.2.0 özellikleri

- Bağımsız `/servers` top listesi ve `/servers/:slug` tanıtım sayfaları
- Minecraft, FiveM, Rust, ARK, Silkroad Online, Metin2, Knight Online ve
  World of Warcraft için kategori gibi çalışan paylaşılabilir filtre adresleri
- İlan başına en fazla 8 etiket; etikete tıklayarak oyunlar arası veya seçili
  oyun içinde filtreleme
- Liste ve tanıtım sayfasında oranı bozulmadan gösterilen standart 468×60
  GIF/WebP reklam bannerları
- Banner tıklamasının sunucu web sitesini yeni sekmede `nofollow`, `ugc`,
  `sponsored`, `noopener` ve `noreferrer` nitelikleriyle açması
- Oturum açmış üyeler için sunucu başvurusu; her kayıt Discourse kullanıcı
  hesabının sahibiyle ilişkilidir
- Sunucu sahibinin kendi tanıtımını sonradan düzenlemesi
- İsteğe bağlı olarak sahip düzenlemelerini tekrar yönetici onayına gönderme
- Hesap ve sunucu başına takvim gününde bir oy
- Forum üyelerinden tekil 1–5 yıldız puanı ve metin yorumu
- Oyun türüne göre değişen ilan alanları: CAP/seviye, EXP/SP/drop/yang/NP
  oranları, wipe takvimi, framework, harita ve realm bilgileri
- Her ilan için günlük tekil ziyaretçi temelli görüntülenme sayacı
- Forum üyelerinin yayınlanmış bir ilan için sahiplik talebi göndermesi;
  yönetici onayında sahipliğin talep eden hesaba atomik aktarılması
- Yönetici ve moderatörlerin ilanı ayrıntı sayfasından kalıcı olarak silmesi
- Host, bağlantı/sorgu portu, sorgu adaptörü, yanıt süresi ve sorgu hata
  ayrıntılarının yalnızca ilan sahibi ile yöneticilere gönderilmesi; son kontrol
  zamanının ziyaretçilere güven göstergesi olarak açık kalması
- Oturum açmamış ziyaretçiye de görünen, giriş sonrası aynı ilana döndüren
  sahiplenme çağrısı
- Cosmetic eklentisiyle uyumlu, avatar ve kullanıcı metnini ayrı hedefleyen
  kullanıcı kartı sarmalayıcıları
- Eski bir sorgu portu artık izin listesinde olmasa bile adres alanları
  değiştirilmeden banner/açıklama gibi güvenli ilan bilgilerinin güncellenmesi
- Yönetici onay/red kuyruğu
- Sidekiq üzerinden periyodik canlı durum yenileme ve kısa süreli önbellek
- Masaüstü, tablet ve telefon için duyarlı arayüz
- Doğrudan ziyaret ve yenileme için Rails uygulama kabuğu fallback rotaları

## Canlı sorgu adaptörleri

| Oyun | Adaptör | Sonuç |
|---|---|---|
| Minecraft Java | Server List Ping | Canlı oyuncu / kapasite |
| FiveM | `dynamic.json`, gerekirse `players.json` | Canlı oyuncu / kapasite |
| Rust | Steam A2S_INFO | Canlı oyuncu / kapasite |
| ARK | Steam A2S_INFO | Canlı oyuncu / kapasite |
| Silkroad Online | Kısa TCP erişim kontrolü | Çevrimiçi / çevrimdışı |
| Metin2 | Kısa TCP erişim kontrolü | Çevrimiçi / çevrimdışı |
| Knight Online | Kısa TCP erişim kontrolü | Çevrimiçi / çevrimdışı |
| World of Warcraft | Kısa realm TCP erişim kontrolü | Çevrimiçi / çevrimdışı |

Son dört oyun için tüm private server yazılımlarında ortak, kimlik doğrulamasız
ve evrensel bir oyuncu sayısı protokolü bulunmadığından sayı uydurulmaz; yalnızca
port erişimi gösterilir. Belirli bir emülatöre ait doğrulanmış API daha sonra ayrı
bir adaptör olarak eklenebilir.

## Ağ güvenliği

Kullanıcının girdiği hedefe web isteğinin veya sayfa render'ının içinde bağlantı
kurulmaz. Oluşturma, düzenleme, zamanlanmış yenileme ve elle yenileme yalnızca
Sidekiq işi kuyruğa alır.

Her sorgudan önce şu kontroller zorunludur:

1. Host biçimi ve isteğe bağlı alan adı soneki izin listesi doğrulanır.
2. DNS kısa zaman aşımıyla çözülür.
3. Dönen **bütün** IPv4/IPv6 adresleri incelenir; loopback, private, link-local,
   CGNAT, dokümantasyon, multicast ve ayrılmış ağlardan biri varsa hedef bütünüyle
   reddedilir.
4. Bağlantı DNS adını tekrar çözmek yerine doğrulanmış IP adresine kurulur; HTTP
   `Host` başlığı yalnızca sanal host seçimi için korunur.
5. Oyun başına port izin listesi uygulanır. Yönetici yalnızca gerekli ek portları
   ayardan açabilir.
6. Bağlantı ve okuma zaman aşımı 500–5000 ms aralığına sıkıştırılır.
7. Yanıt en fazla 64 KiB okunur; HTTP yönlendirmeleri takip edilmez.
8. Sonuç veritabanına ve süreli Discourse önbelleğine yazılır. Aynı kayıt için
   Redis kilidi eşzamanlı sorgu fırtınasını engeller.

### Varsayılan port aralıkları

- Minecraft: `20000-30000`
- FiveM: `30000-30250`
- Rust: `27000-29000`
- ARK: `7000-8100`, `27000-29000`
- Silkroad Online: `15000-16500`
- Metin2: `10000-14500`
- Knight Online: `15000-16500`
- World of Warcraft: `3000-9000`

Farklı portlar yalnızca `crimson_server_list_extra_allowed_ports` ayarında
bilinçli biçimde eklenmelidir.

## Kurulum ve güncelleme

1. Bu dizini mevcut eklenti Git deposunun köküne yükleyin.
2. `/var/discourse` altında `./launcher rebuild app` çalıştırın. Yeni migration,
   etiket, canlı durum, değerlendirme, bounded uptime history ve favori/takip tablosunu otomatik oluşturur.
3. Yönetim panelinde **Eklentiler → Crimson server list** ayarlarını gözden
   geçirin.
4. `/servers` adresini açın.

Mevcut 1.x kurulumunun üzerine aynı eklenti adıyla güncellenebilir; sunucu ve oy
kayıtları korunur.

## Yetki ve veri modeli

- Sunucular: `crimson_game_servers`
- Günlük oylar: `crimson_server_votes`
- Yorum ve yıldızlar: `crimson_server_reviews`
- Sahiplik talepleri: `crimson_server_claim_requests`
- Sunucu raporları: `crimson_server_reports`
- Uptime history: `crimson_server_uptime_samples`
- Favoriler / takip tercihleri: `crimson_server_follows`
- Sunucu etiketleri: `crimson_game_servers.tags` JSONB alanı ve GIN indeksi
- Başvuru, oy, yorum, elle yenileme, sahip düzenlemesi ve favori/takip işlemleri oturum gerektirir.
- Bir kullanıcı aynı sunucuya yalnızca bir değerlendirme bırakabilir; yeniden
  gönderdiğinde mevcut değerlendirmesi güncellenir.
- Bir kullanıcı ve sunucu çifti için yalnız tek favori/takip ilişkisi bulunur; notification tercihi aynı satırda tutulur.
- Sunucu sahibi yalnızca kendi kaydını düzenleyebilir; kendi ilanına oy veremez
  veya değerlendirme bırakamaz; yönetici bütün kayıtları yönetebilir.
- Yönetici ve moderatörler ilan silebilir; sahiplik aktarımını yalnızca yönetici
  onaylayabilir.
- Görüntülenme sayacı, oturum açmış hesap veya anonim tarayıcı parmak izi için
  ilan başına günde en fazla bir artar. Ham IP adresi veritabanına yazılmaz.
- Yayınlanmamış kayıt yalnızca sahibi ve yöneticiler tarafından tanıtım
  adresinde görüntülenebilir.
- Yayındaki kayıtlarda ağ uç noktası ve sorgu ayrıntıları API seviyesinde ilan
  sahibi/yönetici dışındaki kullanıcılardan gizlenir; CSS ile saklama yapılmaz.
- Web, Discord ve banner alanlarında yalnızca `http`/`https` URL'leri kabul
  edilir. Banner istemci tarayıcısında gösterilir; canlı oyun sorgusu sunucuda
  yalnızca yukarıdaki ağ politikası içinden yapılır.

## Ayarlar

- `crimson_server_list_enabled`
- `crimson_server_list_submission_enabled`
- `crimson_server_list_require_approval`
- `crimson_server_list_votes_enabled`
- `crimson_server_list_results_limit`
- `crimson_server_list_live_query_enabled`
- `crimson_server_list_query_interval_minutes`
- `crimson_server_list_connect_timeout_ms`
- `crimson_server_list_read_timeout_ms`
- `crimson_server_list_extra_allowed_ports`
- `crimson_server_list_allowed_host_suffixes`
- `crimson_server_list_reviews_enabled`
- `crimson_server_list_owner_edits_require_approval`
- `crimson_server_list_reviews_limit`
- `crimson_server_list_verification_enabled`
- `crimson_server_list_verification_challenge_hours`
- `crimson_server_list_reports_enabled`
- `crimson_server_list_uptime_history_enabled`
- `crimson_server_list_uptime_history_retention_days`
- `crimson_server_list_follows_enabled`
