#!/usr/bin/env python3
"""
generate_screenshots.py — Generate App Store screenshots via HTML + Playwright.

Renders 6 screenshot concepts × 3 device sizes = 18 PNG files.
Uses era artwork from /artworks/ and design tokens from idle-civilizations.json.

Usage:
    python3 tools/generate_screenshots.py --game idle-civilizations

Output:
    metadata/{game}/screenshots/iphone-6.5/01_campfire.png
    metadata/{game}/screenshots/iphone-5.5/01_campfire.png
    metadata/{game}/screenshots/ipad-12.9/01_campfire.png
    ... (18 files total)

Requirements:
    pip install playwright && playwright install chromium
"""

import argparse
import base64
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

sys.path.insert(0, str(REPO_ROOT / "tools/release/scripts/lib"))
from game_config import load_game

# ── Device sizes ───────────────────────────────────────────────────────────────

DEVICES = {
    "iphone-6.5": (1284, 2778),
    "iphone-5.5": (1242, 2208),
    "ipad-12.9":  (2048, 2732),
}

# ── Screenshot definitions ─────────────────────────────────────────────────────

SCREENSHOTS = [
    {
        "filename":  "01_campfire",
        "era":       "stone_age",
        "headline":  "From campfire\nto civilization",
        "subhead":   "Start with nothing. Build everything.",
        "gold":      "1.24B",
        "gold_rate": "142M/sec",
        "era_label": "Stone Age",
        "era_pct":   67,
        "units": [
            ("unit_campfire",       "🔥", "Campfire",       "284K/s"),
            ("unit_berry_gatherer", "🍇", "Berry Gatherer",  "1.2M/s"),
            ("unit_fishing_spot",   "🎣", "Fishing Spot",    "4.8M/s"),
            ("unit_hunting_lodge",  "🏹", "Hunting Lodge",  "18.3M/s"),
        ],
        "type": "gameplay",
    },
    {
        "filename":  "02_wonder",
        "era":       "bronze_age",
        "headline":  "Build World\nWonders",
        "subhead":   "Unlock history's greatest achievements",
        "gold":      "48.7B",
        "gold_rate": "2.1B/sec",
        "era_label": "Bronze Age",
        "era_pct":   45,
        "wonder_name":   "Stonehenge",
        "wonder_emoji":  "🗿",
        "wonder_bonus":  "+200% Bronze Age Gold",
        "wonder_time":   "59:42",
        "type": "wonder",
    },
    {
        "filename":  "03_leader",
        "era":       "renaissance",
        "headline":  "Unlock Legendary\nLeaders",
        "subhead":   "Boost your favourite buildings",
        "gold":      "7.2Qa",
        "gold_rate": "890T/sec",
        "era_label": "Renaissance",
        "era_pct":   38,
        "leader_name":   "Leonardo da Vinci",
        "leader_emoji":  "🎨",
        "leader_era":    "Renaissance",
        "leader_bonus1": "Da Vinci Workshop ×1.30",
        "leader_bonus2": "Art Studio ×1.15",
        "type": "leader",
    },
    {
        "filename":  "04_offline",
        "era":       "industrial_revolution",
        "headline":  "Grow while\nyou sleep",
        "subhead":   "Your empire never stops producing",
        "gold":      "3.8Sx",
        "gold_rate": "12.4Qa/sec",
        "era_label": "Industrial Revolution",
        "era_pct":   72,
        "offline_hours":    "8h 14m",
        "offline_earned":   "366 Quintillion Gold",
        "offline_multi":    "×2.0 Civ Pass bonus",
        "type": "offline",
    },
    {
        "filename":  "05_leaderboard",
        "era":       "space_age",
        "headline":  "Compete\nworldwide",
        "subhead":   "Climb the global leaderboard",
        "gold":      "2.1Sp",
        "gold_rate": "44.7Sx/sec",
        "era_label": "Space Age",
        "era_pct":   55,
        "leaders": [
            (1,  "🥇", "GreatBuilder99",     "8.92 Sp"),
            (2,  "🥈", "EmpireKing",         "7.41 Sp"),
            (3,  "🥉", "CivMaster",          "6.18 Sp"),
            (4,  "  ", "HistoryHunter",      "5.03 Sp"),
            (5,  "  ", "TokenCollector",     "4.77 Sp"),
            ("★","⭐", "You",                "2.1 Sp"),
        ],
        "type": "leaderboard",
    },
    {
        "filename":  "06_eras",
        "era":       "ancient_empires",
        "headline":  "8 Eras\nof History",
        "subhead":   "Journey from Stone Age to Space Age",
        "gold":      "92.4T",
        "gold_rate": "3.8T/sec",
        "era_label": "Ancient Empires",
        "era_pct":   82,
        "eras": [
            ("🔥", "Stone\nAge",         "#8B7355"),
            ("⚒️",  "Bronze\nAge",        "#CD7F32"),
            ("🏛️",  "Ancient\nEmpires",  "#C4A44D"),
            ("⚔️",  "Classical\nWorld",   "#5B8DB8"),
            ("🏰", "Medieval\nEra",      "#6B4F7C"),
            ("🎨", "Renaissance",        "#C44B24"),
            ("⚙️",  "Industrial",        "#607080"),
            ("🚀", "Space\nAge",         "#1E4A7E"),
        ],
        "type": "eras",
    },
]

