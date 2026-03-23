# Idle Studio — Release Automation Makefile
# Used by GitHub Actions and as a backend for the `studio` CLI.
# Usage: make [target] GAME=idle-civilizations
#        make release GAME=idle-civilizations CHANGELOG="v1.1: Space Age update"

REPO_ROOT    := $(shell pwd)
RELEASE_DIR  := $(REPO_ROOT)/tools/release
DEFAULT_GAME ?= idle-civilizations
GAME         ?= $(DEFAULT_GAME)
# Use Homebrew Ruby (stable symlink) — macOS system Ruby is read-only
BREW_RUBY    := /opt/homebrew/opt/ruby/bin
FASTLANE     := cd $(RELEASE_DIR) && PATH="$(BREW_RUBY):$$PATH" bundle exec fastlane
PYTHON       := $(RELEASE_DIR)/.venv/bin/python3
SKIP_MATCH   ?= false   # set to true for local builds without a cert repo configured

# ── One-time setup ─────────────────────────────────────────────────────────────

.PHONY: setup
setup: ## Install all Ruby + Python dependencies (run once per machine)
	@echo "→ Installing bundler dependencies..."
	cd $(RELEASE_DIR) && PATH="$(BREW_RUBY):$$PATH" bundle config set --local path 'vendor/bundle' && PATH="$(BREW_RUBY):$$PATH" bundle install
	@echo "→ Setting up Python venv..."
	python3 -m venv $(RELEASE_DIR)/.venv && $(RELEASE_DIR)/.venv/bin/pip install -q -r $(RELEASE_DIR)/scripts/requirements.txt
	@echo "→ Installing Playwright Chromium..."
	$(RELEASE_DIR)/.venv/bin/playwright install chromium
	@echo ""
	@echo "✓ Setup complete."
	@echo ""
	@echo "Next steps:"
	@echo "  1. Fill in config/games.yml (team_id, asc_issuer_id, asc_key_id, app_id, match_repo)"
	@echo "  2. Download your ASC .p8 key and set:"
	@echo "       export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXX.p8"
	@echo "       export ASC_KEY_ID=XXXXXXXXXX"
	@echo "       export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
	@echo "       export APPLE_TEAM_ID=XXXXXXXXXX"
	@echo "  3. Run: make setup-signing GAME=$(DEFAULT_GAME)"
	@echo "  4. Run: make install-cli"

.PHONY: install-cli
install-cli: ## Install the `studio` command to /usr/local/bin
	@chmod +x $(RELEASE_DIR)/bin/studio
	@sed "s|__REPO_ROOT__|$(REPO_ROOT)|g" $(RELEASE_DIR)/bin/studio > /tmp/studio-installed
	@mv /tmp/studio-installed /usr/local/bin/studio
	@chmod +x /usr/local/bin/studio
	@echo "✓ Installed: studio → /usr/local/bin/studio"
	@echo "  Run 'studio help' from any directory."

.PHONY: uninstall-cli
uninstall-cli: ## Remove the `studio` command from /usr/local/bin
	@rm -f /usr/local/bin/studio
	@echo "✓ Removed /usr/local/bin/studio"

# ── Code signing ───────────────────────────────────────────────────────────────

.PHONY: setup-signing
setup-signing: ## Sync code signing certificates for GAME via fastlane match
	$(FASTLANE) setup_signing game:$(GAME)

.PHONY: nuke-signing
nuke-signing: ## DANGER: Revoke and regenerate all certificates for GAME
	@echo "WARNING: This will revoke all certificates. Press Ctrl-C to abort, Enter to continue."
	@read _
	$(FASTLANE) nuke_signing game:$(GAME)

# ── Build ──────────────────────────────────────────────────────────────────────

.PHONY: screenshots
screenshots: ## Generate App Store screenshots from HTML templates for GAME
	$(PYTHON) $(REPO_ROOT)/tools/generate_screenshots.py --game $(GAME)

.PHONY: verify-icon
verify-icon: ## Verify the 1024×1024 App Store icon is correctly configured
	$(PYTHON) $(RELEASE_DIR)/scripts/verify_icon.py --game $(GAME)

.PHONY: build
build: ## Archive GAME and export .ipa for App Store distribution
	$(FASTLANE) build game:$(GAME) skip_match:$(SKIP_MATCH)

# ── TestFlight ─────────────────────────────────────────────────────────────────

.PHONY: beta
beta: ## Build GAME and upload to TestFlight (internal testers)
	@test -n "$(CHANGELOG)" || (echo "ERROR: pass CHANGELOG=\"...\""; exit 1)
	$(FASTLANE) beta game:$(GAME) skip_match:$(SKIP_MATCH) changelog:"$(CHANGELOG)"

.PHONY: distribute-beta
distribute-beta: ## Push latest processed TestFlight build to external groups
	$(FASTLANE) distribute_beta game:$(GAME)

# ── Metadata & screenshots ─────────────────────────────────────────────────────

.PHONY: upload-metadata
upload-metadata: ## Upload App Store text metadata for GAME (no screenshots)
	$(FASTLANE) upload_metadata game:$(GAME)

