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
  Generates a random alphanumeric string of the specified length.

  ## Parameters
    - length: The length of the string to generate

  ## Examples
      iex> RandomString.generate(10)
      "aB3xY7qZ9m"

      iex> RandomString.generate(5)
      "K4p2L"
  """
  def generate_random_string(length) when is_integer(length) and length > 0 do
    @alphanumeric
    |> Enum.take_random(length)
    |> List.to_string()
  end

  def generate(_), do: {:error, "Length must be a positive integer"}
end

# Usage example:
# ConfigManager.add_label_if_missing("file.txt", "rpcuser", "richard")
