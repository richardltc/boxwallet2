<script lang="ts">
    import { IconStatusType } from '$lib/bwtypes';
    import { walletUnlockedUntil, walletConnections } from '$lib/rdd_getinfo_store';

    export let block_height: number;
    export let core_files_downloaded = false;
    export let is_ready = false
    export let is_working: boolean

    let icon_wallet_security_class = ""
    let icon_wallet_security_title = ""
    export let wallet_verification_progress: number;
    export let wallet_offline = true
    let icon_is_ready_class = ""
    let icon_is_ready_title = ""
    let icon_wallet_connections_class = ""
    let icon_wallet_connections_title = ""
    let icon_is_staking_class = ""
    let icon_is_staking_title = ""
    let icon_is_syncing_class = ""
    let icon_is_syncing_title = ""
    let icon_is_working_class = ""
    let icon_is_working_title = ""
    let icon_core_files_downloaded_class = ""
    let icon_core_files_downloaded_title = ""

    let wallet_connections_value: number;
    const unsub_wallet_connections = walletConnections.subscribe((value) => {
        wallet_connections_value = value

        if (wallet_connections_value > 0) {
            icon_wallet_connections_title = `${wallet_connections_value} connections`
            icon_wallet_connections_class = "fa-solid fa-network-wired fa-2x"
        } else {
            icon_wallet_connections_title = "Not connected"
            icon_wallet_connections_class = "fa-solid fa-network-wired fa-2x disabled-icon"
        }

    })

    let unlocked_until_value: number;
    const unsubscribe =  walletUnlockedUntil.subscribe((value) => {
        unlocked_until_value = value

        if (unlocked_until_value === -5) {
            icon_wallet_security_class = "fa-solid fa-lock-open fa-2x disabled-icon"
            icon_wallet_security_title = "Offline"
            console.log("wallet status unlocked")
        } else if (unlocked_until_value === 0) {
            icon_wallet_security_class = "fa-solid fa-lock fa-2x"
            icon_wallet_security_title = "Wallet locked"
            console.log("wallet status locked")
        } else if (unlocked_until_value === -1) {
            icon_wallet_security_class = "fa-solid fa-lock-open fa-2x"
            icon_wallet_security_title = "Wallet unlocked"
            console.log("wallet status unlocked")
        } else if (unlocked_until_value > 0) {
            icon_wallet_security_class = "fa-solid fa-lock fa-2x"
            icon_wallet_security_title = "Wallet unlocked for staking."
            console.log("wallet status unlocked for staking")
        }
        });

    // function convertBCVerification(verificationPG: number): string {
    //     let sProg: string;
    //     let fProg: number;
    //
    //     fProg = verificationPG * 100;
    //     sProg = fProg.toFixed(2);
    //
    //     if (sProg === "100.00") {
    //         sProg = "99.99";
    //     }
    //
    //     return `${sProg}%`;
    // }

    $: {
        if (wallet_offline) {
            icon_is_ready_class = "fa-solid fa-face-smile fa-2x disabled-icon"
            icon_is_ready_title = "Offline"
            icon_is_staking_class = "fa-solid fa-microchip fa-2x fa-spin-stop disabled-icon"
            icon_is_staking_title = "Offline"
            icon_is_syncing_class = "fa-solid fa-rotate fa-2x fa-spin-stop disabled-icon"
            icon_is_syncing_title = "Offline"
            // icon_wallet_connections_title = "Offline"
            // icon_wallet_connections_class = "fa-solid fa-network-wired fa-2x disabled-icon"
            // icon_wallet_security_class = "fa-solid fa-lock-open fa-2x disabled-icon"
            // icon_wallet_security_title = "Offline"
        } else {
            if (is_ready) {
                icon_is_ready_class = "fa-solid fa-face-smile fa-2x"
                icon_is_ready_title = "Core wallet is ready."
            } else {
                icon_is_ready_class = "fa-solid fa-face-smile fa-2x disabled-icon"
                icon_is_ready_title = "Core wallet is not ready."
            }
            if ((wallet_verification_progress < 0.99999) && (wallet_connections_value > 0)) {
                console.log(`verification progress = ${wallet_verification_progress}`)
                icon_is_syncing_class = "fa-solid fa-rotate fa-2x fa-spin"
                icon_is_syncing_title = `Blockchain is syncing... Blocks: ${block_height}`
            } else if (wallet_connections_value > 0) {
                icon_is_syncing_class = "fa-solid fa-rotate fa-2x fa-spin-stop"
                icon_is_syncing_title = `Blockchain is synced. Blocks: ${block_height}`
            }
        }

        if (is_working) {
            icon_is_working_class = "fa-solid fa-cog fa-spin fa-2x";
            icon_is_working_title = "Working..."
        } else {
            icon_is_working_class = "fa-solid fa-cog fa-2x fa-spin-stop"
            icon_is_working_title = "Idle"
        }
        if (core_files_downloaded) {
            icon_core_files_downloaded_class = "fa-solid fa-download fa-2x";
            icon_core_files_downloaded_title = "Core files have been downloaded"
        } else {
            icon_core_files_downloaded_class = "fa-solid fa-download fa-2x disabled-icon"
            icon_core_files_downloaded_title = "Core files need to be downloaded"
        }
    }

</script>

<main>
    <div class="wrapper">
        <div class="flex-item"><span title={icon_is_working_title}><i class={icon_is_working_class}></i></span></div>
        <div class="flex-item"><span title={icon_core_files_downloaded_title}><i class={icon_core_files_downloaded_class}></i></span></div>
        <div class="flex-item"><span title={icon_is_ready_title}><i class={icon_is_ready_class}></i></span></div>
        <div class="flex-item"><span title={icon_wallet_connections_title}><i class={icon_wallet_connections_class} ></i></span></div>
        <div class="flex-item"><span title={icon_is_syncing_title}><i class={icon_is_syncing_class}></i></span></div>
        <div class="flex-item"><span title={icon_wallet_security_title}><i class={icon_wallet_security_class}></i></span></div>
        <div class="flex-item"><span title={icon_is_staking_title}><i class={icon_is_staking_class}></i></span></div>
    </div>
</main>

<style>
    .disabled-icon {
        pointer-events: none;
        color: #999; /* You can adjust the color to make it visually disabled */
        opacity: 0.5; /* You can adjust the opacity as well */
    }

    i {
        padding-right: 0px;
    }

    .wrapper {
        display: flex;
    }

    .flex-item {
        margin: 0 15px 0 0;
    }
</style>