defmodule BoxWallet.Settings do
  @moduledoc """
  Manages app-level settings persisted as JSON in the BoxWallet home directory.
  """

  @default_settings %{hide_balance: false}

  def default_settings, do: @default_settings

  def settings_path do
    Path.join(BoxWallet.App.home_folder(), "settings.json")
  end

  def load do
    case File.read(settings_path()) do
      {:ok, contents} ->
        case Jason.decode(contents, keys: :atoms) do
          {:ok, settings} when is_map(settings) ->
            {:ok, Map.merge(@default_settings, settings)}

          _ ->
            {:ok, @default_settings}
        end

      {:error, _} ->
        {:ok, @default_settings}
    end
  end

  def get(key) when is_atom(key) do
    {:ok, settings} = load()
    Map.get(settings, key, Map.get(@default_settings, key))
  end

  def set(key, value) when is_atom(key) do
    {:ok, settings} = load()
    updated = Map.put(settings, key, value)
    save(updated)
  end

  def save(settings) when is_map(settings) do
    json = Jason.encode!(settings, pretty: true)
    File.write(settings_path(), json)
  end
end
