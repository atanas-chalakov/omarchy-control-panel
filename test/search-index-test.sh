#!/usr/bin/env bash
# Automated test verifying Search View indexing, quick tiles, and category mapping consistency

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command python3

python3 - "$ROOT" <<'PY'
import sys, re
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
cp_qml = (root / "ControlPanel.qml").read_text()
search_qml = (root / "views/SearchView.qml").read_text()

# 1. Parse ControlPanel categories
cp_cat_ids = set(re.findall(r'id:\s*"([a-z0-9_-]+)",\s*label:', cp_qml))
assert len(cp_cat_ids) >= 16, f"Expected >= 16 categories in ControlPanel, found {len(cp_cat_ids)}"

# 2. Parse quickTiles in SearchView
tiles = re.findall(r'categoryId:\s*"([a-z0-9_-]+)",\s*cardIndex:\s*(\d+)', search_qml)
assert len(tiles) >= 8, f"Expected >= 8 quickTiles, found {len(tiles)}"
for cat, idx in tiles:
    assert cat in cp_cat_ids, f"QuickTile category '{cat}' is not in ControlPanel categories"

print(f"Verified {len(tiles)} quick tiles have valid category IDs")

# 3. Parse settingsIndex in SearchView
# Match objects with title, categoryId, cardIndex, desc, keywords
raw_items = re.findall(
    r'\{\s*title:\s*"([^"]+)",\s*categoryId:\s*"([^"]+)",\s*categoryName:\s*"([^"]+)",\s*categoryIcon:\s*"([^"]+)",\s*cardIndex:\s*(\d+),\s*desc:\s*"([^"]+)",\s*keywords:\s*"([^"]+)"\s*\}',
    search_qml
)

assert len(raw_items) >= 30, f"Expected >= 30 indexed settings in SearchView, found {len(raw_items)}"

indexed_cats = set()
for title, cat_id, cat_name, icon, card_idx, desc, keywords in raw_items:
    assert cat_id in cp_cat_ids, f"Indexed setting '{title}' has invalid categoryId '{cat_id}'"
    assert int(card_idx) >= 0, f"Indexed setting '{title}' has invalid cardIndex {card_idx}"
    assert len(desc) > 5, f"Indexed setting '{title}' has missing/short description"
    assert len(keywords) > 3, f"Indexed setting '{title}' has missing/short keywords"
    indexed_cats.add(cat_id)

print(f"Verified {len(raw_items)} indexed settings across {len(indexed_cats)} categories")

# Ensure all non-search categories are covered in search
non_search_cats = cp_cat_ids - {"search"}
missing_from_search = non_search_cats - indexed_cats
assert not missing_from_search, f"Categories missing from search index: {missing_from_search}"

# 4. Test quick chips query matching
quick_chips = re.findall(r'query:\s*"([a-z0-9_-]+)"', search_qml)
assert len(quick_chips) >= 6, f"Expected >= 6 quick chips, found {len(quick_chips)}"
for q in quick_chips:
    matched = [title for title, cat_id, cat_name, icon, card_idx, desc, keywords in raw_items
               if q in title.lower() or q in desc.lower() or q in keywords.lower()]
    assert len(matched) > 0, f"Quick chip query '{q}' does not match any indexed settings"

print(f"Verified {len(quick_chips)} quick chips match indexed settings")
PY

pass "SearchView quick tiles reference valid ControlPanel categories"
pass "SearchView index contains comprehensive, valid entries for all categories"
pass "SearchView quick chips queries successfully match indexed settings"