.PHONY: upload-screenshots
upload-screenshots: ## Upload App Store screenshots for GAME
	$(FASTLANE) ios upload_screenshots game:$(GAME)

# ── IAP & Game Center ──────────────────────────────────────────────────────────

.PHONY: sync-iap
sync-iap: ## Sync .storekit products → ASC IAP for GAME (never deletes)
	$(RELEASE_DIR)/.venv/bin/python3 $(RELEASE_DIR)/scripts/sync_iap.py --game $(GAME) $(if $(DRY_RUN),--dry-run,)

.PHONY: sync-gamecenter
sync-gamecenter: ## Sync ThemePackage leaderboards/achievements → ASC Game Center for GAME
	$(RELEASE_DIR)/.venv/bin/python3 $(RELEASE_DIR)/scripts/sync_gamecenter.py --game $(GAME) $(if $(DRY_RUN),--dry-run,)

.PHONY: sync-all-asc
sync-all-asc: sync-iap sync-gamecenter ## Sync IAP + Game Center in one shot
	@echo "✓ ASC sync complete for $(GAME)"

# ── Submission ─────────────────────────────────────────────────────────────────

.PHONY: submit
submit: ## Submit GAME for App Store review (uses latest processed build)
	$(FASTLANE) submit game:$(GAME)

.PHONY: release
release: ## FULL PIPELINE: build → TestFlight → metadata → submit
	@test -n "$(CHANGELOG)" || (echo "ERROR: pass CHANGELOG=\"...\""; exit 1)
	$(FASTLANE) release game:$(GAME) changelog:"$(CHANGELOG)"

# ── Status & reports ───────────────────────────────────────────────────────────

.PHONY: review-status
review-status: ## Show current App Store review status for GAME
	$(RELEASE_DIR)/.venv/bin/python3 $(RELEASE_DIR)/scripts/check_review_status.py --game $(GAME)

.PHONY: reports
reports: ## Pull last 7 days of sales + downloads for GAME
	$(RELEASE_DIR)/.venv/bin/python3 $(RELEASE_DIR)/scripts/fetch_reports.py --game $(GAME) --days 7

.PHONY: reports-30
reports-30: ## Pull last 30 days of sales + downloads for GAME
	$(RELEASE_DIR)/.venv/bin/python3 $(RELEASE_DIR)/scripts/fetch_reports.py --game $(GAME) --days 30

.PHONY: games
games: ## List all configured games
	@$(RELEASE_DIR)/.venv/bin/python3 -c "import yaml; cfg=yaml.safe_load(open('config/games.yml')); [print(f'  {k}: {v[\"display_name\"]} ({v[\"bundle_id\"]})') for k,v in cfg['games'].items()]"

# ── Website ────────────────────────────────────────────────────────────────────

.PHONY: copy-web-assets
copy-web-assets: ## Copy game artwork into website/public/assets for GAME (default: idle-civilizations)
	@GAME_ID=$(GAME); \
	DEST=$(REPO_ROOT)/website/public/assets/$$GAME_ID; \
	mkdir -p $$DEST/eras $$DEST/wonders $$DEST/leaders $$DEST/buildings; \
	echo "→ Copying era artwork..."; \
	cp $(REPO_ROOT)/artworks/*.png $$DEST/eras/ 2>/dev/null || true; \
	echo "→ Copying wonder artwork..."; \
	for dir in $(REPO_ROOT)/apps/IdleCivilizations/Resources/Assets.xcassets/ms_*.imageset; do \
	  cp "$$dir"/*.png $$DEST/wonders/ 2>/dev/null || true; \
	done; \
	echo "→ Copying leader portraits..."; \
	for dir in $(REPO_ROOT)/apps/IdleCivilizations/Resources/Assets.xcassets/char_*.imageset; do \
	  cp "$$dir"/*.png $$DEST/leaders/ 2>/dev/null || true; \
	done; \
	echo "→ Copying building icons..."; \
	for dir in $(REPO_ROOT)/apps/IdleCivilizations/Resources/Assets.xcassets/unit_*.imageset; do \
	  cp "$$dir"/*.png $$DEST/buildings/ 2>/dev/null || true; \
	done; \
	echo "→ Copying app icon..."; \
	cp $(REPO_ROOT)/apps/IdleCivilizations/Resources/Assets.xcassets/IdleCivilizations.appiconset/AppIcon-1024.png $$DEST/ 2>/dev/null || true; \
	echo "✓ Assets copied to $$DEST"

.PHONY: web-dev
web-dev: copy-web-assets ## Copy assets + start website dev server
	cd $(REPO_ROOT)/website && npm run dev

.PHONY: web-build
web-build: copy-web-assets ## Copy assets + build website for production
	cd $(REPO_ROOT)/website && npm run build

# ── Help ───────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show all available targets
	@echo ""
	@echo "Idle Studio Release Automation"
	@echo "Usage: make [target] GAME=idle-civilizations"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""

.DEFAULT_GOAL := help
