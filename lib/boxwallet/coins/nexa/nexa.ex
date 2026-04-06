defmodule Boxwallet.Coins.Nexa do
  require Logger

  @coin_name "Nexa"
  @coin_name_abbrev "NEXA"
  def coin_name_abbrev, do: @coin_name_abbrev

  @home_dir_lin ".nexa"
  @home_dir_mac "Nexa"
  @home_dir_win "NEXA"

  @core_version "2.1.0.0"
  def core_version, do: @core_version
  @download_file_arm64 "nexa-" <> @core_version <> "-arm64.tar.gz"
  @download_file_linux "nexa-" <> @core_version <> "-linux64.tar.gz"
  @download_file_mac_arm64 "nexa-" <> @core_version <> "-macos-arm64.tar.gz"
  @download_file_mac_x86 "nexa-" <> @core_version <> "-macos-x86.tar.gz"
  @download_file_windows "nexa-" <> @core_version <> "-win64.zip"

  @extracted_dir_linux "nexa-" <> @core_version
  @extracted_dir_windows "nexa-" <> @core_version

  # https://www.bitcoinunlimited.info/nexa/2.1.0.0/nexa-2.1.0.0-linux64.tar.gz
  @download_url "https://www.bitcoinunlimited.info/nexa/" <> @core_version <> "/"

  @conf_file "nexa.conf"
  @cli_file_lin "nexa-cli"
  @cli_file_win "nexa-cli.exe"
  @daemon_file_lin "nexad"
  @daemon_file_win "nexad.exe"

  # nexa.conf file constants
  @rpc_user "nexarpc"
  @rpc_port "7227"

  @daemon_stop_attempts 25
  @daemon_rpc_attempts 25
  @daemon_rpc_sleep_interval 1000

  defp copy_extracted_files() do
    cli_filename =
      case get_cli_filename() do
        {:ok, name} -> name
        {:error, reason} ->
          Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
          ""
      end

    daemon_filename =
      case get_daemon_filename() do
        {:ok, name} -> name
        {:error, reason} ->
          Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
          ""
      end

    extracted_dir =
      case :os.type() do
        {:win32, _} -> @extracted_dir_windows
        _ -> @extracted_dir_linux
      end

    full_path_cli =
      Path.join([BoxWallet.App.home_folder(), extracted_dir, "bin", cli_filename])

    full_path_daemon =
      Path.join([BoxWallet.App.home_folder(), extracted_dir, "bin", daemon_filename])

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
      {:ok, %{body: _response_body}} ->
        true

      {:error, %HTTPoison.Error{reason: _reason}} ->
        false
    end
  end

  def download_coin() do
    app_home_dir = BoxWallet.App.home_folder()
    IO.puts("#{BoxWallet.App.name()} is downloading to: #{app_home_dir}")
    IO.puts("System detected as: #{:erlang.system_info(:system_architecture)}")

    file_name =
      case get_download_filename() do
        {:ok, name} -> name
        {:error, reason} ->
          Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
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
        {:ok, name} -> name
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

      {:ok, auth}
    else
      {:error, reason} -> {:error, reason}
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

  defp do_get_cli_filename({:win32, :nt}, _sys_info) do
    {:ok, @cli_file_win}
  end

  defp do_get_cli_filename({:unix, :linux}, sys_info) do
    cond do
      String.contains?(sys_info, "x86_64") or String.contains?(sys_info, "aarch64") ->
        {:ok, @cli_file_lin}

      true ->
        {:error, "Unsupported Linux architecture: #{sys_info}"}
    end
  end

  defp do_get_cli_filename({:unix, :darwin}, sys_info) do
    cond do
      String.contains?(sys_info, "aarch64") or String.contains?(sys_info, "x86_64") ->
        {:ok, @cli_file_lin}

      true ->
        {:error, "Unsupported macOS architecture: #{sys_info}"}
    end
  end

  def get_daemon_filename() do
    do_get_daemon_filename(:os.type(), to_string(:erlang.system_info(:system_architecture)))
  end

  defp do_get_daemon_filename({:win32, :nt}, _sys_info) do
    {:ok, @daemon_file_win}
  end

  defp do_get_daemon_filename({:unix, :linux}, sys_info) do
    cond do
      String.contains?(sys_info, "x86_64") or String.contains?(sys_info, "aarch64") ->
        {:ok, @daemon_file_lin}

      true ->
        {:error, "Unsupported Linux architecture: #{sys_info}"}
    end
  end

  defp do_get_daemon_filename({:unix, :darwin}, sys_info) do
    cond do
      String.contains?(sys_info, "aarch64") or String.contains?(sys_info, "x86_64") ->
        {:ok, @daemon_file_lin}

      true ->
        {:error, "Unsupported macOS architecture: #{sys_info}"}
    end
  end

  defp get_download_filename() do
    sys_info = to_string(:erlang.system_info(:system_architecture))

    case :os.type() do
      {:unix, :linux} ->
        cond do
          String.contains?(sys_info, "aarch64") ->
            {:ok, @download_file_arm64}

          String.contains?(sys_info, "i386") ->
            {:error, "linux 386 is not currently supported for: #{@coin_name}"}

          String.contains?(sys_info, "x86_64") ->
            {:ok, @download_file_linux}

          true ->
            {:error, "Unsupported Linux architecture: #{sys_info}"}
        end

      {:unix, :darwin} ->
        cond do
          String.contains?(sys_info, "aarch64") ->
            {:ok, @download_file_mac_arm64}

          String.contains?(sys_info, "x86_64") ->
            {:ok, @download_file_mac_x86}

          true ->
            {:error, "Unsupported macOS architecture: #{sys_info}"}
        end

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

    case HTTPoison.post(url, body, headers) do
      {:ok, %{body: response_body}} ->
        cond do
          String.contains?(response_body, "Loading") or
            String.contains?(response_body, "Rescanning") or
            String.contains?(response_body, "Verifying") ->
            Logger.info("[#{@coin_name_abbrev}] Daemon is loading")
            {:warming_up, :loading}

          true ->
            case Jason.decode(response_body) do
              {:ok, %{"result" => result}} ->
                {:ok, %{result: result}}

              {:error, reason} ->
                Logger.error(
                  "[#{@coin_name_abbrev}] Failed to parse getblockchaininfo: #{inspect(reason)}"
                )

                {:error, reason}
            end
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

    url = "http://127.0.0.1:#{auth.rpc_port}"

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
          if String.contains?(response_body, "Loading") ||
               String.contains?(response_body, "Rescanning") ||
               String.contains?(response_body, "Verifying") do
            Logger.info(
              "[#{@coin_name_abbrev}] Waiting for Daemon to be ready, attempt #{attempt}"
            )

            Process.sleep(1000)
            {:cont, {:error, :wrong_response}}
          else
            case Jason.decode(response_body) do
              {:ok, %{"result" => result}} ->
                {:halt, {:ok, %{result: result}}}

              {:error, reason} ->
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

  defp populate_conf_file() do
    File.mkdir_p!(get_coin_home_dir())
    conf_file = get_conf_file_location()
    password = BoxWallet.Coins.ConfigManager.generate_random_string(20)

    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "rpcuser", @rpc_user)
    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "rpcpassword", password)
    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "daemon", "1")
    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "server", "1")
    BoxWallet.Coins.ConfigManager.add_label_if_missing(conf_file, "rpcport", @rpc_port)
  end

  defp tidy_downloaded_files(downloaded_file) do
    extracted_dir =
      case :os.type() do
        {:win32, _} -> @extracted_dir_windows
        _ -> @extracted_dir_linux
      end

    File.rm_rf!(Path.join(BoxWallet.App.home_folder(), extracted_dir))
    Logger.info("[#{@coin_name_abbrev}] Removing file: #{downloaded_file}")
    File.rm_rf!(downloaded_file)
  end

  def start_daemon do
    daemon_filename =
      case get_daemon_filename() do
        {:ok, name} -> name
        {:error, reason} ->
          Logger.error("[#{@coin_name_abbrev}] Error: #{reason}")
          ""
      end

    full_path_daemon =
      Path.join([BoxWallet.App.home_folder(), daemon_filename])

    spawn(fn ->
      System.cmd(full_path_daemon, [])
    end)

    Process.sleep(100)
    {:ok}
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
end
