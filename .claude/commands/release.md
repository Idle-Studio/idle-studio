# /release [game]

Orchestrate a release for an Idle Studio game. Guides through the full release checklist.

## What this command does

1. Reads current `release_notes.txt` for the game and asks you to confirm or update them
2. Checks `config/games.yml` is fully filled in (app_id, team_id, etc.)
3. Runs `studio sync-iap --dry-run` to preview any IAP changes
4. Runs `studio sync-gc --dry-run` to preview any Game Center changes
5. Asks: sync now? apply changes to ASC?
6. Runs `studio beta --note "..."` to build and push to TestFlight
7. Reminds you to test on TestFlight before submitting
8. Asks: ready to submit to App Store?
9. Runs `studio submit`

## Arguments

`$ARGUMENTS` — game ID (e.g. `idle-civilizations`). Defaults to `idle-civilizations` if omitted.

## Instructions

You are helping orchestrate a release for the Idle Studio game: **$ARGUMENTS** (default: idle-civilizations).

Follow these steps in order. Wait for user confirmation at each checkpoint before proceeding.

### Step 1 — Check config
Read `config/games.yml`. Verify the game entry has:
- `app_id` set (not empty)
- `team_id` set in studio section (not XXXXXXXXXX)

If anything is missing, tell the user what to fill in and stop.

### Step 2 — Review release notes
Read `metadata/$ARGUMENTS/en-US/release_notes.txt`.
Show the current contents and ask: "Are these release notes correct, or would you like to update them?"
If they want to update, ask for the new text and write it to the file.

### Step 3 — Preview IAP changes
Run: `studio sync-iap --game $ARGUMENTS --dry-run`
Show the output. Ask: "Would you like to apply these IAP changes to App Store Connect?"
If yes: run `studio sync-iap --game $ARGUMENTS`

### Step 4 — Preview Game Center changes
Run: `studio sync-gc --game $ARGUMENTS --dry-run`
Show the output. Ask: "Would you like to apply these Game Center changes to App Store Connect?"
If yes: run `studio sync-gc --game $ARGUMENTS`

### Step 5 — Build and TestFlight
Ask for the changelog/release notes to include with the TestFlight build.
Run: `studio beta --game $ARGUMENTS --note "<changelog>"`
Confirm it appears in TestFlight.

### Step 6 — TestFlight testing checkpoint
Tell the user: "The build is now in TestFlight. Test it on a real device before submitting to App Store review."
Ask: "Have you tested the build and are ready to submit for App Store review?"

### Step 7 — Upload metadata
Run: `studio metadata --game $ARGUMENTS`
This pushes description, keywords, and promotional text.

### Step 8 — Submit for review
Run: `studio submit --game $ARGUMENTS`
Confirm submission.

### Step 9 — Done
Tell the user to monitor review status with: `studio status --game $ARGUMENTS`
Typical review time is 24–48 hours.
