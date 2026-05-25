#!/usr/bin/env python3
"""One-time migration: wiki_pack_<locale>.json -> locale/*.md + locale/svg/*.json."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WIKI_DIR = ROOT / "assets" / "wiki"
TRANSLATIONS_DIR = ROOT / "assets" / "translations"
LOCALES = ("en", "de", "fr", "es", "el", "zh", "ar")
CPR_IMG_PREFIX = "cpr_img_"
SVG_LABEL_FILE = "svg/cpr_compressions.json"


def escape_yaml(value: str) -> str:
    if "\n" in value or ":" in value or value.startswith(("#", "-", "[")):
        return json.dumps(value, ensure_ascii=False)
    return value


def article_to_md(article: dict) -> str:
    title = article["title"]
    summary = article.get("summary") or ""
    body = article["bodyMarkdown"]
    return (
        f"---\n"
        f"title: {escape_yaml(title)}\n"
        f"summary: {escape_yaml(summary)}\n"
        f"---\n"
        f"{body}\n"
    )


def extract_cpr_img_keys(translations: dict) -> dict[str, str]:
    return {
        k: v
        for k, v in translations.items()
        if k.startswith(CPR_IMG_PREFIX) and isinstance(v, str)
    }


def main() -> None:
    en_pack_path = WIKI_DIR / "wiki_pack_en.json"
    en_data = json.loads(en_pack_path.read_text(encoding="utf-8"))
    article_ids = [a["id"] for a in en_data["articles"]]

    manifest = {
        "articles": article_ids,
        "svg_assets": [
            {
                "id": "cpr_compressions",
                "asset": "assets/images/cpr_compressions.svg",
                "labels": SVG_LABEL_FILE,
            }
        ],
    }
    (WIKI_DIR / "manifest.yaml").write_text(
        "articles:\n"
        + "".join(f"  - {aid}\n" for aid in article_ids)
        + "svg_assets:\n"
        + "  - id: cpr_compressions\n"
        + "    asset: assets/images/cpr_compressions.svg\n"
        + f"    labels: {SVG_LABEL_FILE}\n",
        encoding="utf-8",
    )

    for locale in LOCALES:
        pack_path = WIKI_DIR / f"wiki_pack_{locale}.json"
        if not pack_path.exists():
            print(f"skip missing pack: {pack_path}")
            continue
        pack = json.loads(pack_path.read_text(encoding="utf-8"))
        locale_dir = WIKI_DIR / locale
        locale_dir.mkdir(parents=True, exist_ok=True)
        svg_dir = locale_dir / "svg"
        svg_dir.mkdir(parents=True, exist_ok=True)

        for article in pack["articles"]:
            md_path = locale_dir / f"{article['id']}.md"
            md_path.write_text(article_to_md(article), encoding="utf-8")

        trans_path = TRANSLATIONS_DIR / f"{locale}.json"
        if trans_path.exists():
            translations = json.loads(trans_path.read_text(encoding="utf-8"))
            labels = extract_cpr_img_keys(translations)
            if labels:
                (svg_dir / "cpr_compressions.json").write_text(
                    json.dumps(labels, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8",
                )
        print(f"migrated {locale}: {len(pack['articles'])} articles")

    print(f"manifest: {len(article_ids)} articles")


if __name__ == "__main__":
    main()
