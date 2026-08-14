# Idle Studio — Release Automation Makefile
# Used by GitHub Actions and as a backend for the `studio` CLI.
# Usage: make [target] GAME=idle-civilizations
#        make release GAME=idle-civilizations CHANGELOG="v1.1: Space Age update"

REPO_ROOT    := $(shell pwd)
RELEASE_DIR  := $(REPO_ROOT)/tools/release
DEFAULT_GAME ?= idle-civilizations
GAME         ?= $(DEFAULT_GAME)

# Prefer Homebrew Ruby — macOS system Ruby is read-only. Resolved via `brew
# --prefix` so this works on Intel (/usr/local) and Apple Silicon
# (/opt/homebrew) alike, and collapses to an unmodified PATH where brew is
# absent (e.g. GitHub-hosted runners, Linux).
BREW_RUBY_PREFIX := $(shell brew --prefix ruby 2>/dev/null)
RUBY_PATH_PREFIX := $(if $(BREW_RUBY_PREFIX),$(BREW_RUBY_PREFIX)/bin:,)
FASTLANE     := cd $(RELEASE_DIR) && PATH="$(RUBY_PATH_PREFIX)$$PATH" bundle exec fastlane

PYTHON       := $(RELEASE_DIR)/.venv/bin/python3
# Reading config/games.yml must also work before `make setup` has built the venv.
CFG_PYTHON   := $(shell [ -x "$(RELEASE_DIR)/.venv/bin/python3" ] && echo "$(RELEASE_DIR)/.venv/bin/python3" || command -v python3)

# Query a key out of the current GAME's entry in config/games.yml.
# Usage: $(call game_cfg,xcode_scheme)
game_cfg = $(shell $(CFG_PYTHON) -c "import yaml;print(yaml.safe_load(open('$(REPO_ROOT)/config/games.yml'))['games']['$(GAME)'].get('$(1)','') or '')" 2>/dev/null)

SKIP_MATCH   ?= false   # set to true for local builds without a cert repo configured

# ── One-time setup ─────────────────────────────────────────────────────────────

.PHONY: setup
setup: ## Install all Ruby + Python dependencies (run once per machine)
	@echo "→ Installing bundler dependencies..."
	cd $(RELEASE_DIR) && PATH="$(BREW_RUBY):$$PATH" bundle config set --local path 'vendor/bundle' && PATH="$(BREW_RUBY):$$PATH" bundle install
	@echo "→ Setting up Python venv..."
	python3 -m venv $(RELEASE_DIR)/.venv && $(RELEASE_DIR)/.venv/bin/pip install -q -r $(RELEASE_DIR)/scripts/requirements.txt
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

# ── Release ────────────────────────────────────────────────────────────────────

.PHONY: submit
submit: ## Submit the prepared App Store version of GAME for review
	$(FASTLANE) submit game:$(GAME)

.PHONY: release
release: ## Full pipeline for GAME: build → TestFlight → metadata → submit for review
	@test -n "$(CHANGELOG)" || (echo "ERROR: pass CHANGELOG=\"...\""; exit 1)
	$(FASTLANE) release game:$(GAME) skip_match:$(SKIP_MATCH) changelog:"$(CHANGELOG)"

.PHONY: bump-version
bump-version: ## Set the marketing version for GAME (usage: make bump-version VERSION=1.2.0)
	@test -n "$(VERSION)" || (echo "ERROR: pass VERSION=1.2.0"; exit 1)
	@echo "MARKETING_VERSION is owned by apps/$(notdir $(patsubst %/,%,$(dir $(call game_cfg,xcode_project))))/project.yml,"
	@echo "which XcodeGen regenerates the .xcodeproj from — writing it into the .xcodeproj here"
	@echo "would be discarded on the next 'xcodegen generate'."
	@echo ""
	@echo "Set it at the source instead:"
	@echo "  1. $(dir $(call game_cfg,xcode_project))project.yml  → settings.MARKETING_VERSION: $(VERSION)"
	@echo "  2. $(dir $(call game_cfg,xcode_project))Resources/Info.plist → CFBundleShortVersionString"
	@echo "     (should be \$$(MARKETING_VERSION); it is currently hardcoded)"
	@echo ""
	@echo "Those files are outside this Makefile's ownership — see the build-number"
	@echo "comment in tools/release/fastlane/Fastfile for the same conflict."
	@exit 1

# ── Metadata & screenshots ─────────────────────────────────────────────────────

.PHONY: upload-metadata
upload-metadata: ## Upload App Store text metadata + screenshots from metadata/ for GAME
	$(FASTLANE) upload_metadata game:$(GAME)

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
copy-web-assets: ## Copy GAME's artwork into website/public/assets/GAME (default: idle-civilizations)
	@GAME_ID=$(GAME); \
	APP_DIR="$(REPO_ROOT)/$(patsubst %/,%,$(dir $(call game_cfg,xcode_project)))"; \
	ASSETS="$$APP_DIR/Resources/Assets.xcassets"; \
	SCHEME="$(call game_cfg,xcode_scheme)"; \
	DEST=$(REPO_ROOT)/website/public/assets/$$GAME_ID; \
	test -d "$$ASSETS" || { echo "ERROR: no asset catalog for $$GAME_ID at $$ASSETS"; exit 1; }; \
	echo "→ Source: $$ASSETS"; \
	mkdir -p $$DEST/eras $$DEST/wonders $$DEST/leaders $$DEST/buildings; \
	echo "→ Copying level/era artwork..."; \
	if [ -d "$(REPO_ROOT)/artworks/$$GAME_ID" ]; then \
	  cp $(REPO_ROOT)/artworks/$$GAME_ID/*.png $$DEST/eras/ 2>/dev/null || true; \
	elif [ "$$GAME_ID" = "$(DEFAULT_GAME)" ]; then \
	  cp $(REPO_ROOT)/artworks/*.png $$DEST/eras/ 2>/dev/null || true; \
	else \
	  echo "  (none — expected $(REPO_ROOT)/artworks/$$GAME_ID/)"; \
	fi; \
	echo "→ Copying milestone artwork..."; \
	for dir in "$$ASSETS"/ms_*.imageset; do \
	  cp "$$dir"/*.png $$DEST/wonders/ 2>/dev/null || true; \
	done; \
	echo "→ Copying character portraits..."; \
	for dir in "$$ASSETS"/char_*.imageset; do \
	  cp "$$dir"/*.png $$DEST/leaders/ 2>/dev/null || true; \
	done; \
	echo "→ Copying unit icons..."; \
	for dir in "$$ASSETS"/unit_*.imageset; do \
	  cp "$$dir"/*.png $$DEST/buildings/ 2>/dev/null || true; \
	done; \
	echo "→ Copying app icon..."; \
	cp "$$ASSETS/$$SCHEME.appiconset/AppIcon-1024.png" $$DEST/ 2>/dev/null || true; \
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
