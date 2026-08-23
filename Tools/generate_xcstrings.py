#!/usr/bin/env python3
"""Generates REBOOT/Localizable.xcstrings (EN/FR/ES/DE/IT).

Keys are the canonical English source strings. English state is omitted from
each entry on purpose: with one language present, String Catalogs treat the
key itself as the source/fallback, and missing translations resolve to the
readable English key at runtime instead of a raw identifier.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reboot_strings import STRINGS  # noqa: E402

LANGS = ["fr", "es", "de", "it"]


def build_catalog() -> dict:
    strings = {}
    for en, translations in sorted(STRINGS.items()):
        entry = {
            "extractionState": "manual",
        }
        localizations = {}
        for lang in LANGS:
            value = translations.get(lang)
            if value:
                localizations[lang] = {
                    "stringUnit": {"state": "translated", "value": value}
                }
        if localizations:
            entry["localizations"] = localizations
        strings[en] = entry
    return {
        "sourceLanguage": "en",
        "strings": strings,
        "version": "1.0",
    }


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_path = os.path.join(root, "REBOOT", "Localizable.xcstrings")
    catalog = build_catalog()
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, sort_keys=False)
        f.write("\n")
    print(f"wrote {out_path} with {len(catalog['strings'])} keys")


if __name__ == "__main__":
    main()
