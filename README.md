# asus-dgpu-guard

**Black screen on Linux after booting Windows? This fixes it automatically.**

On dual-boot ASUS ROG / TUF laptops, Armoury Crate on Windows can switch the NVIDIA GPU off *in firmware*. That setting stays on after you reboot into Linux, and Linux then hangs on a black screen right after the boot logo. `dgpu-guard` is a tiny boot service that notices this, turns the dGPU back on and reboots once. You get a short extra reboot instead of a black screen.

[Türkçe açıklama aşağıda](#türkçe)

---

## The problem

1. In Windows, Armoury Crate's GPU mode is **Optimized** (or **Eco**). On battery it disables the dGPU by setting the firmware flag `dgpu_disable=1`.
2. You reboot into Linux. The flag is stored in firmware, so Linux sees it too.
3. The NVIDIA card is half there. The driver logs `fallen off the bus`, GPU tools (supergfxd, cardwire, nvidia-powerd) and the login screen hang while probing it, and you get a **black screen after the boot splash**.
4. Plugging in the charger or rebooting doesn't help. The usual workaround is to boot Windows again and change the GPU mode, or to fix it by hand from a TTY.

The manual fix is known ([asus-linux FAQ](https://asus-linux.org/faq/)): write `0` to `dgpu_disable` and reboot. This project does that for you, at the right point in the boot, with loop protection.

## How it works

`dgpu-guard.service` runs early in boot, **before** the display manager and before supergfxd / cardwire / nvidia-powerd:

| Firmware state | What dgpu-guard does |
|---|---|
| dGPU enabled | Nothing. Takes a few milliseconds. |
| dGPU disabled | Writes `dgpu_disable=0`, leaves a marker in `/var/lib/dgpu-guard`, reboots once. |
| Still disabled after that reboot | Gives up and logs an error, so you never get a reboot loop. |

Why reboot instead of hot-enabling the card? The firmware decides at POST how the dGPU is powered and wired, and by the time the flag can be fixed, the driver may already have given up on the card. Hot re-enabling (write 0, PCI rescan) is known to need several tries. One reboot is slower but predictable.

It supports both places the flag can live:
- `/sys/class/firmware-attributes/asus-armoury/attributes/dgpu_disable/current_value` (newer kernels, `asus-armoury`)
- `/sys/devices/platform/asus-nb-wmi/dgpu_disable` (older kernels, `asus-nb-wmi`)

On a laptop without either one, it exits immediately and does nothing.

## Install

```bash
git clone https://github.com/metoi01/asus-dgpu-guard
cd asus-dgpu-guard
./install.sh
```

It installs to `/usr/local/bin` and `/etc/systemd/system`, so it also works on image-based systems (Bazzite, Fedora Silverblue/Kinoite, Aurora, Bluefin) without layering packages.

Remove it with `./uninstall.sh`.

## Check that it works

```bash
journalctl -b -u dgpu-guard
```

A normal boot:

```
dgpu-guard: dGPU is enabled, nothing to do
```

A real boot right after Windows had disabled the dGPU (from the author's machine):

```
04:52:00 dgpu-guard.sh[1202]: dGPU is disabled in firmware (probably Windows / Armoury Crate). Enabling it and rebooting.
04:53:33 dgpu-guard.sh[1197]: dGPU is enabled, nothing to do        <- next boot, desktop came up
```

To see earlier boots, use `journalctl -b -1 -u dgpu-guard`.

## Tests

```bash
./tests/test.sh
```

The tests run the script against a fake sysfs file, so they need no root and no ASUS hardware.

## Avoiding the problem in the first place

In Windows, open Armoury Crate → GPU Mode and choose **Standard** (MSHybrid) instead of Optimized/Eco. Then Windows never writes `dgpu_disable=1`, and dgpu-guard just stays idle as a safety net.

## Tested on

- ASUS ROG Zephyrus G16 GU605MY (Intel Core Ultra + RTX 4090 Laptop)
- Bazzite 45 (KDE Plasma 6, Wayland), kernel 7.2, NVIDIA open driver 615
- Windows 11 + Armoury Crate in Optimized mode

It should work on any ASUS laptop whose kernel exposes `dgpu_disable`. Reports from other models are welcome, open an issue.

## License

MIT

---

## Türkçe

**Windows'tan sonra Bazzite / Linux açılışta siyah ekranda mı kalıyor? Bu servis otomatik düzeltir.**

Windows'taki Armoury Crate, GPU modu **Optimized/Eco** iken pilde NVIDIA'nın elektriğini BIOS seviyesinde keser (`dgpu_disable=1`). Bu ayar Linux'a da taşınır. Kart yarım görünür, sürücü ve giriş ekranı takılır, açılış logosundan sonra **siyah ekran** kalır. Şarj takmak ya da yeniden başlatmak işe yaramaz.

`dgpu-guard` açılışın başında, giriş ekranından önce çalışır:
- dGPU açıksa hiçbir şey yapmaz.
- Kapalıysa açar ve **bir kez** yeniden başlatır. Siyah ekran yerine kısa bir ekstra yeniden başlatma görürsün.
- Yeniden başlatmaya rağmen hâlâ kapalıysa döngüye girmemek için vazgeçer ve log'a yazar.

Kurulum:

```bash
git clone https://github.com/metoi01/asus-dgpu-guard
cd asus-dgpu-guard
./install.sh
```

Log: `journalctl -b -u dgpu-guard`

Sorunu kökten önlemek için Windows'ta Armoury Crate → GPU Modu'nu **Standart** yap.
