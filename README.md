# PRBar

A macOS menu bar app that displays your GitHub pull requests:

- **To review** — PRs where your review is requested (`review-requested:@me`)
- **My PRs** — your open PRs (`author:@me`)

For each PR: CI status (✅/❌/🟡), repo, number, draft badge, age. Click to open the PR in your browser. Auto-refreshes every 3 minutes + manual refresh button.

## Requirements

- macOS 14+
- A **GitHub** account (GitLab/Bitbucket not supported)
- [`gh` CLI](https://cli.github.com) installed and authenticated (`gh auth status`)

The app shells out to `gh` — no token to manage. Since a GUI app does not inherit the shell `PATH`, the `gh` path is hardcoded in `GitHubService.swift`:

- **Apple Silicon**: `/opt/homebrew/bin/gh` (default)
- **Intel**: `/usr/local/bin/gh`

Run `which gh` and update the line if needed.

## Run

```bash
swift run
```

The terminal stays busy while the app is running (Ctrl-C or Quit from the menu to close).

## Build release & run in background

```bash
swift build -c release
./.build/release/PRBar &
```

You can also copy the binary anywhere and add it to your login items.

## Auto-start on login (LaunchAgent)

A LaunchAgent can be installed at `~/Library/LaunchAgents/com.antsteyer.prbar.plist` pointing to `.build/release/PRBar`. It starts the app on every login.

```bash
# Stop (until next login)
launchctl unload ~/Library/LaunchAgents/com.antsteyer.prbar.plist

# Start now
launchctl load -w ~/Library/LaunchAgents/com.antsteyer.prbar.plist
```

`KeepAlive` is set to `false`: the Quit button properly closes the app. Do not delete the project folder (the plist references the binary inside it).

## Open in Xcode

`File ▸ Open…` on the folder (Xcode reads `Package.swift`), then Run.
