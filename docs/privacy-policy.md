# PlaceTimer Gizlilik Politikası

**Son güncelleme:** 8 Eylül 2026

PlaceTimer, nerede ne kadar vakit geçirdiğinizi kendiliğinden takip eden bir
macOS menü çubuğu uygulamasıdır. Bu politika, uygulamanın hangi verilere
dokunduğunu ve bu verilerin nereye gittiğini anlatır.

Kısa cevap: **hiçbir yere gitmiyor.** Uygulamanın sunucusu yoktur.

## Toplanan veri

**Hiçbir veri toplanmıyor.** PlaceTimer'ın sunucusu yoktur; hesap açmanız
gerekmez, giriş yapmazsınız ve uygulama hiçbir analitik, çökme raporlama veya
reklam SDK'sı içermez. Geliştirici olarak sizin hakkınızda hiçbir bilgiye
erişimimiz yoktur.

## Cihazınızda saklanan veriler

Aşağıdakiler yalnızca kendi Mac'inizde, uygulamanın sandbox konteyneri içinde
düz JSON dosyaları olarak durur:

| Veri | Neden |
|---|---|
| Kayıtlı yerlerin adları | Bulunduğunuz yeri tanımak için |
| Bu yerlere bağlı Wi-Fi ağ adları (SSID) ve erişim noktası adresleri (BSSID) | Yer eşleştirmesi için |
| Yerlere ait koordinatlar | Aynı adlı ağları birbirinden ayırmak için (örneğin bir zincir kafenin iki şubesi) |
| Oturum geçmişi: başlangıç/bitiş zamanları, aktif çalışma süreleri | Süre hesapları ve istatistik için |
| Uygulama ayarlarınız | Tercihlerinizi hatırlamak için |

Konum:

```
~/Library/Containers/com.ardaipek.placetimer/Data/Library/Application Support/PlaceTimer/
```

Bu dosyaları uygulama içinden görebilirsiniz: **Ayarlar → Hakkında → Verilerin
yeri → Finder'da göster**.

## İzinler

### Konum

macOS 14'ten beri bağlı olunan Wi-Fi ağının adı yalnızca Konum Servisleri izni
verilmişse okunabiliyor. PlaceTimer'ın tüm işlevi bulunduğunuz yeri ağdan
tanımaya dayandığı için bu izin zorunludur.

Konumunuz cihazınızdan çıkmaz ve hiçbir sunucuya gönderilmez. Yalnızca yerlere
ait koordinat olarak yerel dosyaya yazılır.

### Bildirimler

Belirlediğiniz aralıkta hatırlatma göstermek için kullanılır. Bildirimler
tamamen yereldir; uzak bildirim (push) altyapısı kullanılmaz.

## Apple'a giden tek istek

Tanımadığı bir Wi-Fi ağına bağlandığınızda PlaceTimer size bir ad önerebilmek
için o anki koordinatınızı **Apple Haritalar'a** (`MKLocalSearch`) gönderir ve
yakındaki mekânların isimlerini ister.

- Bu istek **Apple'a** gider, geliştiriciye değil. Apple'ın gizlilik
  politikasına tabidir.
- Yalnızca yeni ve tanınmayan bir ağ görüldüğünde, o soru penceresi çıkarken
  yapılır. Uygulama arka planda sürekli istek atmaz.
- İstemiyorsanız: soru penceresinde önerileri kullanmayıp yerin adını kendiniz
  yazın; ya da "Şimdilik atla" deyin. Ad önerisi dışında hiçbir işlev ağ
  bağlantısı gerektirmez.

Bunun dışında uygulama internete hiç çıkmaz.

## Veri paylaşımı

Hiçbir veri üçüncü taraflarla paylaşılmaz, satılmaz veya reklam amacıyla
kullanılmaz. Paylaşılacak bir veri toplanmıyor.

## Verilerinizi silme

- **Uygulama içinden:** Ayarlar → Hakkında → **Tüm verileri sil**. Kayıtlı
  yerleriniz ve bütün oturum geçmişiniz silinir.
- **Tamamen kaldırma:** Uygulamayı çöp kutusuna atın ve
  `~/Library/Containers/com.ardaipek.placetimer` klasörünü silin.

Veriler yalnızca sizin cihazınızda olduğu için, silme işlemi geri alınamaz ve
bizde hiçbir kopyası kalmaz — çünkü hiç olmadı.

## Çocuklar

PlaceTimer çocuklara yönelik değildir ve hiç kimseden veri toplamadığı için
çocuklardan da veri toplamaz.

## Değişiklikler

Bu politika değişirse bu sayfa güncellenir ve üstteki tarih değiştirilir.

## İletişim

Sorularınız için: **[e-posta adresiniz]**
