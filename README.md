# discourse-crimson-server-list

Discourse için forum konu ve kategori tablolarından bağımsız çalışan, yönetici
onaylı private oyun sunucusu top listesi.

## İlk sürümdeki oyunlar

- Minecraft
- FiveM
- Rust
- ARK
- Silkroad Online
- Metin2
- Knight Online
- World of Warcraft

## Özellikler

- Bağımsız `/servers` Ember rotası
- Oyuna göre filtreleme, metin araması ve farklı sıralama seçenekleri
- Banner, bağlantı adresi, sürüm, mod, dil, web ve Discord alanları
- Oturum açmış üyeler için sunucu başvurusu
- Varsayılan olarak yönetici onayı
- Hesap ve sunucu başına takvim gününde bir oy
- Yöneticiye özel onay/red kuyruğu
- Masaüstü, tablet ve telefon için duyarlı Crimson arayüzü
- Sunucu tarafında harici oyun sunucularına otomatik ağ isteği gönderilmez
- `/servers` adresine doğrudan giriş ve sayfa yenileme için Rails uygulama
  kabuğu fallback'i

## Kurulum

1. Bu dizini bir Git deposuna yükleyin veya ZIP'i Discourse sunucusunda
   `/var/discourse/containers/app.yml` içindeki `hooks` bölümünde eklenti olarak
   klonlayın.
2. Standart Discourse eklenti kurulumu sonrasında `./launcher rebuild app`
   çalıştırın.
3. Yönetim panelindeki **Eklentiler** ayarlarından `crimson server list`
   ayarlarını gözden geçirin.
4. `/servers` adresini açın.
5. `senin.me Crimson Channels` temasının 0.1.12 veya daha yeni sürümü
   kuruluysa masaüstü ve mobil menü bağlantıları otomatik görünür.

## Veri ve yetki modeli

- Sunucular `crimson_game_servers` tablosunda tutulur.
- Oylar `crimson_server_votes` tablosunda tutulur ve veritabanı benzersiz
  indeksi aynı kullanıcının aynı sunucuya aynı gün ikinci kez oy vermesini
  engeller.
- Başvuru oluşturmak ve oy vermek oturum gerektirir.
- Onay ve red işlemleri yalnızca yöneticilere açıktır.
- Web, Discord ve banner alanlarında yalnızca `http`/`https` adresleri kabul
  edilir. İlk sürüm SSRF riskini önlemek için oyun sunucularını sorgulamaz.

## Ayarlar

- `crimson_server_list_enabled`
- `crimson_server_list_submission_enabled`
- `crimson_server_list_require_approval`
- `crimson_server_list_votes_enabled`
- `crimson_server_list_results_limit`

## Sonraki aşama

Canlı oyuncu sayısı için her oyuna özel sorgu adaptörü, izin verilen port ve
host politikası, kısa zaman aşımı, DNS/IP güvenlik kontrolü ve Sidekiq önbelleği
eklenmelidir. Bu güvenlik katmanı olmadan kullanıcı tarafından girilen bir
adrese sunucudan istek gönderilmemelidir.
