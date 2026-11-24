# MovieShelf – iPhone için film/dizi oynatıcı

SwiftUI ile yazılmış, iOS 17+ (iPhone 17 Pro Max dahil) uygulaması.

**Özellikler:** film/dizi kitaplığı, dosya adından otomatik dizi/sezon/bölüm tanıma (`Dizi.S01E02.mp4`),
kaldığın yerden devam, "Devam Et" ve "Favoriler" satırları, otomatik küçük resim, arama,
Picture-in-Picture, arka planda ses, URL (mp4/m3u8) ekleme, USB ile dosya aktarma.

> **Format notu:** Yerleşik iOS oynatıcısı MP4/M4V/MOV (H.264/HEVC) ve HLS (m3u8) oynatır.
> **MKV/AVI açılmaz** – önce MP4'e dönüştür (HandBrake) ya da istersen VLCKit ile MKV desteği ekleriz.

## Kurulum (Windows + USB-C)

Windows'ta Xcode çalışmadığı için derlemeyi GitHub'ın ücretsiz Mac makinesi yapıyor.

### 1) IPA'yı derle
1. github.com'da **özel (private)** yeni bir repo aç.
2. Bu klasörü o repoya yükle (`main` dalına):
   ```powershell
   git init -b main
   git add .
   git commit -m "MovieShelf"
   git remote add origin https://github.com/KULLANICI/REPO.git
   git push -u origin main
   ```
3. Repo → **Actions** → "Build IPA" çalışır (ya da *Run workflow*). ~5 dk sürer.
4. Bitince **Artifacts → MovieShelf-ipa** indir, zipten `MovieShelf.ipa` çıkar.

### 2) iPhone'da Geliştirici Modu
**Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu → Aç** → telefon yeniden başlar → açılışta onayla.
(Bu seçenek, telefonu bir kez bilgisayara bağlayıp Sideloadly ile uygulama yükleyince görünür hale gelir.)

### 3) Telefona yükle
1. PC'ye **iTunes** (Microsoft Store değil, apple.com sürümü) ve **Sideloadly** (sideloadly.io) kur.
2. iPhone'u USB-C ile bağla, "Bu bilgisayara güven" de.
3. Sideloadly'de `MovieShelf.ipa`'yı sürükle, Apple ID'ni yaz, **Start**.
4. iPhone: **Ayarlar → Genel → VPN ve Aygıt Yönetimi →** Apple ID'ne dokun → **Güven**.

> Ücretsiz Apple ID ile uygulama **7 gün** sonra süresi dolar; Sideloadly ile aynı şekilde tekrar yükle
> (veriler/dosyalar kalır). Ücretli Apple Developer hesabı ($99/yıl) ile 1 yıl olur.

### 4) Film aktarma
- Uygulamada **+ → Dosya içe aktar** (Dosyalar uygulamasından), **veya**
- PC'de **Apple Devices** uygulaması → iPhone → *Dosyalar* → MovieShelf → dosyaları sürükle. Uygulama açılınca otomatik görünür.
- Dizi isimlendirme: `Breaking Bad S01E01.mp4` → "Breaking Bad" altında Sezon 1 / Bölüm 1.
