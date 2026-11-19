# JetWIFI — Testing Documentation

JetWIFI depends on real LAN hardware, so meaningful testing happens on a device
attached to a home network. This is the checklist I'd run.

## 0. Build sanity
- [ ] `xcodegen generate` succeeds with no schema errors.
- [ ] `xcodebuild ... archive` completes; `JetWIFI.app` appears in the archive.
- [ ] CI uploads `JetWIFI.ipa` artifact.
- [ ] SideStore installs the IPA; app icon launches to the dark Dashboard.

> First build caveat: this code was written on Windows and has **not** been through
> a Swift compiler. Expect a small round of compile fixes on the first CI run
> (most likely in the low-level C-interop files, `ARPTable.swift` and
> `NetworkInterface.swift`). The CI log will point to the exact line.

## 1. Permissions
- [ ] On first scan, iOS prompts for **Local Network** access.
- [ ] Denying it → discovery returns nothing (expected). Re-enable in
      iOS Settings → JetWIFI → Local Network.

## 2. Discovery
- [ ] Scan on a known network; device count roughly matches reality.
- [ ] Your iPhone appears as **This iPhone**; the gateway shows a **Router** badge.
- [ ] Devices show IP, and most show a MAC + vendor.
- [ ] Known devices (phones, TVs, printers, speakers) get sensible names/icons via
      Bonjour or reverse DNS.
- [ ] Turn a device off → next scan marks it **Offline** (a `deviceLeft` history entry).
- [ ] Turn it back on → it returns as **Online** (`deviceJoined` entry).
- [ ] Rename a device → name persists across app relaunch.

## 3. Router setup
- [ ] Settings → Add router. Each brand shows an honest support summary.
- [ ] Supported brand (ASUS/NETGEAR): wrong password → clear "credentials rejected";
      unreachable host → clear "could not reach the router".
- [ ] Correct credentials → "Router saved"; password is stored in Keychain
      (not in `router.json`).
- [ ] Unsupported brand (Xfinity/Other): saving works, but the UI states blocking
      isn't available.

## 4. Access management (supported routers)
- [ ] Block a **spare/test** device. Confirm its internet actually drops.
- [ ] Device status flips to **Blocked** only *after* the router confirmed —
      not optimistically.
- [ ] Device appears under **Restricted**; a `restrictApplied` entry is logged.
- [ ] Restore access → device regains internet; status returns to normal.
- [ ] Unsupported firmware (no `SetBlockDeviceByMAC` / different nvram) → honest
      `.unsupported` message, **not** a fake success.

## 5. Edge cases
- [ ] No Wi-Fi (cellular only) → scan reports "No Wi-Fi connection".
- [ ] Very large subnet (/16 etc.) → scan is capped and doesn't hang (see
      `NetworkInterface.hostAddresses`, 1024-host cap).
- [ ] Device with no detected MAC → access controls are disabled with an explanation.
- [ ] History cap holds at 500 entries; **Clear** empties it.

## 6. Persistence
- [ ] Force-quit and relaunch → devices, history, and router config reload.
- [ ] Reinstall → Keychain password may survive (device-scoped); JSON resets.

## Known limitations (by design, not bugs)
- No raw-packet features (sandbox); discovery leans on ARP cache + Bonjour, so a
  silent device that never responds to the probe sweep may be missed until it talks.
- Router adapters target documented/common firmware; exotic firmware may need
  per-model tweaks in `Sources/Routers/Adapters/`.
- TP-Link/Eero/Xfinity blocking is intentionally not implemented end-to-end; the
  app explains why and points to the vendor app.
