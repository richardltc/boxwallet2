defmodule Boxwallet.Coins.Ergo do
  @moduledoc """
  Interaction with the Ergo (ERG) node daemon.

  Unlike the Bitcoin-Core forks in BoxWallet, Ergo is a JVM application
  distributed as a single fat JAR (`ergo-<version>.jar`) that requires a Java
  runtime. The node is launched in the foreground via an Erlang `Port`
  (it does not fork like `*coind`), exposes a REST API (not JSON-RPC), and
  authenticates protected endpoints with an `api_key` HTTP header.

  Key differences handled here:

    * Distribution: download the jar only (no archive/extract step).
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

  @jar_file "ergo-#{@core_version}.jar"
  def jar_file, do: @jar_file

  @download_url "https://github.com/ergoplatform/ergo/releases/download/v#{@core_version}/#{@jar_file}"

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

  # --- Java runtime detection (checked when the Ergo page is opened) ---

  @doc "Returns true if a `java` executable is on the PATH."
  def java_installed? do
    System.find_executable("java") != nil
  end

  @doc "OS-specific instructions shown to the user when Java is missing."
  def java_install_instructions do
    case :os.type() do
      {:unix, :darwin} ->
        "Ergo needs a Java runtime. Install one with `brew install openjdk`, or download from https://adoptium.net/, then reopen this page."

      {:unix, :linux} ->
        "Ergo needs a Java runtime. Install one with e.g. `sudo apt install default-jre` (Debian/Ubuntu) or download from https://adoptium.net/, then reopen this page."

      {:win32, _} ->
        "Ergo needs a Java runtime. Download and install one from https://adoptium.net/, make sure `java` is on your PATH, then reopen this page."

      _ ->
        "Ergo needs a Java runtime. Install one from https://adoptium.net/, then reopen this page."
    end
  end

  # --- Files / paths ---

  def files_exist do
    jar_path = jar_path()
    Logger.info("[#{@coin_name_abbrev}] Checking for file: #{jar_path}")
    File.exists?(jar_path)
  end

  defp jar_path, do: Path.join(BoxWallet.App.home_folder(), @jar_file)

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
    app_home_dir = BoxWallet.App.home_folder()
    File.mkdir_p!(app_home_dir)
    jar_path = jar_path()
    Logger.info("[#{@coin_name_abbrev}] Downloading #{@download_url} to #{jar_path}")

    case Req.get(@download_url, into: File.stream!(jar_path)) do
      {:ok, %Req.Response{status: 200}} ->
        Logger.info("[#{@coin_name_abbrev}] Download complete, writing config")
        populate_conf_file()
        {:ok}

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP error: #{status}"}

      {:error, reason} ->
        {:error, reason}
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
    case System.find_executable("java") do
      nil ->
        Logger.error("[#{@coin_name_abbrev}] Java runtime not found; cannot start node")
        {:error, :java_not_found}

      java ->
        jar_path = jar_path()
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
