# JetWIFI

A premium dark-mode iOS app for discovering and managing the devices on **your own**
home Wi-Fi network. It scans the local network, builds rich device profiles, and
manages per-device internet access through **your router's own admin controls** —
not by spoofing or intercepting anyone's traffic.

> **Scope.** JetWIFI only acts on a network you own/administer, and only through the
> router credentials you supply. There is no ARP spoofing, no packet interception,
> and no attempt to affect devices on networks you don't control. Those techniques
> also can't run in a sandboxed (non-jailbroken) sideloaded app anyway — this app
> is built to work *within* those limits, honestly.

---

## What works, and where

| Capability | Status |
|---|---|
| Device discovery (IP, MAC, hostname, vendor, Bonjour services) | ✅ Works in a standard sandboxed app |
| Online/offline tracking, first/last seen, history log | ✅ Works |
| Rename devices, search/filter, persistent storage | ✅ Works |
| Block / restore a device — **NETGEAR** (local SOAP, port 5000) | ✅ Implemented (needs a model exposing `SetBlockDeviceByMAC`) |
| Block / restore a device — **ASUS** (AsusWRT Parental Controls) | ✅ Implemented (nvram vars vary by firmware) |
| Block / restore — **TP-Link** | ⚠️ Honest limitation: encrypted/cloud login; use Tether app |
| Block / restore — **Eero** | ⚠️ Cloud account + verification code required; use eero app |
| Block / restore — **Xfinity** | ⚠️ No local API; use Xfinity app |

When an operation isn't supported on your hardware, JetWIFI **says so clearly**
instead of pretending it worked. That's by design.

### Why the iOS sandbox matters
A sideloaded (non-jailbroken) app can:
- read its own IP/subnet, sweep the subnet, read the ARP cache, browse Bonjour, do reverse DNS — **all of discovery works**;
- make normal HTTP(S)/SOAP calls to your router to drive its admin features — **this is how blocking works**.

It **cannot** send raw/ARP packets or capture other devices' traffic. JetWIFI never tries to.

---

## Build the IPA (no Mac needed on your side)

Apple's toolchain only runs on macOS, so the actual compile happens on GitHub's
free Mac runners. You drive it from your PC.

1. **Create a GitHub repo** and push this folder:
   ```bash
   cd JetWIFI
   git init
   git add .
   git commit -m "JetWIFI initial"
   git branch -M main
   git remote add origin https://github.com/<you>/JetWIFI.git
   git push -u origin main
   ```
2. The **Build JetWIFI IPA** workflow runs automatically (or trigger it from the
   repo's **Actions** tab → *Run workflow*).
3. When it finishes, open the run and download the **`JetWIFI-unsigned-ipa`**
   artifact. Inside is `JetWIFI.ipa` (unsigned — that's expected).

### Build locally instead (if you have a Mac)
```bash
brew install xcodegen
xcodegen generate
open JetWIFI.xcodeproj   # then Run on a device, or Product ▸ Archive
```

---

## Install with SideStore

1. Make sure **SideStore** is set up and working on your iPhone.
2. Get `JetWIFI.ipa` onto the phone (AirDrop, Files, or download it from the
   GitHub artifact directly on the device).
3. Open **SideStore → My Apps → `+` → select `JetWIFI.ipa`.**
4. SideStore signs it with your free Apple ID and installs it.
5. Free Apple IDs expire sideloaded apps after **7 days** — let SideStore refresh
   it over Wi-Fi, and keep your refresh/anisette setup active.

> Free-Apple-ID limits: up to 3 sideloaded apps at once (SideStore counts as one).
> JetWIFI uses no entitlements that require a paid account.

---

## First run

1. Open JetWIFI → **Dashboard → Scan network.** iOS will ask for **Local Network**
   permission the first time — allow it, or discovery returns nothing.
2. Browse discovered devices under **Devices**; tap one for its full profile.
3. To manage access: **Settings → Add your router**, pick your brand, enter the
   admin address + login (stored in the iOS Keychain). JetWIFI tests the
   connection before saving.
4. On a supported router, open a device and tap **Block internet access**. The
   status only flips to *Blocked* after the router confirms the change. Undo it
   from the device page or the **Restricted** tab.

---

## Project layout
```
project.yml                 XcodeGen project definition (edit this, not the .xcodeproj)
.github/workflows/          CI that builds the unsigned IPA
Sources/
  App/                      App entry, root tab bar, generated Info.plist
  Models/                   Device, HistoryEvent, Router models
  Discovery/                NetworkInterface, HostToucher, ARPTable, Bonjour, OUI, DNS
  Routers/                  RouterAdapter protocol, RouterManager, per-brand Adapters/
  Persistence/              JSON Store + Keychain
  State/                    AppState (ObservableObject, the single source of truth)
  Views/                    Dashboard, Devices, Restricted, History, Settings + components
Resources/                  Optional oui.csv for full vendor coverage
```

See [`TESTING.md`](TESTING.md) for the full test checklist.

## Optional: full vendor database
Drop the official IEEE OUI list as `Resources/oui.csv` (lines of `AABBCC,Vendor`)
and `OUILookup` loads it automatically, extending the built-in common-vendor table.
