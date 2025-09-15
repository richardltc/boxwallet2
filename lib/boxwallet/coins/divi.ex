# lib/my_app/coins/divi.ex
defmodule Boxwallet.Coins.Divi do
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

  @extracted_dir_linux "divi-" <> @core_version <> "/"
  @extracted_dir_windows "divi-" <> @core_version <> "\\"

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

  @install_path Path.expand("~/.my_app/bitcoin")
  @rpc_credentials [username: "rpcuser", password: "rpcpass"]

  def download_coin(location) do
    File.mkdir_p(location)
    IO.puts("#{BoxWallet.App.name()} is downloading to: #{location}")
    IO.puts("System detected as: #{:erlang.system_info(:system_architecture)}")
    sys_info = to_string(:erlang.system_info(:system_architecture))

    # The result will contain, :ok, the download_to and download_from
    download_url = get_download_url(location)

    full_file_dl_url =
      full_file_path = BoxWallet.App.home_folder() <> get_filename()

    case Req.get(full_file_dl_url, into: File.stream!(full_file_path)) do
      {:ok, %Req.Response{status: 200}} ->
        IO.puts("Download complete, now extracting...")

        case BoxWallet.Coins.CoinHelper.unarchive(full_file_path, location) do
          :ok ->
            IO.inspect(result, label: "result")
            IO.puts("Download and extraction completed successfully")
            {:ok, %{download_result: {full_file_path, full_file_dl_url}}}

          {:ok, extract_result} ->
            IO.puts("Download and extraction completed successfully")
            IO.inspect(extract_result, label: "Extract result")
            {:ok, %{download_result: {full_file_path, full_file_dl_url}}}

          {:error, reason} ->
            IO.puts("Extraction failed: #{inspect(reason)}")
            {:error, "Extraction failed: #{reason}"}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP error: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_download_url(location) do
    sys_info = to_string(:erlang.system_info(:system_architecture))

    # Determine the file path and URL based on OS and architecture
    result =
      case :os.type() do
        {:unix, :linux} ->
          cond do
            String.contains?(sys_info, "arm71") ->
              IO.puts("arm71 detected")

              {:ok, @download_url <> @download_file_arm32}

            String.contains?(sys_info, "aarch64") ->
              IO.puts("aarch64 detected")
              {:error, "arm64 is not currently supported for: #{@coin_name}"}

            String.contains?(sys_info, "i386") ->
              IO.puts("i386 detected")
              {:error, "linux 386 is not currently supported for: #{@coin_name}"}

            String.contains?(sys_info, "x86_64") ->
              IO.puts("x86_64 detected")

              {:ok, @download_url <> @download_file_linux}

            true ->
              IO.puts("Unsupported system: #{:erlang.system_info(:system_architecture)}")
              {:error, "Unsupported Linux architecture: #{sys_info}"}
          end

        {:unix, :darwin} ->
          cond do
            String.contains?(sys_info, "aarch64") ->
              {:ok, @download_url <> @download_file_mac64}

            String.contains?(sys_info, "i386") ->
              IO.puts("i386 detected")
              {:error, "mac 386 is not currently supported for: #{@coin_name}"}

            String.contains?(sys_info, "x86_64") ->
              IO.puts("x86_64 detected")

              {:ok, @download_url <> @download_file_mac64}

            true ->
              IO.puts("Unsupported system: #{:erlang.system_info(:system_architecture)}")
              {:error, "Unsupported macOS architecture: #{sys_info}"}
          end

        # Covers Windows
        {:win32, :nt} ->
          {:ok, @download_url <> @download_file_windows}

        _ ->
          {:error, "Unsupported operating system"}
      end
  end

  defp get_filename() do
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
