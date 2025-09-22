defmodule BoxWallet.App do
  @app_name "BoxWallet"
  @updater_app_name "bwupdater"
  @app_version "0.0.1"
  @app_filename "boxwallet"
  @app_filename_win "boxwallet.exe"
  @app_github_url "https://github.com/richardltc/boxwallet2"

  @app_working_dir_lin ".boxwallet"
  @app_working_dir_win "BoxWallet"

  def home_folder do
    user_home_dir = System.user_home()

    case :os.type() do
      {:unix, :darwin} ->
        IO.puts("Running on a Mac.")
        Path.join(user_home_dir, "Library/Application Support/" <> @app_working_dir_win)

      {:unix, :linux} ->
        IO.puts("Running on Linux.")
        Path.join(user_home_dir, @app_working_dir_lin)

      {:win32, _} ->
        IO.puts("Running on Windows.")
        Path.join([user_home_dir, "appdata","roaming",@app_working_dir_win])

      _ ->
        IO.puts("Running on an unknown OS.")
    end
  end

  def name do
    @app_name
  end

  def version do
    @app_version
  end
end
