# 🜁 My Personal Arch Linux Installer

> **Strictly Personal. Not a universal installer.
> Use at your own risk. Really.**

This repository contains the exact scripts I use to install and configure **my own** Arch Linux system.
They are not “Arch for everyone.” They are “Arch for me.”

I’m still relatively new to Arch, and I often misconfigure things simply because I’m juggling too many steps during installation.
These scripts help me avoid forgetting important configs and stop me from re-typing the same long sequences every time.

---

## ! Why This Exists (My Real, Practical Problem)

I moved away from Fedora after running into **chaotic AMD GPU driver issues**, especially with Fedora 43 — random freezes, Wayland instability, sudden graphical corruption… the whole mess.

Arch Linux turned out to be _much_ more stable for my hardware, but the installation workflow exposed a different challenge:

- I would forget kernel parameters I wanted
- I’d miss some packages
- I’d repeat the same mistakes
- Installing Arch manually takes time, and rushing leads to errors
- I use a **separate Btrfs `/home` partition**, and it must NOT be wiped

I also tried using `archinstall`, but:

> **archinstall simply doesn’t support reusing an existing Btrfs partition as `/home` without wiping it.**

If I choose Btrfs, it _forces_ formatting.
That instantly made the tool unusable for my workflow.

So yes — I wrote my own scripts.

Not because I want to reinvent the wheel,
but because the official tool literally cannot do what I need.

---

## ⚙️ What These Scripts Solve for _Me_

These scripts allow me to:

- Reinstall Arch _quickly and consistently_
- Reuse my **existing Btrfs home partition safely**
- Reapply my GPU tweaks, kernel parameters, zswap settings
- Install my standard package set without thinking
- Avoid the “oh no I forgot to…” cycle
- Rebuild my system even if I break it (which happens)

They are meant to streamline _my_ workflow — not yours.

---

## 🛠️ How I Use These Scripts

My process is simple and reproducible:

1. Boot into ArchISO
2. Clone this repo:
   ```sh
   git clone https://github.com/RakibulHasanRatul/arch-install-config.git
   cd arch-install-config
   sh ./base-installer.sh # or sh ./chroot-config.sh
   ```
3. Run `base-installer.sh` (in the live environment)
4. Chroot and run `chroot-config.sh`
5. Reboot into a system configured exactly the way I want it

This reduces installation time massively and eliminates human error.

---

## 🔓 Why This Repository Is Public

Let’s be clear:

> **This is NOT public because it's useful for others.
> It’s public so that I can clone it easily from ArchISO without messing around with SSH keys or private repo tokens.**

That’s the only reason.

If someone else finds inspiration in parts of it, that’s cool —
but this repo exists to make _my_ life easier.

---

## ⚠️ Before Anyone Else Tries Anything…

If you're here out of curiosity (which is totally fine), please understand:

> **These scripts are tightly coupled to my hardware, my partition layout, and my preferences.
> Running them on your system will almost certainly break things.**

Possible outcomes include:

- Full disk wipes
- Overwriting your bootloader
- Destroying your existing partitions
- Making your system unbootable
- Corrupting your Btrfs subvolumes
- Causing data loss or even hardware issues

I won’t sugarcoat it:

> **I take absolutely zero responsibility for any damage you cause by running these scripts.
> If you run them without understanding every line, that’s on you.**

Feel free to explore the code — just **don’t execute it blindly**.

---

## 📝 Final Note

This repository is not a distribution, not a polished tool, and not meant to “help others install Arch.”

It’s just my personal automation solution so I can rebuild my system quickly, safely, and consistently.

If you fork or adapt anything, do it at your own responsibility.
Stay smart, double-check your disks before running anything, and don’t blame me if things explode. 🙂
