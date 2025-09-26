# lib/my_app/coins/divi.ex
defmodule Boxwallet.Coins.Divi do
  require Logger
  @behaviour BoxWallet.CoinDaemon
  import BoxWallet.App

  @coin_name "DIVI"
  @coin_name_abbrev "DIVI"

  @home_dir ".divi"
  @home_dir_win "DIVI"

  @core_version "3.0.0"
  @download_file_arm32 "divi-" <> @core_version <> "-RPi2-9e2f76c.tar.gz"
  @download_file_linux "divi-" <> @core_version <> "-x86_64-linux-gnu-9e2f76c.tar.gz"
  @download_file_mac64 "divi-" <> @core_version <> "-osx64-9e2f76c.tar.gz"
  @download_file_windows "divi-" <> @core_version <> "-win64-9e2f76c.zip"
  # @download_file_bs "primer.zip"

  # <> "/"
  @extracted_dir_linux "divi-" <> @core_version
  # <> "\\"
  @extracted_dir_windows "divi-" <> @core_version

  @download_url "https://github.com/DiviProject/Divi/releases/download/v" <> @core_version <> "/"
  # @download_url_bs "https://divi-primer-snapshot.s3.us-east-2.amazonaws.com/snapshot/"

  @conf_file "divi.conf"
  @cli_file_lin "divi-cli"
  @cli_file_win "divi-cli.exe"
  @daemon_file_lin "divid"
  @daemon_file_win "divid.exe"

  # divi.conf file constants
  @rpc_user "divirpc"
  @rpc_port "51473"

  @tip_address "DM5XJbB6kpyDXpbnYcb1ZidrNpubf2gmSN"

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
  # cCommandDumpHDInfo string = "dumphdinfo" // ./divi-cli dumphdinfo

  # @install_path Path.expand("~/.my_app/bitcoin")
  # @rpc_credentials [username: "rpcuser", password: "rpcpass"]

  defp copy_extracted_files() do
    cli_filename =
      case get_cli_filename() do
        {:ok, name} ->
          name

        {:error, reason} ->
          Logger.error("Error: #{reason}")
          ""
      end

    daemon_filename =
      case get_daemon_filename() do
        {:ok, name} ->
          name

        {:error, reason} ->
          Logger.error("Error: #{reason}")
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

    Logger.info("Copying from #{full_path_cli} to #{dest_path_cli}")
    File.cp!(full_path_cli, dest_path_cli)
    Logger.info("Copying from #{full_path_daemon} to #{dest_path_daemon}")
    File.cp!(full_path_daemon, dest_path_daemon)

    File.chmod!(dest_path_cli, 0o755)
    File.chmod!(dest_path_daemon, 0o755)

    Logger.info("Files copied and permissions set successfully.")
  end

  def download_coin() do
    app_home_dir = BoxWallet.App.home_folder()
    # File.mkdir_p!(app_home_dir)
    IO.puts("#{BoxWallet.App.name()} is downloading to: #{app_home_dir}")
    IO.puts("System detected as: #{:erlang.system_info(:system_architecture)}")
    sys_info = to_string(:erlang.system_info(:system_architecture))

    # The result will contain, :ok, the download_to and download_from

    file_name =
      case get_download_filename() do
        {:ok, name} ->
          name

        {:error, reason} ->
          Logger.error("Error: #{reason}")
          # Keep empty string or use some default
          ""
      end

    full_file_dl_url = @download_url <> file_name

    full_file_path = Path.join(app_home_dir, file_name)
    Logger.info("Downloading file to: #{full_file_path}")

    case Req.get(full_file_dl_url, into: File.stream!(full_file_path)) do
      {:ok, %Req.Response{status: 200}} ->
        IO.puts("Download complete, now extracting...")

        case BoxWallet.Coins.CoinHelper.unarchive(full_file_path, app_home_dir) do
          :ok ->
            Logger.info("Extraction completed successfully")
            copy_extracted_files()
            tidy_downloaded_files(full_file_path)
            {:ok}

          {:error, reason} ->
            Logger.error("Extraction failed: #{inspect(reason)}")
            {:error, "Extraction failed: #{reason}"}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP error: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp files_exist do
    daemon_file = get_daemon_filename()
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
      String.contains?(sys_info, "x86_64") or String.contains?(sys_info, "arm71") ->
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
      String.contains?(sys_info, "x86_64") or String.contains?(sys_info, "arm71") ->
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
              {:error, "arm64 is not currently supported for: #{@coin_name}"}

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

  defp tidy_downloaded_files(downloaded_file) do
    File.rm_rf!(Path.join(BoxWallet.App.home_folder(), @extracted_dir_linux))
    Logger.info("Removing file: #{downloaded_file}")
    File.rm_rf!(downloaded_file)
  end

  # specify the variables that need to be passed in here maybe "from" and "to" or something?
  defp unarchive_file(full_file_path, location) do
    case BoxWallet.Coins.CoinHelper.unarchive(full_file_path, location) do
      :ok ->
        # IO.inspect(result, label: "result")
        IO.puts("Download and extraction completed successfully")
        {:ok}

      {:error, reason} ->
        IO.puts("Extraction failed: #{inspect(reason)}")
        {:error, "Extraction failed: #{reason}"}
    end
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

  # def start_daemon do
  #   cmd =
  #     if :os.type() in [{:win32, _} | _],
  #       do: ["start", "/B", @daemon_bin, "-daemon"],
  #       else: [@daemon_bin, "-daemon"]

  #   System.cmd(List.first(cmd), tl(cmd), stderr_to_stdout: true)
  #   :ok
  # end

  # def stop_daemon do
  #   if :os.type() in [{:win32, _} | _] do
  #     System.cmd(@daemon_bin, ["stop"], stderr_to_stdout: true)
  #     System.cmd("taskkill", ["/IM", "bitcoind.exe", "/F"], stderr_to_stdout: true)
  #   else
  #     System.cmd(@daemon_bin, ["stop"], stderr_to_stdout: true)
  #   end

  #   :ok
  # end

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

  def get_sync_info do
    try do
      headers = [
        {"Authorization",
         "Basic " <>
           Base.encode64("#{@rpc_credentials[:username]}:#{@rpc_credentials[:password]}")}
      ]

      body = Jason.encode!(%{"jsonrpc" => "2.0", "method" => "getblockchaininfo", "id" => 1})
      {:ok, response} = HTTPoison.post(@rpc_url, body, headers)
      %{"result" => %{"blocks" => blocks, "headers" => headers}} = Jason.decode!(response.body)
      %{blocks: blocks, headers: headers, progress: trunc(blocks / max(headers, 1) * 100)}
    rescue
      _ -> %{blocks: 0, headers: 0, progress: 0}
    end
  end
end
