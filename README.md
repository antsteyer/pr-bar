# PRBar

A macOS menu bar app that displays your GitHub pull requests:

- **To review** — PRs where your review is requested (`review-requested:@me`)
- **My PRs** — your open PRs (`author:@me`)

For each PR: CI status (✅/❌/🟡), repo, number, draft badge, age. Click to open the PR in your browser. Auto-refreshes every 3 minutes + manual refresh button.

On **My PRs**, two badges tell what to do next:

- **To address** (orange) — a reviewer's latest review is a comment or a change request, and they were not asked to review again.
- **Ready to merge** (green) — the PR is approved, GitHub reports it as mergeable with every check passing (`mergeStateStatus` `CLEAN`), and no review request is still pending.

## Requirements

- macOS 14+
- A **GitHub** account (GitLab/Bitbucket not supported)
- [`gh` CLI](https://cli.github.com) installed and authenticated (`gh auth status`)

The app shells out to `gh` — no token to manage. Since a GUI app does not inherit the shell `PATH`, the `gh` path is hardcoded in `GitHubService.swift`:

- **Apple Silicon**: `/opt/homebrew/bin/gh` (default)
- **Intel**: `/usr/local/bin/gh`

Run `which gh` and update the line if needed.

## Build & run

Notifications only work from a signed `.app` bundle: the bare binary (`swift run`) crashes on launch.

```bash
./make-app.sh        # builds a release, bundles and ad-hoc signs pr-bar.app
open -n pr-bar.app   # -n starts it even when the installed copy is running
```

## Install

```bash
./make-app.sh
rm -rf /Applications/pr-bar.app && cp -R pr-bar.app /Applications/
```

Quit the running app from its menu first, then reopen `/Applications/pr-bar.app`.

## Auto-start on login (LaunchAgent)

A LaunchAgent can be installed at `~/Library/LaunchAgents/com.antsteyer.prbar.plist`, running `/usr/bin/open /Applications/pr-bar.app` with `RunAtLoad`. It starts the app on every login.

```bash
# Stop (until next login)
launchctl unload ~/Library/LaunchAgents/com.antsteyer.prbar.plist

# Start now
launchctl load -w ~/Library/LaunchAgents/com.antsteyer.prbar.plist
```

`KeepAlive` is set to `false`: the Quit button properly closes the app.

## Open in Xcode

`File ▸ Open…` on the folder (Xcode reads `Package.swift`), then Run.
