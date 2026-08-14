## What and why

<!-- One or two sentences. Link the issue if there is one. -->

## Engine or theme?

<!-- The golden rule (CLAUDE.md): engine code must stay theme-agnostic. -->

- [ ] `engine/` + `Packages/IdleEngine/` — no game-specific names, strings or numbers added
- [ ] `games/<name>/` — content/theme only, no Swift changes needed
- [ ] Neither (tooling, CI, website, docs)

## Checks

- [ ] `swift test --package-path Packages/IdleEngine` passes
- [ ] Economy/balance changes are covered by tests, or none were made
- [ ] `make -n <target>` still resolves for any Makefile change

## This repository is PUBLIC

- [ ] No team IDs, ASC key/issuer IDs, API keys, `.p8`/`.p12` files, or personal
      contact details added — those belong in the environment / GitHub secrets
- [ ] No committed build artifacts (`xcuserdata/`, `report.xml`, `Preview.html`,
      `__pycache__/`)

## Release impact

<!-- Delete if none. -->

- [ ] Needs a `MARKETING_VERSION` bump
- [ ] Changes IAP, Game Center, or App Store metadata (needs an ASC sync)
