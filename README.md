# What is BoxWallet?

BoxWallet is a browser based,  multi-coin wallet, that can get your coin-of-choice up and running, securely staking with just a few clicks.

# Getting started with BoxWallet

The best way of getting started with BoxWallet is to clone this repository (`git clone`), install it's dependencies via `npm install` and then run it via `npm run dev`. Don't worry if none of that makes sense, we'll go through everything, step-by-step below.

## Installing `git`

Installing `git` gives you the ability to clone this repository (`git clone`) and then quickly get any updates (`git pull`) with the minimum of fuss.

If you're on Linux you can install `git` with your package manager, however, if you're on Windows, please head over to:

[`https://git-scm.com`](https://git-scm.com) and download and install `git`

With `git` now installed, you can change into the directory where you'd like to install (clone) BoxWallet and type:

`git clone https://github.com/richardltc/boxwallet2.git`

You should now have a directory full of files.

## Installing `NodeJS`
Before we're able to run BoxWallet we need to install `NodeJS` as that will be the engine that BoxWallet uses in order to run.

Again, if you're running on Linux you'll be able to install `NodeJS` from your package manager, on Windows, you can go to:
 [`www.nodejs.org`](https://www.nodejs.org).

With `NodeJS` now installed, the last step we need to do before running BoxWallet2 is to install some dependencies that it requires. Don't worry, as this is a simple process. Open a command prompt in your BoxWallet2 directory and run `npm install`

After this step is complete, you're now ready to run BoxWallet

If you want to run BoxWallet locally on the machine you've just installed it on type the command: `npm run dev --open`

This should now automatically open your browser and run BoxWallet

If you want to run BoxWallet and access it from another machine on your local network run the command: `npm run host`

Congratulations, and thank you for using BoxWallet
