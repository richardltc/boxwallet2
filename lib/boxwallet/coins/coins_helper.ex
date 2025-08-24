defmodule BoxWallet.Coins.CoinHelper do
  def unarchive(full_file_path, location) do
    # Ensure destination directory exists
    case File.mkdir_p(location) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create directory #{location}: #{reason}"}
    end

    # Check if source file exists
    unless File.exists?(full_file_path) do
      {:error, "Source file does not exist: #{full_file_path}"}
    else
      IO.puts("Source file exists: #{full_file_path}")

      case :os.type() do
        {:unix, :linux} ->
          IO.puts("Linux detected")

          cond do
            String.contains?(full_file_path, ".tar.gz") ->
              IO.puts("Extracting #{full_file_path} to #{location}")

              result =
                :erl_tar.extract(
                  to_charlist(full_file_path),
                  [:compressed, {:cwd, to_charlist(location)}]
                  # [:compressed, :verbose, {:cwd, to_charlist(location)}]
                )

              IO.inspect(result, label: "Extract result")

              case result do
                :ok ->
                  IO.puts("Successfully extracted files")
                  :ok

                {:error, reason} ->
                  {:error, "Failed to extract tar.gz: #{inspect(reason)}"}
              end

            true ->
              {:error, "Unsupported file format for Linux: #{full_file_path}"}
          end

        # For Mac...
        {:unix, :darwin} ->
          IO.puts("Mac detected")

          cond do
            String.contains?(full_file_path, ".tar.gz") ->
              IO.puts("Extracting #{full_file_path} to #{location}")

              result =
                :erl_tar.extract(
                  to_charlist(full_file_path),
                  [:compressed, {:cwd, to_charlist(location)}]
                  # [:compressed, :verbose, {:cwd, to_charlist(location)}]
                )

              IO.inspect(result, label: "Extract result")

              case result do
                :ok ->
                  IO.puts("Successfully extracted files")
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
                {:ok, file_list} ->
                  IO.puts("Successfully extracted #{length(file_list)} files")
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
