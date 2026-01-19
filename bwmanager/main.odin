package main

import "core:fmt"
import "core:log"
import "core:os"
import "github" // Assuming github.odin is in the same directory or a subfolder

// Simple ANSI color helpers
ANSI_GREEN :: "\x1b[32m"
ANSI_RESET :: "\x1b[0m"

// Mocking app info (In V these usually come from v.mod)
APP_NAME :: "my_app"
APP_VERSION :: "0.1.0"

main :: proc() {
	// Initialize context logger
	context.logger = log.create_console_logger()

	// Deferred end message (runs when main exits)
	defer fmt.printf(
		"%s%s%s v%s%s%s ending...\n",
		ANSI_GREEN,
		APP_NAME,
		ANSI_RESET,
		ANSI_GREEN,
		APP_VERSION,
		ANSI_RESET,
	)

	log.infof(
		"%s%s%s v%s%s%s starting...",
		ANSI_GREEN,
		APP_NAME,
		ANSI_RESET,
		ANSI_GREEN,
		APP_VERSION,
		ANSI_RESET,
	)

	owner := "vlang"
	repo := "v"

	fmt.printf("Fetching latest release for %s/%s...\n", owner, repo)

	// In Odin, we don't have a direct 'stdout.flush()' as standard fmt
	// calls are generally unbuffered or handle it, but for raw OS:
	os.flush(os.stdout)

	release, ok := github.get_latest_release(owner, repo)
	if !ok {
		// In Odin, the error was printed inside get_latest_release in the previous snippet
		return
	}
	// Important: clean up heap-allocated strings from the JSON parser
	defer github.delete_release(release)

	fmt.println("-------------------------------")
	fmt.printf("Tag Name:  %s\n", release.tag_name)
	fmt.printf("Release:   %s\n", release.name)
	fmt.printf("Published: %s\n", release.published_at)
	fmt.printf("URL:       %s\n", release.html_url)
	fmt.println("-------------------------------")
}
