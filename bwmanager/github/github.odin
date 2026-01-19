package github

import "core:fmt"
import "core:net/http"
import "core:encoding/json"
import "core:strings"

GitHub_Release :: struct {
	tag_name:     string,
	name:         string,
	published_at: string,
	html_url:     string,
}

// Fetches the latest release.
// Note: Caller is responsible for calling delete_release() to free string memory.
get_latest_release :: proc(owner, repo: string) -> (GitHub_Release, bool) {
	url := fmt.tprintf("https://api.github.com/repos/%s/%s/releases/latest", owner, repo)

	// Create headers - GitHub API requires a User-Agent
	headers: http.Headers
	http.headers_init(&headers)
	defer http.headers_destroy(&headers)
	http.headers_set(&headers, "User-Agent", "Odin-Language-Client")

	res, err := http.get(url, headers = headers)
	if err != nil {
		fmt.eprintln("Request error:", err)
		return {}, false
	}
	defer http.response_destroy(res)

	if res.status != .OK {
		fmt.eprintln("Failed to fetch release, status:", res.status)
		return {}, false
	}

	release: GitHub_Release
	parse_err := json.unmarshal(res.body, &release)
	if parse_err != nil {
		fmt.eprintln("JSON parse error:", parse_err)
		return {}, false
	}

	return release, true
}

// Utility to clean up the allocated strings in the struct
delete_release :: proc(release: GitHub_Release) {
	delete(release.tag_name)
	delete(release.name)
	delete(release.published_at)
	delete(release.html_url)
}
