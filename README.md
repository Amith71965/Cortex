# Cortex

A bookmark manager for iOS that actually organizes your links. Save URLs, and Cortex automatically tags them using on-device AI — no accounts required, no data leaving your phone.

Built with SwiftUI and SwiftData. The AI side uses a DistilBERT CoreML model with a NaturalLanguage fallback, so tagging works even without the model file.

---

## What it does

- Save bookmarks with auto-filled titles
- AI-powered tagging (on-device, fully private)
- Browse and search by tag, domain, or keyword
- Scan QR codes to add URLs instantly
- Sign in with Apple or use it as a guest
- Face ID / Touch ID lock

---

## Requirements

- Xcode 16+
- iOS 18.5+ device or simulator
- A free Apple Developer account (good enough to run on your own device)

---

## Running it locally

**1. Clone the repo**

```bash
git clone https://github.com/Amith71965/Cortex.git
cd Cortex
```

**2. Open in Xcode**

```bash
open Cortex.xcodeproj
```

**3. Set your Team**

- Select the `Cortex` project in the navigator
- Go to **Signing & Capabilities**
- Set your Apple ID as the Development Team

**4. Run**

Select your device or simulator from the toolbar and hit `Cmd + R`.

> The DistilBERT CoreML model is not included in the repo (it's 132 MB). The app falls back to Apple's NaturalLanguage framework automatically, so AI tagging still works without it.

---

## Adding the CoreML model (optional)

If you want the full DistilBERT experience, download `distilbert-base.mlpackage` from the [Releases page](https://github.com/Amith71965/Cortex/releases) and place it at:

```
Cortex/Models/distilbert-base.mlpackage
```

Then enable **Auto-organize with AI** in the app's Settings tab.

---

## Contributing

This is a personal project but contributions are welcome — especially around:

- Improving the NLP fallback tagging accuracy
- Browser extension / share sheet integration for easier saving
- iCloud sync (currently disabled; requires a paid developer account)
- UI improvements and additional themes

To contribute:

1. Fork the repo
2. Create a branch (`git checkout -b feature/your-idea`)
3. Open a pull request describing what you changed and why

---

## Author

**Amith Kumar Yadav K** — CS at Boston University
[@Amith71965](https://github.com/Amith71965) · svnitbos@bu.edu
