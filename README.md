# What is BoxWallet 2?

BoxWallet 2 is a browser based,  multi-coin wallet, that can get your coin-of-choice up and running fast and securely staking with just a few clicks.

# Getting started with BoxWallet 2

As there are no current releases of BoxWallet 2, the best way of getting started is to clone this repository (`git clone`), install Elixir and Erlang (which is the platform that BoxWallet runs on) and then run it. Don't worry if none of that makes sense, we'll go through everything, step-by-step below.

## Installing on Ubuntu 24.04

`sudo apt update && sudo apt install git inotify-tools automake autoconf libssl-dev libncurses-dev`

Now, we need to install a tool called `mise` which which handle Erlang and Elixir for us, so copy and paste and run these lines one after the other:
`curl https://mise.run | sh`
`echo "eval \"\$(/home/richard/.local/bin/mise activate bash)\"" >> ~/.bashrc`

Now, re-start you shell and let's check we're OK so far and run `mise docter` which should report No problems found
`mise use erlang@26.2.5.15` this could take some time...
`mise use elixir@1.15.8-otp-26`

That's should now be all of the dependencies that BoxWallet2 requires.

Now, change to a directory that you'd like to install BoxWallet, then run:
`git clone https://github.com/richardltc/boxwallet2.git`
Then, change into the directory:
`cd boxwallet2`

With `Elixir` and `Erlang` now installed, the last step we need to do before running BoxWallet is to install some dependencies that it requires. Don't worry, as this is a simple process. Open a command prompt in your BoxWallet directory and
run either `mix deps.get`

After this step is complete, you're now ready to run BoxWallet. In the same directory, simply run `mix phx.server` and open your browser to `http://localhost:4000`

Congratulations, and thank you for using BoxWallet :)
