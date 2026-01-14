module main

import app
import github
import log
import os
import term

fn main() {
	log.set_level(.info)
	log.set_always_flush(true)
	// Create a mutable reference to stdout
    mut stdout := os.stdout()
	log.info('${term.green(app.name())}' + ' v${term.green(app.version())}' + ' starting...')

	// Example: Fetching the latest release for the V language itself.
		owner := 'vlang'
		repo := 'v'

		println('Fetching latest release for ${owner}/${repo}...')
		stdout.flush()

		release := github.get_latest_release(owner, repo) or {
			eprintln('Error: ${err}')
			return
		}

		println('-------------------------------')
		println('Tag Name:  ${release.tag_name}')
		println('Release:   ${release.name}')
		println('Published: ${release.published_at}')
		println('URL:       ${release.html_url}')
		println('-------------------------------')

	defer {
		println('${term.green(app.name())}' + ' v${term.green(app.version())}' + ' ending...')
	}
}
