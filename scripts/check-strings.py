#!/usr/bin/env python3
"""Falla si alguna cadena del catálogo no tiene traducción a todos los idiomas.

Uso: scripts/check-strings.py [idioma ...]   (por defecto: en)
"""
import json
import sys
from pathlib import Path

CATALOGS = ["Anotador/Localizable.xcstrings", "Anotador/InfoPlist.xcstrings"]
languages = sys.argv[1:] or ["en"]
root = Path(__file__).resolve().parent.parent
problems = []

for relative in CATALOGS:
    catalog = json.loads((root / relative).read_text(encoding="utf-8"))
    for key, entry in catalog["strings"].items():
        if entry.get("shouldTranslate") is False or entry.get("extractionState") == "stale":
            continue
        localizations = entry.get("localizations", {})
        for language in languages:
            unit = localizations.get(language, {})
            if "stringUnit" in unit:
                ok = unit["stringUnit"].get("state") == "translated"
            elif "variations" in unit:
                ok = True
            else:
                ok = False
            if not ok:
                problems.append(f"{relative}: falta '{language}' para: {key}")

if problems:
    print("\n".join(problems))
    print(f"\n{len(problems)} traducciones pendientes.")
    sys.exit(1)
print(f"Catálogos completos para: {', '.join(languages)}")
