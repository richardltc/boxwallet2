# What is BoxWallet?

BoxWallet is a browser based,  multi-coin wallet, that can get your coin-of-choice up and running fast and securely staking with just a few clicks.

# Getting started with BoxWallet

The best way of getting started with BoxWallet is to clone this repository (`git clone`), install it's dependencies via `npm install` and then run it via `npm run dev`. Don't worry if none of that makes sense, we'll go through everything, step-by-step below.

## Installing `git`

Installing `git` gives you the ability to clone this repository (`git clone`) and then quickly get any updates (`git pull`) with the minimum of fuss.

If you're on Linux you can install `git` with your package manager, however, if you're on Windows, please head over to:

[`https://git-scm.com`](https://git-scm.com) and download and install `git`

With `git` now installed, you can change into the directory where you'd like to install (clone) BoxWallet and type:

`git clone https://github.com/richardltc/boxwallet2.git`

You should now have a directory full of files.

## Installing `NodeJS` or `bun`
Before we're able to run BoxWallet we need to install `NodeJS` or `bun` as that will be the engine that BoxWallet uses in order to run.

To install `bun` head over to [`https://bun.sh/`](https://bun.sh/) and follow the really simple instructions on how to install it.

If you're running on Linux you'll be able to install `NodeJS` from your package manager (`sudo apt install nodejs`), on Windows, you can go to:
 [`www.nodejs.org`](https://www.nodejs.org).

With `bun` or `NodeJS` now installed, the last step we need to do before running BoxWallet is to install some dependencies that 
it requires. Don't worry, as this is a simple process. Open a command prompt in your BoxWallet directory and 
run either `bun install` or `npm install`

One final step is to tell BoxWallet what it's server IP address is.  To do this, you need to create a file called `.env`
in the same directory as this `README.md` file. Then, if your doing all of this on a single machine, that is, you're 
going to be running your browser on the same machine that's you're also running the server on, you need to add 
exactly `PUBLIC_HOST_IP=localhost` into the `.env`, otherwise, if the server is running on a different machine than
your browser is running, you need to enter that IP address as `PUBLIC_HOST_IP=your_server_ip` so, if the IP address of
your server was 192.168.1.1 you'd enter `PUBLIC_HOST_IP=192.168.1.1`

After this step is complete, you're now ready to run BoxWallet

If you want to run BoxWallet locally on the machine you've just installed it on type the command: `npm run dev --open`

This should now automatically open your browser and run BoxWallet

If you want to run BoxWallet and access it from another machine on your local network run the command: `npm run host`

Congratulations, and thank you for using BoxWallet
