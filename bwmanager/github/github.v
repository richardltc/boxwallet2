module github

import net.http
import json

const github_url = 'https://api.github.com/repos/richardltc/boxwallet2/releases/latest'

// Define the structure based on GitHub's API response
pub struct GitHubRelease {
pub:
	tag_name     string @[json: 'tag_name']
	name         string
	published_at string @[json: 'published_at']
	html_url     string @[json: 'html_url']
}

pub fn get_latest_release(owner string, repo string) !GitHubRelease {
  // https://api.github.com/repos/richardltc/boxwallet2/releases/latest
	url := 'https://api.github.com/repos/${owner}/${repo}/releases/latest'

	// GitHub API requires a User-Agent header.
	req := http.Request{
		url:    url
		method: .get
		header: http.new_header(
			key:   .user_agent
			value: 'V-Language-Client'
		)
	}

	resp := req.do()!

	if resp.status_code != 200 {
		return error('Failed to fetch release: ${resp.status_code}')
	}

	// Decode the JSON body into our struct
	release := json.decode(GitHubRelease, resp.body)!
	return release
}
