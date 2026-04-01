defmodule BoxWallet.Coins.CoinHelper do
  require Logger

  @doc """
  Returns the total and free disk space in bytes for the primary disk.
  Checks C:\\ on Windows or /home (falling back to /) on Linux/macOS.
  Returns {:ok, %{total: mb, free: mb}} or {:error, reason}.
  """
  def disk_free do
    case :os.type() do
      {:unix, os_name} ->
        path =
          case os_name do
            :darwin -> "/"
            _ -> if File.exists?("/home"), do: "/home", else: "/"
          end

        case System.cmd("df", ["-Pk", path]) do
          {output, 0} -> parse_df_output(output)
          {_, code} -> {:error, "df failed with exit code #{code}"}
        end

      {:win32, :nt} ->
        case System.cmd("powershell", [
               "-NoProfile",
               "-Command",
               "Get-CimInstance -ClassName Win32_LogicalDisk -Filter \"DeviceID='C:'\" | Select-Object Size,FreeSpace | ForEach-Object { \"Size=$($_.Size)\"; \"FreeSpace=$($_.FreeSpace)\" }"
             ]) do
          {output, 0} -> parse_wmic_output(output)
          {_, code} -> {:error, "powershell disk query failed with exit code #{code}"}
        end

      _ ->
        {:error, "Unsupported operating system"}
    end
  end

  defp parse_df_output(output) do
    case String.split(output, "\n", trim: true) do
      [_header | [data | _]] ->
        case String.split(data, ~r/\s+/, trim: true) do
          [_fs, total_kb, _used, free_kb | _] ->
            {:ok, %{total: div(String.to_integer(total_kb), 1024), free: div(String.to_integer(free_kb), 1024)}}

          _ ->
            {:error, "Unexpected df output columns"}
        end

      _ ->
        {:error, "Unexpected df output format"}
    end
  end

  defp parse_wmic_output(output) do
    lines = String.split(output, "\n", trim: true)

    free =
      Enum.find_value(lines, fn line ->
        case String.split(String.trim(line), "=") do
          ["FreeSpace", val] -> String.to_integer(String.trim(val))
          _ -> nil
        end
      end)

    total =
      Enum.find_value(lines, fn line ->
        case String.split(String.trim(line), "=") do
          ["Size", val] -> String.to_integer(String.trim(val))
          _ -> nil
        end
      end)

    if free && total do
      {:ok, %{total: div(total, 1024 * 1024), free: div(free, 1024 * 1024)}}
    else
      {:error, "Failed to parse wmic output"}
    end
  end

  def create_conf_file_if_not_exists(filepath) do
    if File.exists?(filepath) do
      {:ok, "File already exists: #{filepath}"}
    else
      case File.write(filepath, "") do
        :ok -> {:ok, "File created: #{filepath}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def unarchive(full_file_path, location) do
    # Check if source file exists
    unless File.exists?(full_file_path) do
      {:error, "Source file does not exist: #{full_file_path}"}
    else
      IO.puts("Source file exists: #{full_file_path}")

      case :os.type() do
        {:unix, :linux} ->
          cond do
            String.contains?(full_file_path, ".tar.gz") ->
              Logger.info("Extracting #{full_file_path} to #{location}")

              result =
                :erl_tar.extract(
                  to_charlist(full_file_path),
                  [:compressed, {:cwd, to_charlist(location)}]
                )

              case result do
                :ok ->
                  Logger.info("Successfully extracted files")
                  :ok

                {:error, reason} ->
                  {:error, "Failed to extract tar.gz: #{inspect(reason)}"}
              end

            true ->
              {:error, "Unsupported file format for Linux: #{full_file_path}"}
          end

        # For Mac...
        {:unix, :darwin} ->
          cond do
            String.contains?(full_file_path, ".tar.gz") ->
              Logger.info("Extracting #{full_file_path} to #{location}")

              result =
                :erl_tar.extract(
                  to_charlist(full_file_path),
                  [:compressed, {:cwd, to_charlist(location)}]
                )

              case result do
                :ok ->
                  Logger.info("Successfully extracted files")
                  :ok

                {:error, reason} ->
                  {:error, "Failed to extract tar.gz: #{inspect(reason)}"}
              end

            true ->
              {:error, "Unsupported file format for Linux: #{full_file_path}"}
          end

        {:win32, :nt} ->
          case Path.extname(full_file_path) do
            ".zip" ->
              case :zip.unzip(to_charlist(full_file_path), [{:cwd, to_charlist(location)}]) do
                {:ok, _} ->
                  IO.puts("Successfully extracted files")
                  :ok

                {:error, reason} ->
                  {:error, "Failed to extract zip: #{inspect(reason)}"}
              end

            _ ->
              {:error, "Unsupported file format for Windows: #{full_file_path}"}
          end

        _ ->
          {:error, "Unsupported operating system for unarchiving"}
      end
    end
  end
end
