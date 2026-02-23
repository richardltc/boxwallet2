# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Start dev server (hot reload on port 4000)
mix phx.server

# Run all tests
mix test

# Run a single test file
mix test test/boxwallet_web/controllers/page_controller_test.exs

# Run previously failed tests
mix test --failed

# Pre-commit check: compile + clean unused deps + format + test
mix precommit

# Install dependencies and build assets
mix setup
```

## Architecture

BoxWallet is a **Phoenix 1.8 LiveView** application that acts as a GUI for managing cryptocurrency node daemons (Divi, ReddCoin). There is **no database or Ecto**. All persistence is through the coin daemon's own `.conf` files on the local filesystem.

### Module Naming — Important Inconsistency

There are **two different module name casings** in use:
- `BoxWallet.*` — context/domain modules (e.g., `BoxWallet.App`, `BoxWallet.CoinDaemon`, `BoxWallet.Coins.Auth`, `BoxWallet.Coins.ConfigManager`)
- `Boxwallet.*` — Phoenix-generated modules (e.g., `Boxwallet.Coins.Divi`, `BoxwalletWeb.*`)

Do not "fix" this — it reflects the existing split between hand-written and generated code.

### Data Flow for Each Coin

Each coin follows this pattern:

1. **Coin module** (`lib/boxwallet/coins/<coin>/<coin>.ex`) — handles all interaction with the coin daemon via JSON-RPC over HTTP. Implements the `BoxWallet.CoinDaemon` behaviour. Key functions: `files_exist/0`, `get_auth_values/0`, `download_coin/0`, `start_daemon/0`, `stop_daemon/1`, `get_info/1`, `get_blockchain_info/1`, `get_wallet_info/1`, `wallet_encrypt/2`, `wallet_unlock/2`, `wallet_unlock_fs/2`.

2. **Response structs** (`lib/boxwallet/coins/<coin>/get_*.ex`) — parse JSON-RPC responses (e.g., `GetInfo`, `GetBlockchainInfo`, `GetWalletInfo`, `GetMNSyncStatus`). Each has a `from_json/1` that returns `{:ok, struct} | {:error, reason}`.

3. **LiveView** (`lib/boxwallet_web/live/<coin>_live.ex`) — manages UI state via `Process.send_after` polling loops. On `mount/3` it checks `connected?(socket)` before starting polls. Daemon status polling uses `:check_get_info_status`, `:check_get_blockchain_info_status`, `:check_get_wallet_info_status`, `:check_get_mn_sync_status` messages.

### Auth and Config

- `BoxWallet.Coins.Auth` struct: `%{rpc_port, rpc_user, rpc_password}`
- `BoxWallet.Coins.ConfigManager` — reads/writes coin `.conf` files (key=value format)
- Coin conf files live at OS-specific paths (e.g., `~/.divi/divi.conf`, `~/.reddcoin/reddcoin.conf`)
- BoxWallet's own working directory: `~/.boxwallet` (Linux), `~/Library/Application Support/BoxWallet` (Mac), `~/AppData/Roaming/BoxWallet` (Windows)
- `BoxWallet.App` provides `home_folder/0`, `name/0`, `version/0`

### Wallet Encryption States

Wallet encryption is tracked as an atom assign in each LiveView:
- `:wes_unknown` — state not yet fetched
- `:wes_unencrypted` — wallet has no encryption (shows pulsing warning icon)
- `:wes_locked` — encrypted and locked
- `:wes_unlocked` — encrypted and fully unlocked
- `:wes_unlocked_for_staking` — encrypted, unlocked for staking only

### Shared Components

- `BoxwalletWeb.CoreWalletToolbar` — `<.hero_icons_row icons={list}>` renders exactly **6** icons; raises if not 6. Each icon map: `%{name: "hero-*", hint: string, color: "text-*", state: :enabled | :disabled | :flashing | :rotating | :pulsing}`
- `BoxwalletWeb.PromptModal` — password input modal, supports optional confirm field with server-side match validation
- `BoxwalletWeb.CoreWalletBalance` — wallet balance display component

### HTTP Client Note

The coin modules currently use `HTTPoison` for daemon RPC calls (not `Req`). For new HTTP work (downloads, external APIs), use `Req` as specified in AGENTS.md. Do not migrate existing `HTTPoison` RPC call code unless specifically asked.

## Phoenix v1.8 / LiveView Conventions

See `AGENTS.md` for detailed rules. Key points:
- Use `<Layouts.app flash={@flash}>` to wrap LiveView content
- Use `<.icon name="hero-*">` — never `Heroicons` modules
- Use `<.input field={@form[:field]}>` for form inputs
- Use `push_navigate`/`push_patch` (not deprecated `live_redirect`/`live_patch`)
- Streams for collections, never plain list assigns for potentially large data
- HEEx: `{expr}` for attribute/value interpolation, `<%= block %>` for if/for/case in tag bodies
