defmodule BoxWallet.App do
  @app_name       "BoxWallet"
  @updater_app_name "bwupdater"
  @app_version      "0.0.1"
  @app_filename     "boxwallet"
  @app_filename_win "boxwallet.exe"

  @app_working_dir_lin ".boxwallet"
  @app_working_dir_lin  "BoxWallet"

  def name do
    @app_name
  end
end
