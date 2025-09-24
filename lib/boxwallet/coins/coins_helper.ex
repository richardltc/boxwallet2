defmodule BoxWallet.Coins.CoinHelper do
  require Logger

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
