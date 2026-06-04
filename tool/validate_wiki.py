#!/usr/bin/env python3
"""Validate folder-based wiki packs: manifest, articles, SVG label JSON."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WIKI_DIR = ROOT / "assets" / "wiki"
MANIFEST_PATH = WIKI_DIR / "manifest.yaml"
PLACEHOLDER_RE = re.compile(r"\{\{([\w_]+)\}\}")
LOCALE_DIRS = ("en", "de", "fr", "es", "el", "zh", "ar")

# Flutter only bundles immediate children of a declared folder; locale subdirs must
# be listed explicitly in pubspec.yaml (see flutter.dev asset docs).
_REQUIRED_PUBSPEC_ASSET_PREFIXES = tuple(
    f"assets/wiki/{locale}/" for locale in LOCALE_DIRS
) + tuple(f"assets/wiki/{locale}/svg/" for locale in LOCALE_DIRS)


def load_manifest() -> tuple[list[str], list[dict]]:
    articles: list[str] = []
    svg_assets: list[dict] = []
    section: str | None = None
    current: dict | None = None
    for line in MANIFEST_PATH.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped == "articles:":
            section = "articles"
            continue
        if stripped == "svg_assets:":
            section = "svg_assets"
            continue
        if section == "articles" and stripped.startswith("- "):
            articles.append(stripped[2:].strip())
        elif section == "svg_assets":
            if stripped.startswith("- id:"):
                if current:
                    svg_assets.append(current)
                current = {"id": stripped.split(":", 1)[1].strip()}
            elif current is not None and ":" in stripped:
                key, val = stripped.split(":", 1)
                current[key.strip()] = val.strip()
    if current:
        svg_assets.append(current)
    return articles, svg_assets


def svg_placeholders(svg_path: Path) -> set[str]:
    text = svg_path.read_text(encoding="utf-8")
    return set(PLACEHOLDER_RE.findall(text))


def load_label_keys(labels_path: Path) -> set[str]:
    if not labels_path.exists():
        return set()
    data = json.loads(labels_path.read_text(encoding="utf-8"))
    return set(data.keys())


def main() -> int:
    errors: list[str] = []
    if not MANIFEST_PATH.exists():
        print("missing manifest.yaml", file=sys.stderr)
        return 1

    article_ids, svg_assets = load_manifest()
    if not article_ids:
        errors.append("manifest has no articles")

    pubspec_text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    for prefix in _REQUIRED_PUBSPEC_ASSET_PREFIXES:
        needle = f"- {prefix}"
        if needle not in pubspec_text:
            errors.append(
                f"pubspec.yaml missing asset entry '{needle}' "
                "(required for Flutter to bundle wiki locale files)"
            )

    en_dir = WIKI_DIR / "en"
    for aid in article_ids:
        if not (en_dir / f"{aid}.md").exists():
            errors.append(f"en missing article: {aid}.md")

    for locale in LOCALE_DIRS:
        locale_dir = WIKI_DIR / locale
        if not locale_dir.is_dir():
            errors.append(f"missing locale folder: {locale}")
            continue
        for md in locale_dir.glob("*.md"):
            if md.stem not in article_ids:
                errors.append(f"{locale}: unknown article {md.name}")
        for aid in article_ids:
            localized = locale_dir / f"{aid}.md"
            fallback = en_dir / f"{aid}.md"
            if not localized.exists() and not fallback.exists():
                errors.append(f"{locale}: no {aid}.md and no en fallback")

    for entry in svg_assets:
        asset = entry.get("asset", "")
        labels_rel = entry.get("labels", "")
        svg_path = ROOT / asset
        if not svg_path.exists():
            errors.append(f"svg asset missing: {asset}")
            continue
        required = svg_placeholders(svg_path)
        en_labels = WIKI_DIR / "en" / labels_rel
        en_keys = load_label_keys(en_labels)
        missing_en = required - en_keys
        if missing_en:
            errors.append(f"en {labels_rel} missing keys: {sorted(missing_en)}")
        for locale in LOCALE_DIRS:
            labels_path = WIKI_DIR / locale / labels_rel
            keys = load_label_keys(labels_path) or en_keys
            missing = required - keys
            if missing:
                errors.append(
                    f"{locale}: {labels_rel} missing keys (no en fallback): {sorted(missing)}"
                )

    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 1

    print(
        f"OK: {len(article_ids)} articles, {len(svg_assets)} svg_assets, "
        f"{len(LOCALE_DIRS)} locales"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
