# Split Reflex — Production Release Artifacts

This folder contains the signed, production-ready **Android App Bundle (.aab)** built for the **Google Play Store**.

---

## 📦 Production Artifacts

| File | Description | Size |
|---|---|---|
| `SplitReflex-v1.0.0+1-release.aab` | Versioned release bundle ready for Google Play Console | ~23.8 MB |
| `app-release.aab` | Canonical release bundle ready for Google Play Console | ~23.8 MB |

---

## 🔑 Signing & Key Information

- **Keystore Location**: `android/upload-keystore.jks`
- **Key Alias**: `upload`
- **Key Password / Store Password**: `SplitReflex2026PlayStore!`
- **Configuration**: `android/key.properties`

### Certificate Fingerprints (for Play App Signing & API verification):
- **SHA-1**: `79:24:F0:6F:F6:69:E9:45:BA:2C:13:C6:E1:B4:5A:6E:27:7D:9D:5F`
- **SHA-256**: `2D:BF:D2:C7:D4:D3:E6:3E:1A:47:96:EA:BE:B7:28:20:9D:34:38:95:EF:6D:19:F2:C5:CF:4B:7E:7C:ED:EC:64`
- **Validity**: Until `March 20, 2054` (10,000 days)

---

## 🌐 Official URLs & Legal Links

These URLs are integrated directly into the in-app menu and must be entered in the Google Play Console:
- **Official Website**: `https://splitreflex.vercel.app/`
- **Terms & Conditions**: `https://splitreflex.vercel.app/terms`
- **Privacy Policy**: `https://splitreflex.vercel.app/privacy`

---

## 📋 App Specifications

- **Package / Application ID**: `com.splitreflex.game`
- **Version Name**: `1.0.0`
- **Version Code**: `1`
- **Target SDK**: `35` (Android 15 — exceeds minimum Google Play target requirements)
- **Min SDK**: `21` (Android 5.0 Lollipop — supports 99%+ of Android devices)
- **Permissions**: `android.permission.VIBRATE` only (zero sensitive permissions)
- **R8 / Minification**: Enabled (`minifyEnabled true`, `shrinkResources true`)
- **Native Debug Symbols**: `debugSymbolLevel 'FULL'`
