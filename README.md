# BoxWallet

**A self-hosted, non-custodial web dashboard that acts as an automated node manager.**

BoxWallet removes the complexity of running a cryptocurrency node. It automatically downloads and installs official coin binaries, manages the daemon for you, and gives you a clean browser-based dashboard to monitor and control everything — all while keeping 100% control of your private keys.

Pre-built binaries are available for Linux (x64, ARM64), macOS (Intel, Apple Silicon), and Windows — just download and run from the [releases page](https://github.com/richardltc/boxwallet2/releases/latest).

---

## Why BoxWallet?

**One-Click Onboarding**
No manual downloads, no config file editing, no command line required. BoxWallet automatically downloads and installs the official node binaries and gets you staking in a few clicks.

**Runs Anywhere**
BoxWallet is multi-platform. Install it on a Raspberry Pi, a spare laptop you want to put to good use, or your daily Windows, Mac, or Linux machine.

**Mobile-Friendly**
Monitor your node health and staking rewards from a phone or tablet browser anywhere on your local network — no app install needed.

**Non-Custodial**
Your keys never leave your machine. BoxWallet talks directly to your local node daemon; there is no cloud, no third party, and no account required.

---

## Screenshots

Starting the Divi wallet:

<img src="docs/images/divi_start.gif" alt="Divi start">

The Divi dashboard, nearly fully synced and ready for staking:

<img src="docs/images/divi.png" alt="Divi dashboard">

The ReddCoin dashboard, displaying recent transactions:

<img src="docs/images/rdd_transactions.png" alt="ReddCoin dashboard">

---

## Getting Started

Download the latest release for your platform from the [releases page](https://github.com/richardltc/boxwallet2/releases/latest) and run it. Then open your browser at `http://localhost:4000`.

> **Running on a Raspberry Pi or separate machine?**
> See the network access note in the *Building from Source* section below.

---

<details>

<summary>Building from Source</summary>

## Building from Source

If you prefer to build from source, or if a pre-built release isn't available for your platform, follow the instructions below.

## Installing on Ubuntu 24.04

`sudo apt update && sudo apt install git inotify-tools automake autoconf libssl-dev libncurses-dev`

Now, we need to install a tool called `mise` which will handle the Erlang and Elixir install for us.

Copy and paste and run these lines one after the other, making sure you put your actual user name in the second line:

`curl https://mise.run | sh`

`echo "eval \"\$(/home/your_user_name/.local/bin/mise activate bash)\"" >> ~/.bashrc`

Now, re-start your shell and let's check we're OK so far and run `mise doctor` which should report No problems found.

`mise use erlang@26.2.5.15` — this could take some time...

`mise use elixir@1.15.8-otp-26`

Please continue to *Installing BoxWallet* below.

## Installing on Debian 13 (Trixie) and Raspberry Pi OS (64-bit only)

`sudo apt update` — update your local package database

`sudo apt install libc6:armhf libgcc-s1:armhf libstdc++6:armhf` — packages required by Divi

`sudo apt install elixir erlang-dev erlang-xmerl erlang-syntax-tools git` — packages required by BoxWallet

Please continue to *Installing BoxWallet* below.

## Installing on Windows (WSL)

Open PowerShell as an administrator and run `wsl --install`, then restart your computer when prompted. This installs the Windows Subsystem for Linux with Ubuntu.

Then follow the *Installing on Ubuntu 24.04* instructions above.

## Installing BoxWallet

Change to the directory where you'd like to install BoxWallet, then run:

```bash
git clone https://github.com/richardltc/boxwallet2.git
cd boxwallet2
mix deps.get
mix phx.server
```

Then open your browser at `http://localhost:4000`.

**Accessing from another device on your network** (e.g. a Raspberry Pi or spare machine):
Edit `config/dev.exs` and change `127, 0, 0, 1` to `0, 0, 0, 0`, then restart `mix phx.server`. You can then access the dashboard from any browser on your local network.

</details>
