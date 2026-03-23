"""
game_config.py — Load and validate game configuration from config/games.yml.
"""

from __future__ import annotations
import os
from pathlib import Path
import yaml


# config/games.yml lives 4 levels up from this file:
# tools/release/scripts/lib/ → tools/release/scripts/ → tools/release/ → tools/ → repo root
REPO_ROOT = Path(__file__).resolve().parents[4]
CONFIG_PATH = REPO_ROOT / "config" / "games.yml"


def load_config() -> dict:
    with open(CONFIG_PATH) as f:
        return yaml.safe_load(f)


def load_game(game_id: str) -> dict:
    cfg = load_config()
    games = cfg.get("games", {})
    if game_id not in games:
        available = ", ".join(games.keys())
        raise ValueError(
            f"Unknown game '{game_id}'. "
            f"Available games: {available}. "
            f"Add it to config/games.yml first."
        )
    game = games[game_id]
    game["id"] = game_id
    game["studio"] = cfg["studio"]
    # Resolve paths relative to repo root
    game["storekit_config_path"] = REPO_ROOT / game["storekit_config"]
    game["theme_json_path"]      = REPO_ROOT / game["theme_json"]
    game["metadata_dir"]         = REPO_ROOT / game["metadata_path"]
    return game


def list_games() -> dict[str, dict]:
    cfg = load_config()
    return cfg.get("games", {})
