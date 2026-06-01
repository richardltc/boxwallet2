defmodule Boxwallet.Coins.Ergo do
  @moduledoc """
  Interaction with the Ergo (ERG) node daemon.

  Unlike the Bitcoin-Core forks in BoxWallet, Ergo is a JVM application. We
  download the official per-platform "ergo-node" bundle, which ships the node
  jar (`ergo-<version>.jar`) alongside a bundled OpenJDK JRE, so no system Java
  is required. The node is launched in the foreground via an Erlang `Port`
  (it does not fork like `*coind`), exposes a REST API (not JSON-RPC), and
  authenticates protected endpoints with an `api_key` HTTP header.

  Key differences handled here:

    * Distribution: download the platform bundle (node jar + JRE) and extract it.
    * Auth: fixed `api_key` shipped in source; the node config stores only the
      Blake2b256 hash of the key. The node binds to 127.0.0.1 only.
    * Config: HOCON `ergo.conf` written from a template (the key=value
      `ConfigManager` does not apply).
    * Consensus: PoW (Autolykos2) — no staking.
    * Units: balances are in nanoERG (1 ERG = 1e9 nanoERG).

  HTTP uses `Req` (per AGENTS.md), not HTTPoison.
  """
  require Logger

  alias BoxWallet.Coins.Auth
  alias BoxWallet.Coins.Ergo.{GetInfo, WalletStatus, WalletBalances, ListTransactions}

  @coin_name_abbrev "ERG"
  def coin_name_abbrev, do: @coin_name_abbrev

  # Ergo node data directory + config live here (OS-specific).
  @home_dir_lin ".ergo"
  @home_dir_mac "Ergo"
  @home_dir_win "Ergo"

  @core_version "6.0.2"
  def core_version, do: @core_version

  # The node ships as `ergo-<version>.jar` inside each platform's bundle.
  @jar_file "ergo-#{@core_version}.jar"
  def jar_file, do: @jar_file

  # GitHub release that carries the per-platform "ergo-node" bundles (each is
  # the node jar plus a bundled OpenJDK 21 JRE, so no system Java is required).
  @release_base "https://github.com/ergoplatform/ergo/releases/download/v#{@core_version}"

  @conf_file "ergo.conf"

  # REST API + auth. Ergo binds the API to 127.0.0.1 only, so a fixed api_key
  # shipped in source is acceptable; `@api_key_hash` is the Blake2b256 hash of
  # `@api_key` (Erlang :crypto can't compute blake2b-256, hence the constant).
  @rpc_port "9053"
  @api_key "BoxWalletErgoLocalApiKey"
  @api_key_hash "9ecf0728f49d816f6ffdd168369412edc2713b74b083b2f65b1422c63dda0c95"
  @base_url "http://127.0.0.1:#{@rpc_port}"

  # JVM max heap for the node process.
  @xmx "4G"

  @nano_per_erg 1_000_000_000

  @daemon_rpc_attempts 25

  # --- Bundle (node jar + JRE) location and download selection ---

  # BoxWallet downloads the official per-platform "ergo-node" bundle, which
  # carries `ergo-<version>.jar` alongside a known-good OpenJDK JRE. Running the
  # node therefore needs no system Java. Everything is extracted under this dir.
  defp bundle_dir, do: Path.join(BoxWallet.App.home_folder(), "ergo-node")

  @doc """
  Path to the `java` executable inside the downloaded bundle, or `nil` if the
  bundle is not present. Located by search so it tolerates the slightly
  different JRE layouts the platform archives use.
  """
  def bundled_java do
    exe = if match?({:win32, _}, :os.type()), do: "java.exe", else: "java"

    bundle_dir()
    |> find_files(exe)
    |> Enum.find(fn path -> Path.basename(Path.dirname(path)) == "bin" end)
  end

  @doc "Path to the node jar inside the downloaded bundle, or `nil` if absent."
  def bundled_jar do
    bundle_dir()
    |> find_files(@jar_file)
    |> List.first()
  end

  # Recursively collect files with the given basename under `dir`.
  defp find_files(dir, basename) do
    Path.wildcard(Path.join([dir, "**", basename]))
  end

  # Per-platform bundle asset. Returns `{url, :tar | :zip}`.
  defp bundle_asset do
    {platform, ext, kind} =
      case :os.type() do
        {:unix, :linux} -> {"linux", "tar.gz", :tar}
        {:unix, :darwin} -> {"macos", "tar.gz", :tar}
        {:win32, _} -> {"windows", "zip", :zip}
      end

    name = "ergo-node-v#{@core_version}-#{platform}-#{bundle_arch()}.#{ext}"
    {"#{@release_base}/#{name}", kind}
  end

  # Map the host architecture to the bundle's arch suffix ("x64" or "aarch64").
  defp bundle_arch do
    case :os.type() do
      {:win32, _} ->
        arch =
          System.get_env("PROCESSOR_ARCHITEW6432") ||
            System.get_env("PROCESSOR_ARCHITECTURE") || ""

        if arch =~ ~r/arm64/i, do: "aarch64", else: "x64"

      _ ->
        arch = to_string(:erlang.system_info(:system_architecture))
        if arch =~ "aarch64" or arch =~ "arm", do: "aarch64", else: "x64"
    end
  end

  # --- Files / paths ---

  def files_exist do
    jar = bundled_jar()
    java = bundled_java()
    Logger.info("[#{@coin_name_abbrev}] Checking bundle: jar=#{inspect(jar)}, java=#{inspect(java)}")
    jar != nil and java != nil
  end

  def get_conf_file_location do
    Path.join(get_coin_home_dir(), @conf_file)
  end

  def get_coin_home_dir do
    user_home_dir = System.user_home()

    case :os.type() do
      {:unix, :darwin} ->
        Path.join([user_home_dir, "Library", "Application Support", @home_dir_mac])

      {:unix, :linux} ->
        Path.join(user_home_dir, @home_dir_lin)

      {:win32, _} ->
        Path.join([user_home_dir, "AppData", "Roaming", @home_dir_win])

      _ ->
        Logger.error("[#{@coin_name_abbrev}] get_coin_home_dir: Running on an unknown OS!")
    end
  end

  # --- Auth ---

  @doc """
  Ergo auth is fixed (port + api_key constants), so this always succeeds. The
  api_key is carried in the `Auth` struct's `rpc_password` field, matching the
  shape the other coins use.
  """
  def get_auth_values do
    {:ok, %Auth{rpc_port: @rpc_port, rpc_user: "", rpc_password: @api_key}}
  end

  defp api_headers(auth), do: [{"api_key", auth.rpc_password}]

  # --- Download + config ---

  def download_coin do
    File.mkdir_p!(bundle_dir())
    {url, kind} = bundle_asset()
    archive_path = Path.join(bundle_dir(), Path.basename(url))
    Logger.info("[#{@coin_name_abbrev}] Downloading #{url}")

    case Req.get(url, into: File.stream!(archive_path)) do
      {:ok, %Req.Response{status: 200}} ->
        Logger.info("[#{@coin_name_abbrev}] Download complete, extracting bundle")

        case extract_bundle(archive_path, kind) do
          :ok ->
            File.rm(archive_path)
            ensure_java_executable()
            populate_conf_file()
            {:ok}

          {:error, reason} ->
            {:error, "Extract failed: #{inspect(reason)}"}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP error: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_bundle(archive_path, :tar) do
    :erl_tar.extract(String.to_charlist(archive_path), [
      :compressed,
      {:cwd, String.to_charlist(bundle_dir())}
    ])
  end

  defp extract_bundle(archive_path, :zip) do
    case :zip.extract(String.to_charlist(archive_path), [
           {:cwd, String.to_charlist(bundle_dir())}
         ]) do
      {:ok, _files} -> :ok
      other -> other
    end
  end

  # Extraction does not always preserve the exec bit, so make sure java can run.
  defp ensure_java_executable do
    case bundled_java() do
      nil -> :ok
      java -> File.chmod(java, 0o755)
    end
  end

  defp populate_conf_file do
    File.mkdir_p!(get_coin_home_dir())
    conf_path = get_conf_file_location()
    # HOCON quoted strings treat "\" as an escape char, and Java accepts "/"
    # path separators on every OS, so normalise to forward slashes.
    data_dir = String.replace(get_coin_home_dir(), "\\", "/")

    contents = """
    ergo {
        directory = "#{data_dir}"
        node {
            mining = false
        }
    }
    scorex {
        restApi {
            apiKeyHash = "#{@api_key_hash}"
            bindAddress = "127.0.0.1:#{@rpc_port}"
        }
    }
    """

    File.write(conf_path, contents)
  end

  # --- Daemon lifecycle ---

  def daemon_is_running(_auth) do
    case Req.get(@base_url <> "/info", receive_timeout: 2_000, retry: false) do
      {:ok, %Req.Response{status: 200}} -> true
      _ -> false
    end
  end

  def start_daemon do
    case bundled_java() do
      nil ->
        Logger.error("[#{@coin_name_abbrev}] Bundled Java runtime not found; cannot start node")
        {:error, :java_not_found}

      java ->
        jar_path = bundled_jar()
        conf_path = get_conf_file_location()

        # Ergo runs in the foreground, so manage it via a Port (avoids unbounded
        # memory growth from buffered stdout). JVM options must precede -jar.
        spawn(fn ->
          port =
            Port.open(
              {:spawn_executable, java},
              [
                :binary,
                :stderr_to_stdout,
                :exit_status,
                args: ["-Xmx#{@xmx}", "-jar", jar_path, "--mainnet", "-c", conf_path]
              ]
            )

          daemon_port_loop(port)
        end)

        Process.sleep(100)
        {:ok}
    end
  end

  defp daemon_port_loop(port) do
    receive do
      {^port, {:data, data}} ->
        Logger.info("[#{@coin_name_abbrev}] ergo: #{String.trim(data)}")
        daemon_port_loop(port)

      {^port, {:exit_status, 0}} ->
        Logger.info("[#{@coin_name_abbrev}] ergo node exited normally")

      {^port, {:exit_status, code}} ->
        Logger.error("[#{@coin_name_abbrev}] ergo node exited with status #{code}")
    end
  end

  def stop_daemon(auth) do
    case Req.post(@base_url <> "/node/shutdown", headers: api_headers(auth), retry: false) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        Logger.info("[#{@coin_name_abbrev}] Node shutdown requested")
        {:ok, status}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, error_message(status, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- Node / blockchain info (public endpoint) ---

  @doc """
  Polls `GET /info`. Retries while the node API is not yet listening (during
  startup), since a single call covers blocks, headers, peers and sync state.
  """
  def get_info(_auth) do
    url = @base_url <> "/info"

    Enum.reduce_while(1..@daemon_rpc_attempts, {:error, :no_attempts}, fn attempt, _acc ->
      case Req.get(url, retry: false) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          case GetInfo.from_json(body) do
            {:ok, response} -> {:halt, {:ok, response}}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        {:ok, %Req.Response{status: status}} ->
          Logger.info("[#{@coin_name_abbrev}] /info returned #{status}, waiting (#{attempt})")
          Process.sleep(1_000)
          {:cont, {:error, status}}

        {:error, reason} ->
          Process.sleep(1_000)
          {:cont, {:error, reason}}
      end
    end)
  end

  # --- Wallet (protected endpoints) ---

  def wallet_status(auth) do
    case Req.get(@base_url <> "/wallet/status", headers: api_headers(auth), retry: false) do
      {:ok, %Req.Response{status: 200, body: body}} -> WalletStatus.from_json(body)
      {:ok, %Req.Response{status: status, body: body}} -> {:error, error_message(status, body)}
      {:error, reason} -> {:error, reason}
    end
  end

  def wallet_balances(auth) do
    case Req.get(@base_url <> "/wallet/balances", headers: api_headers(auth), retry: false) do
      {:ok, %Req.Response{status: 200, body: body}} -> WalletBalances.from_json(body)
      {:ok, %Req.Response{status: status, body: body}} -> {:error, error_message(status, body)}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_transactions(auth) do
    case Req.get(@base_url <> "/wallet/transactions", headers: api_headers(auth), retry: false) do
      {:ok, %Req.Response{status: 200, body: body}} -> ListTransactions.from_json(body)
      {:ok, %Req.Response{status: status, body: body}} -> {:error, error_message(status, body)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a new wallet. Returns `{:ok, mnemonic}` where `mnemonic` is the
  15-word seed phrase the user must back up.
  """
  def wallet_init(auth, pass) do
    body = %{pass: pass}

    case Req.post(@base_url <> "/wallet/init", headers: api_headers(auth), json: body, retry: false) do
      {:ok, %Req.Response{status: 200, body: %{"mnemonic" => mnemonic}}} ->
        {:ok, mnemonic}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, error_message(status, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Restores a wallet from an existing 15-word mnemonic."
  def wallet_restore(auth, pass, mnemonic) do
    body = %{pass: pass, mnemonic: mnemonic, usePre1627KeyDerivation: false}

    case Req.post(@base_url <> "/wallet/restore",
           headers: api_headers(auth),
           json: body,
           retry: false
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 -> :ok
      {:ok, %Req.Response{status: status, body: body}} -> {:error, error_message(status, body)}
      {:error, reason} -> {:error, reason}
    end
  end

  def wallet_unlock(auth, pass) do
    case Req.post(@base_url <> "/wallet/unlock",
           headers: api_headers(auth),
           json: %{pass: pass},
           retry: false
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 -> :ok
      {:ok, %Req.Response{status: status, body: body}} -> {:error, error_message(status, body)}
      {:error, reason} -> {:error, reason}
    end
  end

  def wallet_lock(auth) do
    case Req.get(@base_url <> "/wallet/lock", headers: api_headers(auth), retry: false) do
      {:ok, %Req.Response{status: status}} when status in 200..299 -> :ok
      {:ok, %Req.Response{status: status, body: body}} -> {:error, error_message(status, body)}
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Addresses ---

  def get_addresses(auth) do
    case Req.get(@base_url <> "/wallet/addresses", headers: api_headers(auth), retry: false) do
      {:ok, %Req.Response{status: 200, body: addresses}} when is_list(addresses) ->
        {:ok, addresses}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, error_message(status, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns a receive address as `{:ok, %{result: address}}` (matching the shape
  the LiveViews expect). Uses the first managed address, deriving one if the
  wallet has none yet.
  """
  def get_receive_address(auth) do
    case get_addresses(auth) do
      {:ok, [first | _]} when is_binary(first) -> {:ok, %{result: first}}
      {:ok, _empty} -> derive_next_address(auth)
      other -> other
    end
  end

  def derive_next_address(auth) do
    case Req.post(@base_url <> "/wallet/deriveNextKey", headers: api_headers(auth), retry: false) do
      {:ok, %Req.Response{status: 200, body: %{"address" => address}}} when is_binary(address) ->
        {:ok, %{result: address}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, error_message(status, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Alias used by the receive tab's "New Address" button.
  def get_new_address(auth), do: derive_next_address(auth)

  @doc """
  Lightweight client-side check. Ergo mainnet P2PK addresses are base58 and
  start with "9". (The node's `/utils/address/{addr}` can validate fully once
  it is running.)
  """
  def validate_address(address) when is_binary(address) do
    String.starts_with?(address, "9") and String.length(address) >= 40 and
      String.length(address) <= 60
  end

  def validate_address(_), do: false

  @doc """
  Sends `amount` ERG to `address`. The node computes the fee automatically.
  Returns `{:ok, txid}`.
  """
  def send_to_address(auth, address, amount) do
    value = trunc(Float.round(amount * @nano_per_erg))
    payments = [%{address: address, value: value}]

    case Req.post(@base_url <> "/wallet/payment/send",
           headers: api_headers(auth),
           json: payments,
           retry: false
         ) do
      {:ok, %Req.Response{status: 200, body: txid}} when is_binary(txid) ->
        {:ok, txid}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, error_message(status, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- Helpers ---

  defp error_message(status, %{"detail" => detail}) when is_binary(detail),
    do: "HTTP #{status}: #{detail}"

  defp error_message(status, %{"reason" => reason}) when is_binary(reason),
    do: "HTTP #{status}: #{reason}"

  defp error_message(status, body), do: "HTTP #{status}: #{inspect(body)}"
end
