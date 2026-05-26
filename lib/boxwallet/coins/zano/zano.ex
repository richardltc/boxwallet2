defmodule Boxwallet.Coins.Zano do
  @moduledoc """
  Zano coin integration. Zano is a CryptoNote-based privacy coin (Boolberry lineage),
  so it does **not** speak the Bitcoin-Core RPC dialect that most other coins in this
  app use. Two separate daemons ship in the AppImage / Windows zip:

    * `zanod`         — node daemon. JSON-RPC at `:11211/json_rpc`. Methods like
                        `getinfo`, `getheight`, `gettransactions`.
    * `simplewallet`  — wallet daemon. Same binary upstream documents as an
                        interactive CLI, but runs as a JSON-RPC server when
                        invoked with `--rpc-bind-port=…`. We use `:11212/json_rpc`.
                        Methods like `getbalance`, `getaddress`, `transfer`,
                        `get_recent_txs_and_info`.

  The wallet daemon must be started separately, pointed at a wallet file, with the
  wallet password supplied on the command line. There is no `encryptwallet` or
  `walletpassphrase` equivalent — the password is set at wallet creation time and
  required every time `simplewallet` is started. This maps onto the BoxWallet
  encryption-status atoms as:

      :wes_unencrypted          — no wallet file on disk
      :wes_locked               — wallet file exists, simplewallet not running
      :wes_unlocked             — simplewallet running and answering RPC
      :wes_unlocked_for_staking — identical to :wes_unlocked for Zano (staking is
                                  automatic when simplewallet is running unlocked)
  """

  require Logger

  @coin_name "Zano"
  @coin_name_abbrev "ZANO"
  def coin_name_abbrev, do: @coin_name_abbrev

  @home_dir_lin ".Zano"
  @home_dir_mac "Zano"
  @home_dir_win "Zano"

  @core_version "2.1.17.469"
  def core_version, do: @core_version

  # Reference: https://build.zano.org/builds/zano-linux-x64-release-v2.1.17.469[1b1cc03].AppImage
  @download_file_linux "zano-linux-x64-release-v" <> @core_version <> "[1b1cc03].AppImage"
  @download_file_windows "zano-win-x64-release-v" <> @core_version <> "[1b1cc03].zip"

  @extracted_dir_linux "squashfs-root"

  @download_url "https://build.zano.org/builds/"

  @conf_file "zano.conf"
  @daemon_file_lin "zanod"
  @daemon_file_win "zanod.exe"
  @walletd_file_lin "simplewallet"
  @walletd_file_win "simplewallet.exe"

  @rpc_user "zanorpc"
  @rpc_port "11211"
  @walletd_rpc_port "11212"

  @wallet_file_name "boxwallet.zsw"

  @daemon_rpc_attempts 25
  @daemon_rpc_sleep_interval 1_000
  @walletd_start_attempts 30
  @walletd_start_sleep 500

  # --- Filesystem / install ---

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
        user_home_dir
    end
  end

  def get_conf_file_location do
    Path.join(get_coin_home_dir(), @conf_file)
  end

  def wallet_file_path do
    Path.join(BoxWallet.App.home_folder(), @wallet_file_name)
  end

  def wallet_file_exists? do
    File.exists?(wallet_file_path())
  end

  def get_daemon_filename do
    do_get_daemon_filename(:os.type(), to_string(:erlang.system_info(:system_architecture)))
  end

  defp do_get_daemon_filename({:win32, :nt}, _sys_info), do: {:ok, @daemon_file_win}

  defp do_get_daemon_filename({:unix, :linux}, sys_info) do
    if String.contains?(sys_info, "x86_64") or String.contains?(sys_info, "aarch64") do
      {:ok, @daemon_file_lin}
    else
      {:error, "Unsupported Linux architecture: #{sys_info}"}
    end
  end

  defp do_get_daemon_filename({:unix, :darwin}, sys_info) do
    if String.contains?(sys_info, "aarch64") or String.contains?(sys_info, "x86_64") do
      {:ok, @daemon_file_lin}
    else
      {:error, "Unsupported macOS architecture: #{sys_info}"}
    end
  end

  def get_walletd_filename do
    case :os.type() do
      {:win32, :nt} -> {:ok, @walletd_file_win}
      {:unix, _} -> {:ok, @walletd_file_lin}
      _ -> {:error, "Unsupported operating system"}
    end
  end

  defp get_download_filename do
    sys_info = to_string(:erlang.system_info(:system_architecture))

    case :os.type() do
      {:unix, :linux} ->
        cond do
          String.contains?(sys_info, "x86_64") ->
            {:ok, @download_file_linux}

          String.contains?(sys_info, "i386") ->
            {:error, "linux 386 is not currently supported for: #{@coin_name}"}

          true ->
            {:error,
             "Unsupported Linux architecture: #{sys_info} — Zano publishes x86_64 Linux builds only."}
        end

      {:unix, :darwin} ->
        {:error, "macOS builds of #{@coin_name} are not currently published by upstream."}

      {:win32, :nt} ->
        {:ok, @download_file_windows}

      _ ->
        {:error, "Unsupported operating system"}
    end
  end

  def files_exist do
    daemon_filename =
      case get_daemon_filename() do
        {:ok, name} ->
          name

        {:error, reason} ->
          Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
          ""
      end

    s = Path.join(BoxWallet.App.home_folder(), daemon_filename)
    Logger.info("[#{@coin_name_abbrev}] Checking for file: #{s}")
    File.exists?(s)
  end

  def get_auth_values do
    conf_file = get_conf_file_location()

    with {:ok, rpcport} <- BoxWallet.Coins.ConfigManager.get_label_value(conf_file, "rpcport"),
         {:ok, rpcuser} <- BoxWallet.Coins.ConfigManager.get_label_value(conf_file, "rpcuser"),
         {:ok, rpcpassword} <-
           BoxWallet.Coins.ConfigManager.get_label_value(conf_file, "rpcpassword") do
      auth = %BoxWallet.Coins.Auth{
        rpc_port: rpcport,
        rpc_user: rpcuser,
        rpc_password: rpcpassword
      }

      {:ok, auth}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp populate_conf_file do
    File.mkdir_p!(get_coin_home_dir())
    conf_file = get_conf_file_location()
    password = BoxWallet.Coins.ConfigManager.generate_random_string(20)

    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "rpcuser", @rpc_user)
    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "rpcpassword", password)
    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "daemon", "1")
    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "server", "1")
    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "rpcport", @rpc_port)
  end

  # --- Download / extraction ---

  def download_coin do
    app_home_dir = BoxWallet.App.home_folder()
    IO.puts("#{BoxWallet.App.name()} is downloading to: #{app_home_dir}")
    IO.puts("System detected as: #{:erlang.system_info(:system_architecture)}")

    case get_download_filename() do
      {:error, reason} ->
        Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
        {:error, reason}

      {:ok, file_name} ->
        full_file_dl_url = @download_url <> file_name
        full_file_path = Path.join(app_home_dir, file_name)
        Logger.info("[#{@coin_name_abbrev}] Downloading file to: #{full_file_path}")

        case Req.get(full_file_dl_url, into: File.stream!(full_file_path)) do
          {:ok, %Req.Response{status: 200}} ->
            IO.puts("Download complete, now extracting...")

            case unarchive_file(full_file_path, app_home_dir) do
              {:ok} ->
                Logger.info("[#{@coin_name_abbrev}] Extraction completed successfully")
                copy_extracted_files()
                tidy_downloaded_files(full_file_path)
                populate_conf_file()
                {:ok}

              {:error, reason} ->
                Logger.error("[#{@coin_name_abbrev}] Extraction failed: #{inspect(reason)}")
                {:error, "Extraction failed: #{reason}"}
            end

          {:ok, %Req.Response{status: status}} ->
            {:error, "HTTP error: #{status}"}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp copy_extracted_files do
    daemon_filename = unwrap_filename(get_daemon_filename())
    walletd_filename = unwrap_filename(get_walletd_filename())

    base = Path.join([BoxWallet.App.home_folder(), @extracted_dir_linux, "usr", "bin"])
    dest = BoxWallet.App.home_folder()

    for name <- [daemon_filename, walletd_filename], name != "" do
      src = Path.join(base, name)
      dst = Path.join(dest, name)
      Logger.info("[#{@coin_name_abbrev}] Copying from #{src} to #{dst}")

      if File.exists?(src) do
        File.cp!(src, dst)
        File.chmod!(dst, 0o755)
      else
        Logger.warning("[#{@coin_name_abbrev}] Expected binary not found in AppImage: #{src}")
      end
    end

    Logger.info("[#{@coin_name_abbrev}] Files copied and permissions set successfully.")
  end

  defp unwrap_filename({:ok, name}), do: name

  defp unwrap_filename({:error, reason}) do
    Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
    ""
  end

  defp tidy_downloaded_files(downloaded_file) do
    File.rm_rf!(Path.join(BoxWallet.App.home_folder(), @extracted_dir_linux))
    Logger.info("[#{@coin_name_abbrev}] Removing file: #{downloaded_file}")
    File.rm_rf!(downloaded_file)
  end

  defp unarchive_file(full_file_path, location) do
    with :ok <- File.chmod(full_file_path, 0o777),
         {_output, 0} <-
           System.cmd(full_file_path, ["--appimage-extract"],
             cd: location,
             stderr_to_stdout: true
           ) do
      sys_info = to_string(:erlang.system_info(:system_architecture))

      case :os.type() do
        {:unix, :linux} ->
          if String.contains?(sys_info, "x86_64") do
            File.rm_rf!(full_file_path)
          end

        {:win32, _} ->
          File.rm_rf!(full_file_path)

        _ ->
          :ok
      end

      Logger.info("[#{@coin_name_abbrev}] AppImage extraction completed successfully")
      {:ok}
    else
      {:error, reason} ->
        {:error, "Unable to chmod file: #{full_file_path} - #{inspect(reason)}"}

      {output, exit_code} ->
        {:error, "Command execution failed (exit #{exit_code}): #{output}"}
    end
  end

  # --- Node daemon (zanod) lifecycle ---

  def start_daemon do
    case get_daemon_filename() do
      {:error, reason} ->
        Logger.error("[#{@coin_name_abbrev}] start_daemon error: #{reason}")
        {:error, reason}

      {:ok, daemon_filename} ->
        full_path_daemon = Path.join([BoxWallet.App.home_folder(), daemon_filename])

        if File.exists?(full_path_daemon) do
          spawn(fn ->
            case :os.type() do
              {:win32, _} ->
                System.cmd("cmd.exe", ["/C", "start", "/b", full_path_daemon])

              _ ->
                System.cmd(full_path_daemon, ["--no-console", "--no-predownload"])
            end
          end)

          :ok
        else
          msg = "Daemon executable not found at #{full_path_daemon}"
          Logger.error("[#{@coin_name_abbrev}] #{msg}")
          {:error, msg}
        end
    end
  end

  def stop_daemon(_auth) do
    Logger.info("[#{@coin_name_abbrev}] Sending SIGINT to #{@coin_name} daemons...")

    case :os.type() do
      {:win32, _} ->
        for img <- [@walletd_file_win, @daemon_file_win] do
          System.cmd("taskkill", ["/IM", img], stderr_to_stdout: true)
        end

        {:ok, "daemons stopped"}

      _ ->
        for proc <- [@walletd_file_lin, @daemon_file_lin] do
          System.cmd("pkill", ["-INT", proc], stderr_to_stdout: true)
        end

        {:ok, "daemons stopped"}
    end
  end

  def daemon_is_running(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: 0,
        method: "getinfo",
        params: %{flags: 0}
      })

    url = "http://127.0.0.1:#{auth.rpc_port}/json_rpc"
    headers = [{"Content-Type", "application/json"}]

    Logger.info("[#{@coin_name_abbrev}] Attempting to call GetInfo to see if Daemon is running")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{status_code: 200}} -> true
      _ -> false
    end
  end

  # --- Wallet daemon (simplewallet) lifecycle ---

  def walletd_is_running do
    body =
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: 0,
        method: "getaddress",
        params: %{}
      })

    url = "http://127.0.0.1:#{@walletd_rpc_port}/json_rpc"
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, body, headers, timeout: 1_000, recv_timeout: 1_000) do
      {:ok, %{status_code: 200, body: response_body}} ->
        not String.contains?(response_body, "WALLET_RPC_NOT_INITIALIZED")

      _ ->
        false
    end
  end

  @doc """
  Spawns `simplewallet` against an existing wallet file. Returns `:ok` once the
  walletd RPC starts answering, or `{:error, reason}` if it never comes up in
  time.
  """
  def start_walletd(password) do
    if wallet_file_exists?() do
      do_spawn_walletd(password, false)
    else
      {:error, "No wallet file found. Encrypt the wallet first to create one."}
    end
  end

  @doc """
  Spawns `simplewallet` and generates a brand-new wallet file with the given
  password. Returns `:ok` once the walletd RPC starts answering.
  """
  def create_wallet(password) do
    if wallet_file_exists?() do
      {:error, "A wallet file already exists. Unlock it instead."}
    else
      do_spawn_walletd(password, true)
    end
  end

  defp do_spawn_walletd(password, generate_new?) do
    case get_walletd_filename() do
      {:error, reason} ->
        {:error, reason}

      {:ok, walletd} ->
        path = Path.join([BoxWallet.App.home_folder(), walletd])

        if not File.exists?(path) do
          {:error, "Wallet daemon not found at #{path}. Re-download Zano core files."}
        else
          args =
            [
              "--rpc-bind-ip=127.0.0.1",
              "--rpc-bind-port=#{@walletd_rpc_port}",
              "--daemon-address=127.0.0.1:#{@rpc_port}",
              "--password=#{password}"
            ] ++
              if generate_new? do
                ["--generate-new-wallet=#{wallet_file_path()}"]
              else
                ["--wallet-file=#{wallet_file_path()}"]
              end

          spawn(fn ->
            try do
              System.cmd(path, args, stderr_to_stdout: true)
            rescue
              e ->
                Logger.error("[#{@coin_name_abbrev}] walletd crashed: #{Exception.message(e)}")
            end
          end)

          wait_for_walletd_ready(@walletd_start_attempts)
        end
    end
  end

  defp wait_for_walletd_ready(0), do: {:error, "simplewallet did not respond in time"}

  defp wait_for_walletd_ready(attempts) do
    Process.sleep(@walletd_start_sleep)

    if walletd_is_running() do
      :ok
    else
      wait_for_walletd_ready(attempts - 1)
    end
  end

  def stop_walletd do
    Logger.info("[#{@coin_name_abbrev}] Stopping #{@walletd_file_lin}")

    case :os.type() do
      {:win32, _} ->
        System.cmd("taskkill", ["/IM", @walletd_file_win], stderr_to_stdout: true)

      _ ->
        System.cmd("pkill", ["-INT", @walletd_file_lin], stderr_to_stdout: true)
    end

    :ok
  end

  # --- Wallet encryption API (LiveView-facing) ---
  #
  # In Zano semantics there is no encrypt-in-place. These wrappers exist so the
  # LiveView code path is identical to Divi's:
  #
  #   wallet_encrypt(auth, password) — create a new wallet with this password
  #   wallet_unlock(auth, password)  — start walletd against existing wallet
  #   wallet_unlock_fs(auth, password) — same as unlock; staking is automatic
  #     once walletd is running unlocked

  def wallet_encrypt(_auth, password), do: create_wallet(password)
  def wallet_unlock(_auth, password), do: start_walletd(password)
  def wallet_unlock_fs(_auth, password), do: start_walletd(password)

  # --- Node RPC calls ---

  def get_info(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: 0,
        method: "getinfo",
        params: %{flags: 1_048_575}
      })

    url = "http://127.0.0.1:#{auth.rpc_port}/json_rpc"
    headers = [{"Content-Type", "application/json"}]

    Enum.reduce_while(1..@daemon_rpc_attempts, {:error, :no_attempts}, fn attempt, _acc ->
      Logger.info(
        "[#{@coin_name_abbrev}] Attempting to GetInfo (attempt #{attempt}/#{@daemon_rpc_attempts})"
      )

      case HTTPoison.post(url, body, headers) do
        {:ok, %{body: response_body}} ->
          Logger.info("[#{@coin_name_abbrev}] GetInfo response: #{response_body}")

          case BoxWallet.Coins.Zano.GetInfo.from_json(response_body) do
            {:ok, response} ->
              {:halt, {:ok, response}}

            {:error, reason} ->
              Logger.error("[#{@coin_name_abbrev}] Failed to parse GetInfo: #{inspect(reason)}")
              {:halt, {:error, reason}}
          end

        {:error, %HTTPoison.Error{reason: reason}} ->
          Process.sleep(@daemon_rpc_sleep_interval)
          {:cont, {:error, reason}}
      end
    end)
  end

  # --- Wallet RPC calls (simplewallet) ---

  defp walletd_rpc(method, params) do
    body =
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: 0,
        method: method,
        params: params
      })

    url = "http://127.0.0.1:#{@walletd_rpc_port}/json_rpc"
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, body, headers, recv_timeout: 10_000) do
      {:ok, %{body: response_body}} ->
        {:ok, response_body}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def get_balance(_auth) do
    case walletd_rpc("getbalance", %{}) do
      {:ok, body} -> BoxWallet.Coins.Zano.GetBalance.from_json(body)
      {:error, reason} -> {:error, reason}
    end
  end

  def get_receive_address(_auth) do
    case walletd_rpc("getaddress", %{}) do
      {:ok, body} ->
        case BoxWallet.Coins.Zano.GetAddress.from_json(body) do
          {:ok, %{result: %{address: address}}} when is_binary(address) ->
            {:ok, %{result: address}}

          other ->
            other
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_new_address(auth), do: get_receive_address(auth)

  def get_wallet_info(auth) do
    with {:ok, balance_resp} <- get_balance(auth),
         {:ok, addr_resp} <- get_receive_address(auth) do
      atomic = 1_000_000_000_000
      r = balance_resp.result || %BoxWallet.Coins.Zano.GetBalance.Result{}

      result = %BoxWallet.Coins.Zano.GetWalletInfo.Result{
        active_wallet: wallet_file_path(),
        balance: (r.balance || 0) / atomic,
        unconfirmed_balance: (r.awaiting_in || 0) / atomic,
        immature_balance: max((r.balance || 0) - (r.unlocked_balance || 0), 0) / atomic,
        address: addr_resp.result || "",
        encryption_status: "unlocked"
      }

      {:ok, %BoxWallet.Coins.Zano.GetWalletInfo{result: result, error: nil, id: 0}}
    end
  end

  def list_transactions(_auth, current_height \\ 0) do
    params = %{offset: 0, count: 10, update_provision_info: false}

    case walletd_rpc("get_recent_txs_and_info", params) do
      {:ok, body} ->
        BoxWallet.Coins.Zano.GetRecentTxs.from_json(body, current_height)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate_address(address) when is_binary(address) do
    # Zano standard addresses start with "Zx" and are ~97 chars long.
    # Integrated addresses start with "iZ" and are slightly longer.
    cond do
      String.starts_with?(address, "Zx") and String.length(address) in 95..100 -> true
      String.starts_with?(address, "iZ") and String.length(address) in 105..115 -> true
      true -> false
    end
  end

  def validate_address(_), do: false

  def send_to_address(_auth, address, amount) when is_number(amount) do
    atomic = round(amount * 1_000_000_000_000)
    # ~0.01 ZANO default fee
    fee = 10_000_000_000

    params = %{
      destinations: [%{address: address, amount: atomic}],
      fee: fee,
      mixin: 10,
      payment_id: ""
    }

    case walletd_rpc("transfer", params) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, %{"result" => %{"tx_hash" => tx_hash}}} ->
            {:ok, tx_hash}

          {:ok, %{"error" => %{"message" => message}}} ->
            {:error, message}

          {:ok, %{"error" => error}} when not is_nil(error) ->
            {:error, inspect(error)}

          _ ->
            {:error, "Unexpected response from transfer: #{body}"}
        end

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # --- Block-height oracle ---

  def get_block_height do
    url = "https://explorer.zano.org/api/get_info"

    case Req.get(url) do
      {:ok, %{status: 200, body: %{"height" => count}}} when is_integer(count) ->
        {:ok, count}

      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        case Integer.parse(body) do
          {count, _} -> {:ok, count}
          :error -> {:error, "Could not parse height from #{body}"}
        end

      {:ok, %{status: status}} ->
        {:error, "API returned status code: #{status}"}

      {:error, exception} ->
        {:error, exception}
    end
  end
end
