# discourse-crimson-server-list

Discourse için forum konu ve kategori tablolarından bağımsız çalışan; yönetici
onaylı, canlı durum destekli private oyun sunucusu top listesi.

## 2.0.0 özellikleri

- Bağımsız `/servers` top listesi ve `/servers/:slug` tanıtım sayfaları
- Minecraft, FiveM, Rust, ARK, Silkroad Online, Metin2, Knight Online ve
  World of Warcraft filtreleri
- GIF/WebP dahil hareketli reklam bannerları
- Oturum açmış üyeler için sunucu başvurusu; her kayıt Discourse kullanıcı
  hesabının sahibiyle ilişkilidir
- Sunucu sahibinin kendi tanıtımını sonradan düzenlemesi
- İsteğe bağlı olarak sahip düzenlemelerini tekrar yönetici onayına gönderme
- Hesap ve sunucu başına takvim gününde bir oy
- Forum üyelerinden tekil 1–5 yıldız puanı ve metin yorumu
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
   canlı durum ve değerlendirme alanlarını otomatik oluşturur.
3. Yönetim panelinde **Eklentiler → Crimson server list** ayarlarını gözden
   geçirin.
4. `/servers` adresini açın.

Mevcut 1.x kurulumunun üzerine aynı eklenti adıyla güncellenebilir; sunucu ve oy
kayıtları korunur.

## Yetki ve veri modeli

- Sunucular: `crimson_game_servers`
- Günlük oylar: `crimson_server_votes`
- Yorum ve yıldızlar: `crimson_server_reviews`
- Başvuru, oy, yorum, elle yenileme ve sahip düzenlemesi oturum gerektirir.
- Bir kullanıcı aynı sunucuya yalnızca bir değerlendirme bırakabilir; yeniden
  gönderdiğinde mevcut değerlendirmesi güncellenir.
- Sunucu sahibi yalnızca kendi kaydını düzenleyebilir; yönetici bütün kayıtları
  yönetebilir.
- Yayınlanmamış kayıt yalnızca sahibi ve yöneticiler tarafından tanıtım
  adresinde görüntülenebilir.
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