# Era color palettes (top, bottom)
ERA_COLORS = {
    "stone_age":             ("#8B7355", "#2A1A08"),
    "bronze_age":            ("#CD7F32", "#3A1A05"),
    "ancient_empires":       ("#C4A44D", "#3A2805"),
    "classical_world":       ("#5B8DB8", "#0E2A40"),
    "medieval_era":          ("#6B4F7C", "#1A0A28"),
    "renaissance":           ("#C44B24", "#380A05"),
    "industrial_revolution": ("#607080", "#151E28"),
    "space_age":             ("#1E4A7E", "#020810"),
}


def img_to_b64(path: Path) -> str:
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


def build_html(shot: dict, w: int, h: int, artworks_dir: Path, xcassets_dir: Path) -> str:
    era        = shot["era"]
    top_color  = ERA_COLORS[era][0]
    bot_color  = ERA_COLORS[era][1]
    is_ipad    = w > 1500
    scale      = w / 1284  # scale factor relative to iPhone 6.5" base

    # Load era artwork as base64
    art_path = artworks_dir / f"era_{era}.png"
    art_b64  = img_to_b64(art_path) if art_path.exists() else ""
    art_tag  = f'<img src="data:image/png;base64,{art_b64}">' if art_b64 else ""

    # Load unit icons as base64
    unit_tags = {}
    for name_candidate in [
        "unit_campfire", "unit_berry_gatherer", "unit_fishing_spot", "unit_hunting_lodge",
        "unit_mine", "unit_smelter", "unit_marketplace", "unit_warship", "unit_bronze_palace",
        "unit_grain_farm", "unit_aqueduct", "unit_amphitheatre", "unit_army_barracks",
        "unit_great_pyramid", "unit_printing_press", "unit_university", "unit_art_studio",
        "unit_da_vinci_workshop", "unit_coal_mine", "unit_steam_engine", "unit_factory",
        "unit_power_station", "unit_radio_tower", "unit_space_rocket", "unit_lunar_base",
    ]:
        icon_path = xcassets_dir / f"{name_candidate}.imageset" / f"{name_candidate}.png"
        if icon_path.exists():
            unit_tags[name_candidate] = img_to_b64(icon_path)

    def unit_img(name: str, size: int = 80) -> str:
        b64 = unit_tags.get(name, "")
        if b64:
            return f'<img src="data:image/png;base64,{b64}" width="{size}" height="{size}" style="border-radius:{int(size*0.22)}px">'
        return f'<div style="width:{size}px;height:{size}px;border-radius:{int(size*0.22)}px;background:{top_color};display:flex;align-items:center;justify-content:center;font-size:{int(size*0.5)}px">🏛️</div>'

    # Font sizes scale with device width
    fs = lambda base: int(base * scale)

    # ── Build content block based on screenshot type ──────────────────────────
    shot_type = shot.get("type", "gameplay")

    if shot_type == "gameplay":
        units_html = ""
        for u_name, u_emoji, u_label, u_rate in shot.get("units", []):
            units_html += f"""
            <div class="bcard">
              <div class="bcard-icon">{unit_img(u_name, fs(72))}</div>
              <div class="bcard-info">
                <div class="bcard-name">{u_label}</div>
                <div class="bcard-rate">💰 {u_rate}</div>
              </div>
              <div class="bcard-btn">▲</div>
            </div>"""
        content_block = f'<div class="buildings">{units_html}</div>'

    elif shot_type == "wonder":
        content_block = f"""
        <div class="wonder-card">
          <div class="wonder-header">
            <span style="font-size:{fs(48)}px">{shot['wonder_emoji']}</span>
            <div>
              <div class="wonder-title">{shot['wonder_name']}</div>
              <div class="wonder-bonus">{shot['wonder_bonus']}</div>
            </div>
          </div>
          <div class="wonder-progress">
            <div class="wonder-bar"><div class="wonder-fill" style="width:62%"></div></div>
            <div class="wonder-time">⏱ {shot['wonder_time']} remaining</div>
          </div>
          <div class="wonder-cta">BUILDING...</div>
        </div>"""

    elif shot_type == "leader":
        content_block = f"""
        <div class="leader-card">
          <div class="leader-avatar">{shot['leader_emoji']}</div>
          <div class="leader-name">{shot['leader_name']}</div>
          <div class="leader-era">{shot['leader_era']} · Legendary Leader</div>
          <div class="leader-divider"></div>
          <div class="leader-bonus">✦ {shot['leader_bonus1']}</div>
          <div class="leader-bonus">✦ {shot['leader_bonus2']}</div>
          <div class="leader-cta">UNLOCK</div>
        </div>"""

    elif shot_type == "offline":
        content_block = f"""
        <div class="offline-card">
          <div class="offline-title">⚡ Welcome Back!</div>
          <div class="offline-time">Away for {shot['offline_hours']}</div>
          <div class="offline-earned">{shot['offline_earned']}</div>
          <div class="offline-sub">earned while offline</div>
          <div class="offline-badge">{shot['offline_multi']}</div>
          <div class="offline-cta">COLLECT ALL</div>
        </div>"""

    elif shot_type == "leaderboard":
        rows_html = ""
        for rank, medal, name, score in shot.get("leaders", []):
            is_you = (name == "You")
            row_class = "lb-row lb-you" if is_you else "lb-row"
            rows_html += f"""
            <div class="{row_class}">
              <div class="lb-rank">{rank}</div>
              <div class="lb-medal">{medal}</div>
              <div class="lb-name">{name}</div>
              <div class="lb-score">{score}</div>
            </div>"""
        content_block = f"""
        <div class="leaderboard">
          <div class="lb-title">🏆 Global Leaderboard</div>
          <div class="lb-subtitle">Legacy Tokens — All Time</div>
          {rows_html}
        </div>"""

    elif shot_type == "eras":
        era_items = ""
        for i, (emoji, label, color) in enumerate(shot.get("eras", [])):
            current = (i == 2)  # Ancient Empires is "current"
            unlocked = (i <= 2)
            item_class = "era-item era-current" if current else ("era-item era-unlocked" if unlocked else "era-item era-locked")
            era_items += f"""
            <div class="{item_class}" style="--era-color:{color}">
              <div class="era-dot">{emoji if unlocked else "🔒"}</div>
              <div class="era-lbl">{label}</div>
            </div>"""
        content_block = f'<div class="era-map">{era_items}</div>'

    else:
        content_block = ""

    # ── Full HTML ─────────────────────────────────────────────────────────────
    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  body {{
    width:{w}px; height:{h}px;
    background:{bot_color};
    font-family: -apple-system, 'Helvetica Neue', Arial, sans-serif;
    color:#F5F5F5;
    overflow:hidden;
    position:relative;
  }}

  /* Background artwork */
  .bg {{
    position:absolute; inset:0;
    z-index:0;
  }}
  .bg img {{
    width:100%; height:100%;
    object-fit:cover;
    object-position:center top;
  }}
  .bg::after {{
    content:'';
    position:absolute; inset:0;
    background: linear-gradient(
      to bottom,
      rgba(13,13,15,0.55) 0%,
      rgba(13,13,15,0.30) 20%,
      rgba(13,13,15,0.60) 55%,
      rgba(13,13,15,0.95) 80%,
      rgba(13,13,15,1.00) 100%
    );
  }}

  /* Content layer */
  .ui {{
    position:absolute; inset:0;
    z-index:1;
    display:flex;
    flex-direction:column;
    padding: {fs(32)}px {fs(24)}px;
    gap: {fs(14)}px;
  }}

  /* Status bar mock */
  .status-bar {{
    display:flex;
    justify-content:space-between;
    align-items:center;
    font-size:{fs(18)}px;
    opacity:0.85;
    padding: 0 {fs(4)}px;
  }}

  /* Resource bar */
  .resource-bar {{
    background:rgba(26,26,32,0.92);
    border-radius:{fs(16)}px;
    padding:{fs(18)}px {fs(22)}px;
    display:flex;
    align-items:center;
    justify-content:space-between;
    border:1px solid rgba(255,215,0,0.20);
  }}
  .gold-amount {{
    font-size:{fs(38)}px;
    font-weight:700;
    color:#FFD700;
    letter-spacing:-0.5px;
  }}
  .gold-rate {{
    font-size:{fs(20)}px;
    color:#B8A040;
  }}

  /* Era progress */
  .era-bar-wrap {{
    background:rgba(26,26,32,0.88);
    border-radius:{fs(12)}px;
    padding:{fs(12)}px {fs(22)}px;
    display:flex;
    align-items:center;
    gap:{fs(16)}px;
  }}
  .era-name {{
    font-size:{fs(20)}px;
    font-weight:600;
    color:{top_color};
    white-space:nowrap;
    min-width:{fs(130)}px;
  }}
  .prog-track {{
    flex:1;
    height:{fs(10)}px;
    background:rgba(255,255,255,0.12);
    border-radius:{fs(5)}px;
    overflow:hidden;
  }}
  .prog-fill {{
    height:100%;
    width:{shot['era_pct']}%;
    background:linear-gradient(90deg, {top_color}, {ERA_COLORS[era][0]}cc);
    border-radius:{fs(5)}px;
  }}
  .era-pct {{
    font-size:{fs(18)}px;
    color:rgba(255,255,255,0.55);
    white-space:nowrap;
  }}

  /* Building cards */
  .buildings {{
    display:flex;
    flex-direction:column;
    gap:{fs(10)}px;
    flex:1;
    justify-content:center;
  }}
  .bcard {{
    background:rgba(26,26,32,0.90);
    border-radius:{fs(18)}px;
    padding:{fs(14)}px {fs(18)}px;
    display:flex;
    align-items:center;
    gap:{fs(16)}px;
    border:1px solid rgba(255,255,255,0.07);
  }}
  .bcard-icon {{ flex-shrink:0; }}
  .bcard-info {{ flex:1; }}
  .bcard-name {{
    font-size:{fs(22)}px;
    font-weight:600;
    color:#F5F5F5;
  }}
  .bcard-rate {{
    font-size:{fs(18)}px;
    color:#FFD700;
    margin-top:{fs(3)}px;
  }}
  .bcard-btn {{
    font-size:{fs(28)}px;
    color:{top_color};
    font-weight:700;
    background:rgba(255,255,255,0.08);
    width:{fs(52)}px;
    height:{fs(52)}px;
    border-radius:{fs(13)}px;
    display:flex;
    align-items:center;
    justify-content:center;
  }}

  /* Wonder card */
  .wonder-card {{
    background:rgba(26,26,32,0.95);
    border-radius:{fs(24)}px;
    padding:{fs(32)}px;
    border:2px solid {top_color}55;
    flex:1;
    display:flex;
    flex-direction:column;
    justify-content:center;
    gap:{fs(18)}px;
  }}
  .wonder-header {{
    display:flex;
    align-items:center;
    gap:{fs(20)}px;
  }}
  .wonder-title {{
    font-size:{fs(36)}px;
    font-weight:700;
    color:#F5F5F5;
  }}
  .wonder-bonus {{
    font-size:{fs(22)}px;
    color:{top_color};
    margin-top:{fs(4)}px;
  }}
  .wonder-progress {{ display:flex; flex-direction:column; gap:{fs(10)}px; }}
  .wonder-bar {{
    height:{fs(16)}px;
    background:rgba(255,255,255,0.10);
    border-radius:{fs(8)}px;
    overflow:hidden;
  }}
  .wonder-fill {{
    height:100%;
    background:linear-gradient(90deg, {top_color}, #FFD700);
    border-radius:{fs(8)}px;
  }}
  .wonder-time {{
    font-size:{fs(22)}px;
    color:rgba(255,255,255,0.65);
  }}
  .wonder-cta {{
    align-self:center;
    background:linear-gradient(135deg, {top_color}, {ERA_COLORS[era][0]});
    color:#fff;
    font-weight:700;
    font-size:{fs(22)}px;
    letter-spacing:2px;
    padding:{fs(16)}px {fs(40)}px;
    border-radius:{fs(50)}px;
    margin-top:{fs(8)}px;
  }}

  /* Leader card */
  .leader-card {{
    background:rgba(26,26,32,0.95);
    border-radius:{fs(24)}px;
    padding:{fs(32)}px;
    border:2px solid {top_color}55;
    flex:1;
    display:flex;
    flex-direction:column;
    align-items:center;
    justify-content:center;
    gap:{fs(14)}px;
    text-align:center;
  }}
  .leader-avatar {{
    font-size:{fs(90)}px;
    line-height:1;
    background:rgba(255,255,255,0.05);
    width:{fs(160)}px;
    height:{fs(160)}px;
    border-radius:{fs(80)}px;
    display:flex;
    align-items:center;
    justify-content:center;
    border:2px solid {top_color}66;
  }}
  .leader-name {{
    font-size:{fs(36)}px;
    font-weight:700;
    color:#F5F5F5;
  }}
  .leader-era {{
    font-size:{fs(20)}px;
    color:{top_color};
    opacity:0.85;
  }}
  .leader-divider {{
    width:60%;
    height:1px;
    background:rgba(255,255,255,0.10);
    margin:{fs(4)}px 0;
  }}
  .leader-bonus {{
    font-size:{fs(22)}px;
    color:rgba(255,255,255,0.80);
  }}
  .leader-cta {{
    background:linear-gradient(135deg, {top_color}, {ERA_COLORS[era][0]});
    color:#fff;
    font-weight:700;
    font-size:{fs(22)}px;
    letter-spacing:2px;
    padding:{fs(16)}px {fs(48)}px;
    border-radius:{fs(50)}px;
    margin-top:{fs(10)}px;
  }}

  /* Offline card */
  .offline-card {{
    background:rgba(26,26,32,0.95);
    border-radius:{fs(24)}px;
    padding:{fs(36)}px;
    border:2px solid {top_color}55;
    flex:1;
    display:flex;
    flex-direction:column;
    align-items:center;
    justify-content:center;
    gap:{fs(12)}px;
    text-align:center;
  }}
  .offline-title {{
    font-size:{fs(32)}px;
    font-weight:700;
    color:{top_color};
  }}
  .offline-time {{
    font-size:{fs(22)}px;
    color:rgba(255,255,255,0.60);
  }}
  .offline-earned {{
    font-size:{fs(44)}px;
    font-weight:700;
    color:#FFD700;
    line-height:1.1;
  }}
  .offline-sub {{
    font-size:{fs(22)}px;
    color:rgba(255,255,255,0.60);
  }}
  .offline-badge {{
    background:{top_color}33;
    border:1px solid {top_color}66;
    color:{top_color};
    font-size:{fs(20)}px;
    font-weight:600;
    padding:{fs(8)}px {fs(24)}px;
    border-radius:{fs(30)}px;
    margin-top:{fs(4)}px;
  }}
  .offline-cta {{
    background:linear-gradient(135deg, #FFD700, #FFA500);
    color:#1A1A00;
    font-weight:700;
    font-size:{fs(24)}px;
    letter-spacing:2px;
    padding:{fs(18)}px {fs(56)}px;
    border-radius:{fs(50)}px;
    margin-top:{fs(14)}px;
  }}

  /* Leaderboard */
  .leaderboard {{
    background:rgba(26,26,32,0.95);
    border-radius:{fs(24)}px;
    padding:{fs(24)}px;
    border:2px solid {top_color}44;
    flex:1;
    display:flex;
    flex-direction:column;
    gap:{fs(10)}px;
  }}
  .lb-title {{
    font-size:{fs(30)}px;
    font-weight:700;
    color:#F5F5F5;
    text-align:center;
  }}
  .lb-subtitle {{
    font-size:{fs(18)}px;
    color:rgba(255,255,255,0.45);
    text-align:center;
    margin-bottom:{fs(8)}px;
  }}
  .lb-row {{
    display:flex;
    align-items:center;
    gap:{fs(14)}px;
    padding:{fs(12)}px {fs(16)}px;
    border-radius:{fs(12)}px;
    background:rgba(255,255,255,0.04);
  }}
  .lb-you {{
    background:{top_color}22;
    border:1px solid {top_color}55;
  }}
  .lb-rank {{
    font-size:{fs(20)}px;
    font-weight:700;
    color:rgba(255,255,255,0.45);
    width:{fs(32)}px;
    text-align:center;
  }}
  .lb-medal {{ font-size:{fs(22)}px; width:{fs(30)}px; }}
  .lb-name {{
    flex:1;
    font-size:{fs(22)}px;
    font-weight:500;
    color:#F5F5F5;
  }}
  .lb-score {{
    font-size:{fs(22)}px;
    font-weight:700;
    color:#FFD700;
  }}

  /* Era map */
  .era-map {{
    flex:1;
    display:flex;
    flex-direction:row;
    align-items:stretch;
    gap:{fs(8)}px;
    padding:{fs(8)}px 0;
  }}
  .era-item {{
    flex:1;
    display:flex;
    flex-direction:column;
    align-items:center;
    justify-content:center;
    gap:{fs(10)}px;
    border-radius:{fs(16)}px;
    padding:{fs(16)}px {fs(6)}px;
    transition:all 0.2s;
  }}
  .era-unlocked {{
    background:rgba(255,255,255,0.06);
    border:1px solid rgba(255,255,255,0.10);
  }}
  .era-current {{
    background:var(--era-color,#8B7355)22;
    border:2px solid var(--era-color,#8B7355);
  }}
  .era-locked {{
    background:rgba(0,0,0,0.30);
    border:1px solid rgba(255,255,255,0.04);
    opacity:0.5;
  }}
  .era-dot {{ font-size:{fs(30)}px; line-height:1; }}
  .era-lbl {{
    font-size:{fs(14)}px;
    text-align:center;
    line-height:1.3;
    color:rgba(255,255,255,0.80);
    white-space:pre-line;
    font-weight:500;
  }}

  /* Headline block */
  .headline-block {{
    background:rgba(13,13,15,0.75);
    border-radius:{fs(20)}px;
    padding:{fs(20)}px {fs(24)}px;
    text-align:center;
  }}
  .headline {{
    font-size:{fs(52)}px;
    font-weight:800;
    line-height:1.1;
    color:#FFFFFF;
    letter-spacing:-0.5px;
    white-space:pre-line;
  }}
  .subhead {{
    font-size:{fs(22)}px;
    color:rgba(255,255,255,0.65);
    margin-top:{fs(8)}px;
  }}

  /* App brand footer */
  .brand {{
    display:flex;
    align-items:center;
    justify-content:center;
    gap:{fs(12)}px;
    padding:{fs(10)}px 0;
  }}
  .brand-name {{
    font-size:{fs(24)}px;
    font-weight:700;
    color:rgba(255,255,255,0.85);
    letter-spacing:0.5px;
  }}
  .brand-dot {{
    width:{fs(8)}px;
    height:{fs(8)}px;
    border-radius:50%;
    background:#FFD700;
  }}
</style>
</head>
<body>
  <div class="bg">{art_tag}</div>
  <div class="ui">
    <!-- Status bar -->
    <div class="status-bar">
      <span>9:41</span>
      <span>Idle Civilizations</span>
      <span>⚡ 100%</span>
    </div>

    <!-- Resource bar -->
    <div class="resource-bar">
      <div>
        <div style="font-size:{fs(18)}px;color:rgba(255,255,255,0.55);margin-bottom:{fs(3)}px">💰 GOLD</div>
        <div class="gold-amount">{shot['gold']}</div>
      </div>
      <div style="text-align:right">
        <div style="font-size:{fs(18)}px;color:rgba(255,255,255,0.55);margin-bottom:{fs(3)}px">per second</div>
        <div class="gold-rate">{shot['gold_rate']}</div>
      </div>
    </div>

    <!-- Era progress -->
    <div class="era-bar-wrap">
      <div class="era-name">{shot['era_label']}</div>
      <div class="prog-track"><div class="prog-fill"></div></div>
      <div class="era-pct">{shot['era_pct']}%</div>
    </div>

    <!-- Main content -->
    {content_block}

    <!-- Headline -->
    <div class="headline-block">
      <div class="headline">{shot['headline']}</div>
      <div class="subhead">{shot['subhead']}</div>
    </div>

    <!-- Brand -->
    <div class="brand">
      <div class="brand-dot"></div>
      <div class="brand-name">IDLE CIVILIZATIONS</div>
      <div class="brand-dot"></div>
    </div>
  </div>
</body>
</html>"""


def generate_for_game(game_id: str):
    game = load_game(game_id)
    artworks_dir = REPO_ROOT / "artworks"
    xcassets_dir = REPO_ROOT / "apps/IdleCivilizations/Resources/Assets.xcassets"

    from playwright.sync_api import sync_playwright

    total = 0
    with sync_playwright() as p:
        browser = p.chromium.launch()

        for device_name, (w, h) in DEVICES.items():
            out_dir = REPO_ROOT / game["metadata_path"] / "screenshots" / "en-US" / device_name
            out_dir.mkdir(parents=True, exist_ok=True)

            for shot in SCREENSHOTS:
                html = build_html(shot, w, h, artworks_dir, xcassets_dir)
                out_path = out_dir / f"{shot['filename']}.png"

                page = browser.new_page(viewport={"width": w, "height": h}, device_scale_factor=1)
                page.set_content(html, wait_until="networkidle")
                page.screenshot(path=str(out_path), full_page=False, clip={"x": 0, "y": 0, "width": w, "height": h})
                page.close()

                print(f"  ✓ {device_name}/{shot['filename']}.png  ({w}×{h})")
                total += 1

        browser.close()

    print(f"\n✓ Generated {total} screenshots")
    print(f"  → {REPO_ROOT / game['metadata_path'] / 'screenshots'}/")


def main():
    parser = argparse.ArgumentParser(description="Generate App Store screenshots via HTML+Playwright")
    parser.add_argument("--game", required=True, help="Game ID from config/games.yml")
    args = parser.parse_args()
    generate_for_game(args.game)


if __name__ == "__main__":
    main()
