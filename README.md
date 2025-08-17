# What is BoxWallet 2?

BoxWallet 2 is a browser based,  multi-coin wallet, that can get your coin-of-choice up and running fast and securely staking with just a few clicks.

# Getting started with BoxWallet 2

As there are no current releases of BoxWallet 2, the best way of getting started is to clone this repository (`git clone`), install Elixir and Erlang (which is the platform that BoxWallet runs on) and then run it. Don't worry if none of that makes sense, we'll go through everything, step-by-step below.

## Installing `git`

Installing `git` gives you the ability to clone this repository (`git clone`) and then quickly get any updates (`git pull`) with the minimum of fuss.

If you're on Linux you can install `git` with your package manager, however, if you're on Windows, please head over to:

[`https://git-scm.com`](https://git-scm.com) and download and install `git`

With `git` now installed, you can change into the directory where you'd like to install (clone) BoxWallet and type:

`git clone https://github.com/richardltc/boxwallet2.git`

You should now have a directory full of files.

## Installing `Elixir` and `Erlang`
Before we're able to run BoxWallet we need to install `Elixir` and `Erlang` as that is the platform that BoxWallet runs on.

To install `Elixir` and `Erlang` head over to [`https://elixir-lang.org/install.html`](https://elixir-lang.org/install) and follow the instructions there.

With `Elixir` and `Erlang` now installed, the last step we need to do before running BoxWallet is to install some dependencies that
it requires. Don't worry, as this is a simple process. Open a command prompt in your BoxWallet directory and
run either `mix deps.get`

After this step is complete, you're now ready to run BoxWallet. In the same directory, simply run `mix phx.server` and open your browser to `http://localhost:4000/light`

Congratulations, and thank you for using BoxWallet
