defmodule BoxWallet.Coins.ConfigManager do
  @moduledoc """
  Manages configuration file labels by checking for existence and adding new ones.
  """

  @alphanumeric Enum.concat([?0..?9, ?A..?Z, ?a..?z])

  @doc """
  Checks if a label exists in a file, and if not, appends it with the given value.

  ## Examples
      iex> ConfigManager.add_label_if_missing("config.txt", "rpcuser", "richard")
      {:ok, :added}

      iex> ConfigManager.add_label_if_missing("config.txt", "rpcuser", "richard")
      {:ok, :exists}
  """
  def add_label_if_missing(file_path, label, value) do
    case File.read(file_path) do
      {:ok, content} ->
        if label_exists?(content, label) do
          IO.puts("Label '#{label}' already exists in #{file_path}. Skipping.")
          {:ok, :exists}
        else
          append_label(file_path, label, value)
        end

      {:error, :enoent} ->
        # File doesn't exist, create it with the label
        IO.puts("File #{file_path} doesn't exist. Creating with label.")
        append_label(file_path, label, value)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp label_exists?(content, label) do
    # Check if the label exists at the start of any line
    content
    |> String.split("\n")
    |> Enum.any?(fn line ->
      String.trim(line) |> String.starts_with?("#{label}=")
    end)
  end

  defp append_label(file_path, label, value) do
    line = "#{label}=#{value}\n"

    case File.open(file_path, [:append]) do
      {:ok, file} ->
        IO.write(file, line)
        File.close(file)
        IO.puts("Added '#{label}=#{value}' to #{file_path}")
        {:ok, :added}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Sets a label to a specific value. If the label exists, it is updated in place.
  If it does not exist, it is appended.

  ## Examples
      iex> ConfigManager.set_label_value("config.txt", "testnet", "1")
      :ok
  """
  def set_label_value(file_path, label, value) do
    case File.read(file_path) do
      {:ok, content} ->
        if label_exists?(content, label) do
          new_content =
            content
            |> String.split("\n")
            |> Enum.map(fn line ->
              if String.trim(line) |> String.starts_with?("#{label}=") do
                "#{label}=#{value}"
              else
                line
              end
            end)
            |> Enum.join("\n")

          File.write(file_path, new_content)
        else
          append_label(file_path, label, value)
          :ok
        end

      {:error, :enoent} ->
        append_label(file_path, label, value)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_label_value(file_path, label) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.find_value(fn line ->
          case String.split(line, "=", parts: 2) do
            [^label, value] -> String.trim(value)
            _ -> nil
          end
        end)
        |> case do
          nil -> {:error, :not_found}
          value -> {:ok, value}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Enables testnet by setting `testnet=1` and adding a `[test]` section that
  duplicates the rpcport, rpcuser, and rpcpassword from the top-level config.
  This is required by newer Bitcoin-derived daemons which only apply settings
  under the matching network section.
  """
  def enable_testnet(file_path) do
    set_label_value(file_path, "testnet", "1")

    case File.read(file_path) do
      {:ok, content} ->
        # Read existing top-level values
        rpcport = extract_top_level_value(content, "rpcport")
        rpcuser = extract_top_level_value(content, "rpcuser")
        rpcpassword = extract_top_level_value(content, "rpcpassword")

        # Remove any existing [test] section first
        cleaned = remove_section(content, "test")

        # Build the [test] section
        test_lines =
          ["\n[test]"] ++
            if(rpcport, do: ["rpcport=#{rpcport}"], else: []) ++
            if(rpcuser, do: ["rpcuser=#{rpcuser}"], else: []) ++
            if(rpcpassword, do: ["rpcpassword=#{rpcpassword}"], else: [])

        new_content = String.trim_trailing(cleaned) <> "\n" <> Enum.join(test_lines, "\n") <> "\n"
        File.write(file_path, new_content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Disables testnet by setting `testnet=0` and removing the `[test]` section.
  """
  def disable_testnet(file_path) do
    set_label_value(file_path, "testnet", "0")

    case File.read(file_path) do
      {:ok, content} ->
        new_content = remove_section(content, "test")
        File.write(file_path, new_content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_top_level_value(content, label) do
    content
    |> String.split("\n")
    |> Enum.reduce_while(nil, fn line, _acc ->
      trimmed = String.trim(line)

      cond do
        # Stop if we hit any section header
        String.starts_with?(trimmed, "[") -> {:halt, nil}
        String.starts_with?(trimmed, "#{label}=") ->
          case String.split(trimmed, "=", parts: 2) do
            [_, value] -> {:halt, String.trim(value)}
            _ -> {:cont, nil}
          end
        true -> {:cont, nil}
      end
    end)
  end

  defp remove_section(content, section_name) do
    header = "[#{section_name}]"

    content
    |> String.split("\n")
    |> Enum.reduce({[], false}, fn line, {acc, in_section} ->
      trimmed = String.trim(line)

      cond do
        String.downcase(trimmed) == String.downcase(header) ->
          {acc, true}

        in_section and String.starts_with?(trimmed, "[") ->
          {[line | acc], false}

        in_section ->
          {acc, true}

        true ->
          {[line | acc], false}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  def generate_random_string(length) when is_integer(length) and length > 0 do
    @alphanumeric
    |> Enum.take_random(length)
    |> List.to_string()
  end

  def generate(_), do: {:error, "Length must be a positive integer"}
end

# Usage example:
# ConfigManager.add_label_if_missing("file.txt", "rpcuser", "richard")
