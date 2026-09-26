#!/usr/bin/env python3
"""Schreibt daten/PRUEFLISTE.md: alles, was im Datensatz als ungeprüft markiert
ist oder ganz fehlt. Aufruf aus dem Projektordner: python3 werkzeuge/pruefliste.py"""
import json, collections

L = json.load(open("daten/ligen.json", encoding="utf-8"))
K = json.load(open("daten/kader.json", encoding="utf-8"))["kader"]
S = json.load(open("daten/schiedsrichter.json", encoding="utf-8"))
P = json.load(open("daten/spielplan.json", encoding="utf-8"))["spielplaene"]

z = ["# Prüfliste zum Datensatz", "",
     "Erzeugt von `werkzeuge/pruefliste.py`. Was hier steht, ist entweder nach",
     "Wissensstand eingetragen (`\"geprueft\": false`) oder fehlt noch ganz. Nach dem",
     "Prüfen im Datensatz `geprueft` löschen und das Skript neu laufen lassen.", ""]

z += ["## Ligen ohne vollständigen Spielplan", ""]
for n in L["nationen"]:
    for l in n["ligen"]:
        teams = max(len(l.get("vereine", [])), l.get("teams", 0))
        soll = teams * (teams - 1)
        ist = len(P.get(l["name"], {}).get("partien", []))
        if ist < soll:
            z.append("- %s (%s): %d von %d Partien" % (l["name"], n["name"], ist, soll))
z.append("")

z += ["## Vereine ohne echte Spieler", ""]
for n in L["nationen"]:
    for l in n["ligen"]:
        leer = [v["name"] for v in l.get("vereine", []) if len(K.get(v["name"], [])) == 0]
        if leer:
            z.append("- **%s:** %s" % (l["name"], ", ".join(leer)))
z.append("")

z += ["## Vereine mit wenigen echten Spielern (unter 14 — der Rest wird erfunden)", ""]
for n in L["nationen"]:
    for l in n["ligen"]:
        for v in l.get("vereine", []):
            k = len(K.get(v["name"], []))
            if 0 < k < 14:
                z.append("- %s: %d" % (v["name"], k))
z.append("")

z += ["## Trainer", "", "Ohne Eintrag erfindet das Spiel einen.", ""]
ohne, unsicher = [], []
for n in L["nationen"]:
    for l in n["ligen"]:
        if l["stufe"] != 1:
            continue
        for v in l.get("vereine", []):
            t = v.get("trainer")
            if not t:
                ohne.append(v["name"])
            elif isinstance(t, dict) and t.get("geprueft") is False:
                unsicher.append("%s (%s %s)" % (v["name"], t.get("vorname", ""), t.get("nachname", "")))
z.append("**Ungeprüft:** " + (", ".join(unsicher) or "—"))
z.append("")
z.append("**Fehlen (erste Ligen):** " + (", ".join(ohne) or "—"))
z.append("")

z += ["## Ungeprüfte Spieler", ""]
je = collections.defaultdict(list)
for verein, liste in K.items():
    for s in liste:
        if s.get("geprueft") is False:
            je[verein].append("%s %s (%s)" % (s["vorname"], s["nachname"], s["position"]))
for verein in sorted(je):
    z.append("- **%s:** %s" % (verein, ", ".join(je[verein])))
z.append("")

z += ["## Ungeprüfte Schiedsrichter", ""]
for g in S["gespanne"]:
    if g.get("geprueft") is False:
        z.append("- %s / %s (%s)" % (g["a"], g["b"], g["nation"]))
z.append("")

z += ["## Felder, die noch niemand befüllt hat", "",
      "Das Spiel liest sie, der Datensatz hat sie aber (fast) nirgends:", ""]
zaehl = collections.Counter()
for liste in K.values():
    for s in liste:
        for f in ("geburtsdatum", "hand", "groesse", "gewicht", "vertrag_bis", "gehalt", "verletzt", "kapitaen", "zweitpositionen"):
            if f in s:
                zaehl[f] += 1
gesamt = sum(len(l) for l in K.values())
for f in ("geburtsdatum", "hand", "groesse", "gewicht", "vertrag_bis", "gehalt", "verletzt", "kapitaen", "zweitpositionen"):
    z.append("- `%s`: %d von %d Spielern" % (f, zaehl[f], gesamt))
vz = collections.Counter()
nv = 0
for n in L["nationen"]:
    for l in n["ligen"]:
        for v in l.get("vereine", []):
            nv += 1
            for f in ("etat", "sponsoren", "zuschauerschnitt", "stab"):
                if f in v:
                    vz[f] += 1
for f in ("etat", "sponsoren", "zuschauerschnitt", "stab"):
    z.append("- `vereine[].%s`: %d von %d Vereinen" % (f, vz[f], nv))
z.append("")
open("daten/PRUEFLISTE.md", "w", encoding="utf-8").write("\n".join(z))
print("daten/PRUEFLISTE.md geschrieben")
