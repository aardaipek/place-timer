# App Store Connect metin alanları

Kopyalayıp yapıştırmak için. Karakter sınırları Apple'ın koyduğu sınırlardır.

## Name (30 karakter)

```
PlaceTimer
```

## Subtitle (30 karakter)

```
Nerede ne kadar oturuyorsun?
```

(28 karakter)

## Promotional Text (170 karakter, incelemeye girmeden değiştirilebilir)

```
Başlat/durdur yok. Bilgisayarı açtığında bulunduğun yeri Wi-Fi ağından tanır, sayacı kendi başlatır. Menü çubuğunda tek satır: neredesin ve ne kadardır oradasın.
```

(160 karakter)

## Description (4000 karakter)

```
PlaceTimer, nerede ne kadar vakit geçirdiğini kendiliğinden takip eden bir menü çubuğu uygulamasıdır.

Başlat ya da durdur düğmesi yoktur. Bilgisayarını açtığında bulunduğun yeri bağlı olduğun Wi-Fi ağından tanır, o yerdeki oturumu başlatır ve geçen süreyi menü çubuğunda gösterir. Kapağı kapattığında durur, açtığında devam eder. Aklında tutman ya da bir düğmeye basman gereken hiçbir şey yok.

NASIL ÇALIŞIR

• Yer tanıma bağlı olduğun Wi-Fi ağına dayanır. Bir yer birden çok ağ tutabilir: router'lar 2.4 ve 5 GHz bantlarını çoğu zaman ayrı adlarla yayınlar, PlaceTimer ikisini de aynı yer sayar.
• Tanımadığı bir ağa bağlandığında bir kez "Burası neresi?" diye sorar. Yakındaki mekânlardan ad önerir ya da kendin yazarsın. Bir daha sormaz.
• Aynı adlı ağlar birbirine karışmaz: kayıtlı koordinattan uzaktaki bir ağ, zincir bir mekânın başka şubesi olarak ayrıca sorulur.

İKİ SAYAÇ

Menü çubuğundaki sayaç o yerde geçirdiğin toplam süredir — duvar saati.
Panel ayrıca aktif çalışma süreni gösterir: ekran açıkken ve son girdinden bu yana belirlediğin eşikten az zaman geçmişken sayar. "Üç saattir buradayım ama iki saat çalıştım" farkını görürsün.

GÜN ŞERİDİ

Panelin altındaki ince şerit, günün ilk oturumundan şimdiye uzanır ve yerlere göre renklidir. Günün nasıl geçtiğini tek bakışta görürsün; oturumlar arası boşluklar boş kalır.

KONTROL SENDE

Otomasyon yanılırsa düzeltirsin:
• Sayacı sıfırla
• Yeri elle değiştir ya da yeni bir yer oluştur — henüz hiçbir ağa bağlanmamışken bile
• İki kaydı birleştir: aynı yerin iki ağı ya da iki adı tek yerde toplanır, geçmişteki süreler de taşınır
• Yanlış açılmış bir oturumu tek tek sil

İSTATİSTİK

Bugün, bu hafta ve bu ay için yer başına toplam süreler; her yerin yanında oranını gösteren bir çubuk. Aynı aralıktaki oturumları tek tek görebilir, yanlış olanları silebilirsin.

AYARLAR

• Menü çubuğunda saniye ve yer adı gösterimi
• Oturumu bitiren uyku eşiği — "Hemen" seçersen kapağı kapattığın an sayaç durur
• Aktif sayacı durduran hareketsizlik eşiği
• Bildirim sıklığı: kapalı, 30 dakikada bir ya da saatte bir
• Açılışta başlat

GİZLİLİK

Uygulamanın sunucusu yoktur. Hesap açman gerekmez, analitik toplanmaz, hiçbir veri satılmaz veya paylaşılmaz. Kayıtlı yerlerin ve bütün oturum geçmişin yalnızca senin Mac'inde, düz JSON dosyaları olarak durur — uygulama içinden Finder'da açıp kendi gözünle görebilirsin.

Konum izni gerekir çünkü macOS 14'ten beri bağlı Wi-Fi ağının adı yalnızca bu izinle okunabiliyor. Konumun cihazından çıkmaz.

Tek istisna: tanımadığı bir ağa bağlandığında ad önerebilmek için o anki koordinat Apple Haritalar'a gönderilir. Bu arama Apple'a gider; istemiyorsan yerin adını kendin yazman yeter.

Dilediğin an Ayarlar → Hakkında bölümünden bütün verini silebilirsin.

GEREKSİNİM

macOS 26 veya üzeri. Uygulama yalnızca menü çubuğunda yaşar, Dock'ta simgesi yoktur.
```

