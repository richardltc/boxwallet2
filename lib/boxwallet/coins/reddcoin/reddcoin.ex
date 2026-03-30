# lib/my_app/coins/divi.ex
defmodule Boxwallet.Coins.ReddCoin do
  require Logger

  # @behaviour BoxWallet.CoinDaemon
  # import BoxWallet.App

  @coin_name "ReddCoin"
  @coin_name_abbrev "RDD"
  def coin_name_abbrev, do: @coin_name_abbrev

  @home_dir_lin ".reddcoin"
  @home_dir_mac "Reddcoin"
  @home_dir_win "Reddcoin"

  @core_version "4.22.9"
  def core_version, do: @core_version
  @download_file_arm32 "reddcoin-" <> @core_version <> "-arm-linux-gnueabihf.tar.gz"
  @download_file_arm64 "reddcoin-" <> @core_version <> "aarch64-linux-gnu.tar.gz"
  @download_file_linux "reddcoin-" <> @core_version <> "-x86_64-linux-gnu.tar.gz"
  @download_file_windows "reddcoin-" <> @core_version <> "-win64.zip"
  # @download_file_bs "primer.zip"

  # https://download.reddcoin.com/bin/reddcoin-core-4.22.9/
  @extracted_dir_linux "reddcoin-" <> @core_version
  @extracted_dir_windows "reddcoin-" <> @core_version

  @download_url "https://download.reddcoin.com/bin/reddcoin-core-" <> @core_version <> "/"
  # @download_url_bs "https://"

  @conf_file "reddcoin.conf"
  @cli_file_lin "reddcoin-cli"
  @cli_file_win "reddcoin-cli.exe"
  @daemon_file_lin "reddcoind"
  @daemon_file_win "reddcoind.exe"

  # reddcoin.conf file constants
  @rpc_user "reddcoinrpc"
  @rpc_port "45443"

  # @tip_address "RaPRrgr3ztttsMY7MWitGWvxJYS2hA6quN"
  #
  @daemon_stop_attempts 25
  @daemon_rpc_attempts 25
  @daemon_rpc_sleep_interval 1000

  # CWalletESUnlockedForStaking = "unlocked-for-staking"
  # CWalletESLocked             = "locked"
  # CWalletESUnlocked           = "unlocked"
  # CWalletESUnencrypted        = "unencrypted"

  # General CLI command constants
  # // cCommandGetBCInfo             string = "getblockchaininfo"
  # cCommandGetInfo string = "getinfo"
  # // cCommandGetStakingInfo        string = "getstakinginfo"
  # // cCommandListReceivedByAddress string = "listreceivedbyaddress"
  # // cCommandListTransactions      string = "listtransactions"
  # // cCommandGetNetworkInfo        string = "getnetworkinfo"
  # // cCommandGetNewAddress         string = "getnewaddress"
  # cCommandGetWalletInfo string = "getwalletinfo"
  # // cCommandSendToAddress         string = "sendtoaddress"
  # // cCommandMNSyncStatus1         string = "mnsync"
  # // cCommandMNSyncStatus2         string = "status"

  defp copy_extracted_files() do
    cli_filename =
      case get_cli_filename() do
        {:ok, name} ->
          name

        {:error, reason} ->
          Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
          ""
      end

    daemon_filename =
      case get_daemon_filename() do
        {:ok, name} ->
          name

        {:error, reason} ->
          Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
          ""
      end

    full_path_cli =
      Path.join([BoxWallet.App.home_folder(), @extracted_dir_linux, "bin", cli_filename])

    full_path_daemon =
      Path.join([BoxWallet.App.home_folder(), @extracted_dir_linux, "bin", daemon_filename])

    dest_path_cli =
      Path.join([BoxWallet.App.home_folder(), cli_filename])

    dest_path_daemon =
      Path.join([BoxWallet.App.home_folder(), daemon_filename])

    Logger.info("[#{@coin_name_abbrev}] Copying from #{full_path_cli} to #{dest_path_cli}")
    File.cp!(full_path_cli, dest_path_cli)
    Logger.info("[#{@coin_name_abbrev}] Copying from #{full_path_daemon} to #{dest_path_daemon}")
    File.cp!(full_path_daemon, dest_path_daemon)

    File.chmod!(dest_path_cli, 0o755)
    File.chmod!(dest_path_daemon, 0o755)

    Logger.info("[#{@coin_name_abbrev}] Files copied and permissions set successfully.")
  end

  def create_wallet(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "createwallet",
        params: ["BoxWallet"]
      })

    url = "http://127.0.0.1:#{auth.rpc_port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to CreateWallet...")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        IO.inspect(response_body)

        if !String.contains?(response_body, "\"error\":null") do
          {:error, :wrong_response}
        else
          :ok
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def load_wallet(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "loadwallet",
        params: ["BoxWallet"]
      })

    url = "http://127.0.0.1:#{auth.rpc_port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to LoadWallet...")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => nil}} ->
            :ok

          {:ok, %{"error" => %{"message" => message}}} ->
            {:error, message}

          _ ->
            {:error, :unexpected_response}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def daemon_is_running(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "getinfo",
        params: []
      })

    url = "http://127.0.0.1:#{auth.rpc_port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to call GetInfo to see if Daemon is running")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        IO.inspect(response_body)
        IO.puts("We think the Daemon is running...")
        true

      {:error, %HTTPoison.Error{reason: _reason}} ->
        false
    end
  end

  def download_coin() do
    app_home_dir = BoxWallet.App.home_folder()
    # File.mkdir_p!(app_home_dir)
    IO.puts("#{BoxWallet.App.name()} is downloading to: #{app_home_dir}")
    IO.puts("System detected as: #{:erlang.system_info(:system_architecture)}")

    # The result will contain, :ok, the download_to and download_from

    file_name =
      case get_download_filename() do
        {:ok, name} ->
          name

        {:error, reason} ->
          Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
          # Keep empty string or use some default
          ""
      end

    full_file_dl_url = @download_url <> file_name

    full_file_path = Path.join(app_home_dir, file_name)
    Logger.info("[#{@coin_name_abbrev}] Downloading file to: #{full_file_path}")

    case Req.get(full_file_dl_url, into: File.stream!(full_file_path)) do
      {:ok, %Req.Response{status: 200}} ->
        IO.puts("Download complete, now extracting...")

        case BoxWallet.Coins.CoinHelper.unarchive(full_file_path, app_home_dir) do
          :ok ->
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

  def files_exist() do
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
    File.exists?(Path.join(BoxWallet.App.home_folder(), daemon_filename))
  end

  def get_auth_values() do
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

      # IO.inspect(auth, label: "Auth values")
      {:ok, auth}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def get_block_height() do
    url = "https://blockbook.reddcoin.com/api/v2"

    case Req.get(url) do
      {:ok, %{status: 200, body: %{"backend" => %{"blocks" => blocks}}}}
      when is_integer(blocks) ->
        Logger.info("[#{@coin_name_abbrev}] Blockheight found: #{blocks}")
        {:ok, blocks}

      {:ok, %{status: 200, body: _body}} ->
        {:error, "Unexpected response format"}

      {:ok, %{status: status}} ->
        {:error, "API returned status code: #{status}"}

      {:error, exception} ->
        {:error, exception}
    end
  end

  def get_conf_file_location() do
    Path.join(get_coin_home_dir(), @conf_file)
  end

  def get_coin_home_dir() do
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

  def get_cli_filename() do
    do_get_cli_filename(:os.type(), to_string(:erlang.system_info(:system_architecture)))
  end

  # Function clause for Windows. It ignores the second argument (sys_info).
  defp do_get_cli_filename({:win32, :nt}, _sys_info) do
    {:ok, @cli_file_win}
  end

  # Function clause for Linux.
  defp do_get_cli_filename({:unix, :linux}, sys_info) do
    cond do
      String.contains?(sys_info, "x86_64") or String.contains?(sys_info, "aarch64") ->
        {:ok, @cli_file_lin}

      # ... other error conditions for Linux
      true ->
        {:error, "Unsupported Linux architecture: #{sys_info}"}
    end
  end

  # Function clause for macOS.
  defp do_get_cli_filename({:unix, :darwin}, sys_info) do
    cond do
      String.contains?(sys_info, "aarch64") or String.contains?(sys_info, "x86_64") ->
        {:ok, @cli_file_lin}

      # ... other error conditions for macOS
      true ->
        {:error, "Unsupported macOS architecture: #{sys_info}"}
    end
  end

  def get_daemon_filename() do
    do_get_daemon_filename(:os.type(), to_string(:erlang.system_info(:system_architecture)))
  end

  # Function clause for Windows. It ignores the second argument (sys_info).
  defp do_get_daemon_filename({:win32, :nt}, _sys_info) do
    {:ok, @daemon_file_win}
  end

  # Function clause for Linux.
  defp do_get_daemon_filename({:unix, :linux}, sys_info) do
    cond do
      String.contains?(sys_info, "x86_64") or String.contains?(sys_info, "aarch64") ->
        {:ok, @daemon_file_lin}

      # ... other error conditions for Linux
      true ->
        {:error, "Unsupported Linux architecture: #{sys_info}"}
    end
  end

  # Function clause for macOS.
  defp do_get_daemon_filename({:unix, :darwin}, sys_info) do
    cond do
      String.contains?(sys_info, "aarch64") or String.contains?(sys_info, "x86_64") ->
        {:ok, @daemon_file_lin}

      # ... other error conditions for macOS
      true ->
        {:error, "Unsupported macOS architecture: #{sys_info}"}
    end
  end

  defp get_download_filename() do
    sys_info = to_string(:erlang.system_info(:system_architecture))

    # Determine the file path and URL based on OS and architecture
    result =
      case :os.type() do
        {:unix, :linux} ->
          cond do
            String.contains?(sys_info, "arm71") ->
              {:ok, @download_file_arm32}

            String.contains?(sys_info, "aarch64") ->
              {:ok, @download_file_arm64}

            String.contains?(sys_info, "i386") ->
              {:error, "linux 386 is not currently supported for: #{@coin_name}"}

            String.contains?(sys_info, "x86_64") ->
              {:ok, @download_file_linux}

            true ->
              IO.puts("Unsupported system: #{:erlang.system_info(:system_architecture)}")
              {:error, "Unsupported Linux architecture: #{sys_info}"}
          end

        {:unix, :darwin} ->
          cond do
            String.contains?(sys_info, "aarch64") ->
              {:ok, @download_file_mac64}

            String.contains?(sys_info, "i386") ->
              {:error, "mac 386 is not currently supported for: #{@coin_name}"}

            String.contains?(sys_info, "x86_64") ->
              {:ok, @download_file_mac64}

            true ->
              IO.puts("Unsupported system: #{:erlang.system_info(:system_architecture)}")
              {:error, "Unsupported macOS architecture: #{sys_info}"}
          end

        # Covers Windows
        {:win32, :nt} ->
          {:ok, @download_file_windows}

        _ ->
          {:error, "Unsupported operating system"}
      end
  end

  def get_blockchain_info(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "getblockchaininfo",
        params: []
      })

    url = "http://127.0.0.1:#{auth.rpc_port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Enum.reduce_while(1..@daemon_rpc_attempts, {:error, :no_attempts}, fn attempt, _acc ->
      Logger.info(
        "[#{@coin_name_abbrev}] Attempting to GetBlockchainInfo (attempt #{attempt}/#{@daemon_rpc_attempts})"
      )

      case HTTPoison.post(url, body, headers) do
        {:ok, %{body: response_body}} ->
          IO.inspect(response_body)

          if String.contains?(response_body, "Loading") ||
               String.contains?(response_body, "Preparing databases") ||
               String.contains?(response_body, "Rewinding") ||
               String.contains?(response_body, "RPC server started") ||
               String.contains?(response_body, "Verifying") do
            Logger.info(
              "[#{@coin_name_abbrev}] Waiting for Daemon to be ready, attempt #{attempt}"
            )

            Process.sleep(1000)
            {:cont, {:error, :wrong_response}}
          else
            # Now we need to convert into a GetBlockchainInfo before returning it to the UI
            case BoxWallet.Coins.ReddCoin.GetBlockchainInfo.from_json(response_body) do
              {:ok, response} ->
                # Process the successful response - Halt with result
                {:halt, {:ok, response}}

              {:error, reason} ->
                # Handle the error
                Logger.error("[#{@coin_name_abbrev}] Failed to parse: #{inspect(reason)}")
                {:halt, {:error, reason}}
            end
          end

        {:error, %HTTPoison.Error{reason: reason}} ->
          Process.sleep(3000)
          {:cont, {:error, reason}}
      end
    end)
  end

  def get_peer_info(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltest",
        method: "getpeerinfo",
        params: []
      })

    url = "http://127.0.0.1:#{auth.rpc_port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to GetPeerInfo")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case BoxWallet.Coins.ReddCoin.GetPeerInfo.from_json(response_body) do
          {:ok, response} ->
            {:ok, response}

          {:error, reason} ->
            Logger.error("[#{@coin_name_abbrev}] Failed to parse GetPeerInfo: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def get_receive_address(auth) do
    case list_received_by_address(auth) do
      {:ok, [%{"address" => address} | _]} ->
        {:ok, %{result: address}}

      _ ->
        get_new_address(auth)
    end
  end

  defp list_received_by_address(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltest",
        method: "listreceivedbyaddress",
        params: [0, true]
      })

    url = "http://127.0.0.1:#{auth.rpc_port}/wallet/BoxWallet"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"result" => result}} when is_list(result) and result != [] ->
            {:ok, result}

          _ ->
            {:ok, []}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def get_new_address(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltest",
        method: "getnewaddress",
        params: []
      })

    url = "http://127.0.0.1:#{auth.rpc_port}/wallet/BoxWallet"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to GetNewAddress")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case BoxWallet.Coins.ReddCoin.GetNewAddress.from_json(response_body) do
          {:ok, response} ->
            {:ok, response}

          {:error, reason} ->
            Logger.error(
              "[#{@coin_name_abbrev}] Failed to parse GetNewAddress: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def get_wallet_info(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "getwalletinfo",
        params: []
      })

    url = "http://127.0.0.1:#{auth.rpc_port}/wallet/BoxWallet"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Enum.reduce_while(1..@daemon_rpc_attempts, {:error, :no_attempts}, fn attempt, _acc ->
      Logger.info(
        "[#{@coin_name_abbrev}] Attempting to GetWalletInfo (attempt #{attempt}/#{@daemon_rpc_attempts})"
      )

      case HTTPoison.post(url, body, headers) do
        {:ok, %{body: response_body}} ->
          IO.inspect(response_body)

          if String.contains?(response_body, "Loading") ||
               String.contains?(response_body, "Preparing databases") ||
               String.contains?(response_body, "Rewinding") ||
               String.contains?(response_body, "RPC server started") ||
               String.contains?(response_body, "Verifying") do
            Logger.info(
              "[#{@coin_name_abbrev}] Waiting for Daemon to be ready, attempt #{attempt}"
            )

            Process.sleep(1000)
            {:cont, {:error, :wrong_response}}
          else
            # Now we need to convert into a GetBlockchainInfo before returning it to the UI
            case BoxWallet.Coins.ReddCoin.GetWalletInfo.from_json(response_body) do
              {:ok, response} ->
                # Process the successful response - Halt with result
                {:halt, {:ok, response}}

              {:error, reason} ->
                # Handle the error
                Logger.error("[#{@coin_name_abbrev}] Failed to parse: #{inspect(reason)}")
                {:halt, {:error, reason}}
            end
          end

        {:error, %HTTPoison.Error{reason: reason}} ->
          Process.sleep(3000)
          {:cont, {:error, reason}}
      end
    end)
  end

  def list_transactions(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltest",
        method: "listtransactions",
        params: []
      })

    url = "http://127.0.0.1:#{auth.rpc_port}/wallet/BoxWallet"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to ListTransactions")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case BoxWallet.Coins.ReddCoin.ListTransactions.from_json(response_body) do
          {:ok, response} ->
            {:ok, response}

          {:error, reason} ->
            Logger.error(
              "[#{@coin_name_abbrev}] Failed to parse ListTransactions: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def get_staking_info(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "getstakinginfo",
        params: []
      })

    url = "http://127.0.0.1:#{auth.rpc_port}/wallet/BoxWallet"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to GetStakingInfo")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        IO.inspect(response_body)

        case BoxWallet.Coins.ReddCoin.GetStakingInfo.from_json(response_body) do
          {:ok, response} ->
            {:ok, response}

          {:error, reason} ->
            Logger.error(
              "[#{@coin_name_abbrev}] Failed to parse GetStakingInfo: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp populate_conf_file() do
    File.mkdir_p!(get_coin_home_dir())
    conf_file = get_conf_file_location()
    password = BoxWallet.Coins.ConfigManager.generate_random_string(20)

    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "rpcuser", @rpc_user)
    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "rpcpassword", password)

    # On Windows, reddcoind doesn't support daemon=1, so we skip it
    # and use a Port-based approach in start_daemon/0 instead
    case :os.type() do
      {:win32, _} -> :ok
      _ -> BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "daemon", "1")
    end

    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "server", "1")
    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "rpcport", @rpc_port)
  end

  defp tidy_downloaded_files(downloaded_file) do
    File.rm_rf!(Path.join(BoxWallet.App.home_folder(), @extracted_dir_linux))
    Logger.info("[#{@coin_name_abbrev}] Removing file: #{downloaded_file}")
    File.rm_rf!(downloaded_file)
  end

  # def install_daemon do
  #   try do
  #     File.mkdir_p!(@install_path)
  #     {:ok, response} = HTTPoison.get(@daemon_url)
  #     tarball_path = Path.join(System.tmp_dir!(), "bitcoin.tar.gz")
  #     File.write!(tarball_path, response.body)
  #     :ok = :erl_tar.extract(tarball_path, [:compressed, {:cwd, to_charlist(@install_path)}])

  #     extracted_bin =
  #       if :os.type() in [{:win32, _} | _],
  #         do: Path.join(@install_path, "bitcoind.exe"),
  #         else: Path.join(@install_path, "bitcoind")

  #     File.rename(extracted_bin, @daemon_bin)
  #     File.rm!(tarball_path)
  #     unless :os.type() in [{:win32, _} | _], do: File.chmod!(@daemon_bin, 0o755)
  #     :ok
  #   rescue
  #     e -> {:error, Exception.message(e)}
  #   end
  # end

  def start_daemon do
    daemon_filename =
      case get_daemon_filename() do
        {:ok, name} ->
          name

        {:error, reason} ->
          Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
          ""
      end

    full_path_daemon =
      Path.join([BoxWallet.App.home_folder(), daemon_filename])

    case :os.type() do
      {:win32, _} ->
        # On Windows, daemon=1 is not supported, so we run via a Port
        # which avoids unbounded memory growth from buffered stdout
        spawn(fn ->
          port =
            Port.open(
              {:spawn_executable, full_path_daemon},
              [:binary, :stderr_to_stdout, :exit_status]
            )

          daemon_port_loop(port)
        end)

      _ ->
        # On Linux/Mac, daemon=1 in conf causes the process to fork to background,
        # so System.cmd returns quickly
        spawn(fn ->
          System.cmd(full_path_daemon, [])
        end)
    end

    # Give it a moment to start, then check if it's running
    Process.sleep(100)
    {:ok}
  end

  defp daemon_port_loop(port) do
    receive do
      {^port, {:data, data}} ->
        Logger.info("[#{@coin_name_abbrev}] reddcoind: #{String.trim(data)}")
        daemon_port_loop(port)

      {^port, {:exit_status, 0}} ->
        Logger.info("[#{@coin_name_abbrev}] reddcoind exited normally")

      {^port, {:exit_status, code}} ->
        Logger.error("[#{@coin_name_abbrev}] reddcoind exited with status #{code}")
    end
  end

  def stop_daemon(auth) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "stop",
        params: []
      })

    url = "http://127.0.0.1:#{auth.rpc_port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Enum.reduce_while(1..@daemon_stop_attempts, {:error, :no_attempts}, fn attempt, _acc ->
      Logger.info(
        "[#{@coin_name_abbrev}] Attempting to stop daemon (attempt #{attempt}/#{@daemon_stop_attempts})"
      )

      case HTTPoison.post(url, body, headers) do
        {:ok, %{body: response_body}} ->
          case Jason.decode(response_body) do
            {:ok, %{"error" => nil}} ->
              Logger.info(
                "[#{@coin_name_abbrev}] Successfully stopped daemon on attempt #{attempt}"
              )

              {:halt, {:ok, response_body}}

            _ ->
              Process.sleep(@daemon_rpc_sleep_interval)
              {:cont, {:error, :wrong_response}}
          end

        {:error, %HTTPoison.Error{reason: reason}} ->
          Process.sleep(@daemon_rpc_sleep_interval)
          {:cont, {:error, reason}}
      end
    end)
  end

  # def daemon_running? do
  #   if :os.type() in [{:win32, _} | _] do
  #     {output, 0} =
  #       System.cmd("tasklist", ["/FI", "IMAGENAME eq bitcoind.exe"], stderr_to_stdout: true)

  #     String.contains?(output, "bitcoind.exe")
  #   else
  #     case System.cmd("pgrep", ["-f", @daemon_bin], stderr_to_stdout: true) do
  #       {_, 0} -> true
  #       _ -> false
  #     end
  #   end
  # end

  defp wallet_exists? do
    wallet_dir = Path.join(get_coin_home_dir(), "BoxWallet")

    File.dir?(wallet_dir)
  end

  def wallet_encrypt(auth, password) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "encryptwallet",
        params: ["#{password}"]
      })

    url = "http://127.0.0.1:#{auth.rpc_port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    url = url <> "/wallet/BoxWallet"

    Logger.info("[#{@coin_name_abbrev}] Attempting to Encrypt wallet")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => nil}} ->
            :ok

          {:ok, %{"error" => %{"message" => message}}} ->
            {:error, message}

          {:ok, %{"error" => error}} ->
            {:error, inspect(error)}

          {:error, _} ->
            {:error, "Failed to parse response"}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %HTTPoison.Error{reason: reason}}
    end
  end

  def wallet_unlock(auth, password) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "walletpassphrase",
        params: ["#{password}", 0]
      })

    url = "http://127.0.0.1:#{auth.rpc_port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    url = url <> "/wallet/BoxWallet"

    Logger.info("[#{@coin_name_abbrev}] Attempting to Unlock wallet")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => nil}} ->
            :ok

          {:ok, %{"error" => %{"message" => message}}} ->
            {:error, message}

          {:ok, %{"error" => error}} ->
            {:error, inspect(error)}

          {:error, _} ->
            {:error, "Failed to parse response"}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %HTTPoison.Error{reason: reason}}
    end
  end

  def wallet_unlock_fs(auth, password) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "walletpassphrase",
        params: ["#{password}", 9_999_999, true]
      })

    url = "http://127.0.0.1:#{auth.rpc_port}/wallet/BoxWallet"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to Unlock wallet for staking")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => nil}} ->
            # After unlocking, enable staking on both wallet and node level
            set_staking(auth, true)
            staking(auth, true)
            :ok

          {:ok, %{"error" => %{"message" => message}}} ->
            {:error, message}

          {:ok, %{"error" => error}} ->
            {:error, inspect(error)}

          {:error, _} ->
            {:error, "Failed to parse response"}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %HTTPoison.Error{reason: reason}}
    end
  end

  def set_staking(auth, enable) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "setstaking",
        params: [enable]
      })

    url = "http://127.0.0.1:#{auth.rpc_port}/wallet/BoxWallet"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to set wallet staking to #{enable}")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => nil}} ->
            :ok

          {:ok, %{"error" => %{"message" => message}}} ->
            Logger.error("[#{@coin_name_abbrev}] setstaking failed: #{message}")
            {:error, message}

          {:ok, %{"error" => error}} ->
            Logger.error("[#{@coin_name_abbrev}] setstaking failed: #{inspect(error)}")
            {:error, inspect(error)}

          {:error, _} ->
            {:error, "Failed to parse response"}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %HTTPoison.Error{reason: reason}}
    end
  end

  @doc """
  Validates a ReddCoin address.
  A valid address must be exactly 34 characters long and start with "R".
  """
  def validate_address(address) when is_binary(address) do
    String.length(address) == 34 and String.starts_with?(address, "R")
  end

  def validate_address(_), do: false

  def send_to_address(auth, address, amount) do
    # Set the transaction fee before sending
    set_tx_fee(auth, 0.0001)

    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "boxwallet",
        method: "sendtoaddress",
        params: [address, amount]
      })

    url = "http://127.0.0.1:#{auth.rpc_port}/wallet/BoxWallet"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to SendToAddress #{address} amount #{amount}")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => nil, "result" => txid}} ->
            {:ok, txid}

          {:ok, %{"error" => %{"message" => message}}} ->
            Logger.error("[#{@coin_name_abbrev}] sendtoaddress failed: #{message}")
            {:error, message}

          {:ok, %{"error" => error}} ->
            Logger.error("[#{@coin_name_abbrev}] sendtoaddress failed: #{inspect(error)}")
            {:error, inspect(error)}

          {:error, _} ->
            {:error, "Failed to parse response"}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %HTTPoison.Error{reason: reason}}
    end
  end

  def set_tx_fee(auth, fee) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "boxwallet",
        method: "settxfee",
        params: [fee]
      })

    url = "http://127.0.0.1:#{auth.rpc_port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to SetTxFee to #{fee}")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => nil}} ->
            :ok

          {:ok, %{"error" => %{"message" => message}}} ->
            Logger.error("[#{@coin_name_abbrev}] settxfee failed: #{message}")
            {:error, message}

          {:ok, %{"error" => error}} ->
            Logger.error("[#{@coin_name_abbrev}] settxfee failed: #{inspect(error)}")
            {:error, inspect(error)}

          {:error, _} ->
            {:error, "Failed to parse response"}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %HTTPoison.Error{reason: reason}}
    end
  end

  def staking(auth, enable) do
    body =
      Jason.encode!(%{
        jsonrpc: "1.0",
        id: "curltext",
        method: "staking",
        params: [enable]
      })

    url = "http://127.0.0.1:#{auth.rpc_port}"

    headers = [
      {"Content-Type", "text/plain"},
      {"Authorization", "Basic #{Base.encode64("#{auth.rpc_user}:#{auth.rpc_password}")}"}
    ]

    Logger.info("[#{@coin_name_abbrev}] Attempting to set global staking to #{enable}")

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => nil}} ->
            :ok

          {:ok, %{"error" => %{"message" => message}}} ->
            Logger.error("[#{@coin_name_abbrev}] staking failed: #{message}")
            {:error, message}

          {:ok, %{"error" => error}} ->
            Logger.error("[#{@coin_name_abbrev}] staking failed: #{inspect(error)}")
            {:error, inspect(error)}

          {:error, _} ->
            {:error, "Failed to parse response"}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %HTTPoison.Error{reason: reason}}
    end
  end

  # def get_sync_info do
  #   try do
  #     headers = [
  #       {"Authorization",
  #        "Basic " <>
  #          Base.encode64("#{@rpc_credentials[:username]}:#{@rpc_credentials[:password]}")}
  #     ]

  #     body = Jason.encode!(%{"jsonrpc" => "2.0", "method" => "getblockchaininfo", "id" => 1})
  #     {:ok, response} = HTTPoison.post(@rpc_url, body, headers)
  #     %{"result" => %{"blocks" => blocks, "headers" => headers}} = Jason.decode!(response.body)
  #     %{blocks: blocks, headers: headers, progress: trunc(blocks / max(headers, 1) * 100)}
  #   rescue
  #     _ -> %{blocks: 0, headers: 0, progress: 0}
  #   end
  # end
end