## Keywords (100 karakter, virgülle ayrılmış, boşluk bırakma)

```
zaman,takip,süre,menübar,wifi,çalışma,verimlilik,otomatik,sayaç,mekan,istatistik,odak
```

(87 karakter)

## Support URL

Depo sayfası ya da GitHub Pages adresi. Zorunlu.

## Privacy Policy URL

`docs/privacy-policy.md` dosyasının yayınlanmış hâli. Zorunlu.

## What's New (ilk sürümde gerekmez)

```
İlk sürüm.
```

## App Review Notes

```
PlaceTimer menü çubuğunda çalışır ve Dock simgesi yoktur (Info.plist'te LSUIElement).
Uygulamayı açtıktan sonra menü çubuğunun sağ tarafındaki sayaca tıklayarak paneli
açabilirsiniz; ayarlar penceresi paneldeki dişli düğmesindedir.

KONUM İZNİ: Uygulama açılışta konum izni ister. Bu izin, uygulamanın tek işlevi
için zorunludur: macOS 14'ten beri bağlı olunan Wi-Fi ağının adı (SSID) yalnızca
Konum Servisleri izni verilmişse okunabiliyor. İzin verilmezse menü çubuğunda
"İzin gerekli" yazar ve uygulama hiçbir yeri tanıyamaz.

Konum verisi cihazdan çıkmaz. Uygulamanın sunucusu yoktur, analitik toplamaz.
Tek ağ isteği: tanınmayan bir Wi-Fi ağına bağlanıldığında yer adı önerebilmek
için MKLocalSearch ile Apple Haritalar'a yapılan yakındaki mekân sorgusu.

TEST İÇİN: Konum iznini verdikten sonra bir Wi-Fi ağına bağlıysanız uygulama
"Burası neresi?" diye soracaktır; bir ad girdiğinizde menü çubuğundaki sayaç o
adla birlikte işlemeye başlar.
```

## App Privacy anketi

**Data Not Collected** seçilir.

Gerekçe: uygulamanın sunucusu yok, analitik yok, hesap yok; hiçbir veri
geliştiriciye ya da üçüncü taraflara ulaşmıyor. `MKLocalSearch` çağrısı bir
Apple sistem servisidir ve geliştiricinin topladığı veri değildir — yine de
inceleme notunda açıkça anılıyor.

## Category

- Primary: **Productivity**
- Secondary: **Utilities** (isteğe bağlı)

`Info.plist` içindeki `LSApplicationCategoryType` da
`public.app-category.productivity` olarak ayarlı; ikisi tutmalı.

## Age Rating

4+ — uygulamada kullanıcı içeriği, web erişimi ya da hassas materyal yok.

## Ekran görüntüleri

Zorunlu, en az 1 tane. Kabul edilen ölçüler: 1280×800, 1440×900, 2560×1600,
2880×1800.

Önerilen üç kare:

1. Menü çubuğu açık panel: yer adı, büyük sayaç, gün şeridi.
2. Ayarlar → İstatistik: yer başına çubuklar ve oturum listesi.
3. Ayarlar → Genel ya da Hakkında: gizlilik metni görünsün.
