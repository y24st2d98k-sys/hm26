# Datensatz

Alles, was die Wirklichkeit vorgibt, steht hier — nicht im Code. Das Spiel liest
diese Dateien beim Anlegen einer neuen Karriere und **erfindet alles, was fehlt**.
Ein unvollständiger Datensatz führt also nie zu einer kaputten Welt, sondern nur
zu mehr erfundenen Spielern.

Zum Prüfen, wie weit die echten Daten reichen:

```bash
godot4 --headless res://werkzeuge/Datenbericht.tscn
```

---

## `ligen.json` — Nationen, Ligen, Vereine

```json
{
  "version": 1,
  "stand": "September 2026",
  "nationen": [
    {
      "id": "de", "name": "Deutschland",
      "ruf": 94, "reichtum": 1.0,
      "pokal": "DHB-Pokal", "supercup": "Super Cup",
      "ligen": [
        {
          "id": "l_de1", "name": "Handball-Bundesliga", "kurz": "HBL",
          "stufe": 1, "ruf": 90,
          "vereine": [
            {
              "name": "THW Kiel", "kurz": "THW", "ort": "Kiel",
              "gegruendet": 1904,
              "halle": "Wunderino Arena", "kapazitaet": 10285,
              "farben": ["#000000", "#ffffff"],
              "ruf": 91
            }
          ]
        }
      ]
    }
  ]
}
```

| Feld | Bedeutung |
|---|---|
| `nationen[].ruf` | Ansehen der Nation (0–100). Beeinflusst Startplätze im Europapokal. |
| `nationen[].reichtum` | Wirtschaftskraft (1.0 = deutsches Niveau). Skaliert alle Etats. |
| `ligen[].stufe` | 1 = oberste Spielklasse, 2 = Unterhaus. Auf- und Abstieg läuft zwischen Stufe 1 und 2 derselben Nation. |
| `ligen[].ruf` | Ansehen der Liga. Bestimmt Medienerlöse und Preisgelder. |
| `ligen[].teams` | Nur nötig, wenn `vereine` leer ist — dann erfindet das Spiel so viele Vereine. |
| `ligen[].erzeugt` | Nur Kennzeichnung für den Datenbericht. |
| `vereine[].ruf` | Ansehen des Vereins (0–100). **Der wichtigste Wert:** er bestimmt Kaderstärke, Etat, Hallenpuls und die Erwartung des Vorstands. |
| `vereine[].farben` | Zwei Hex-Farben für das prozedural gezeichnete Wappen. |

Fehlende Felder werden ergänzt: ohne `halle` erfindet das Spiel einen Hallennamen,
ohne `kapazitaet` leitet es sie aus dem Ruf ab, und so weiter. Zwingend ist nur `name`.

**Eine Liga hinzufügen:** einen Eintrag in `ligen` anlegen. Hat sie keine
`vereine`, reicht `"teams": 12` — das Spiel erfindet sie.

---

## `kader.json` — echte Spieler

```json
{
  "version": 1,
  "stand": "September 2026",
  "kader": {
    "THW Kiel": [
      {"nummer": 33, "vorname": "Andreas", "nachname": "Wolff", "position": "TW",
       "nation": "de", "alter": 35, "staerke": 90}
    ]
  }
}
```

Der Schlüssel ist der **exakte Vereinsname** aus `ligen.json`.

| Feld | Bedeutung |
|---|---|
| `nummer` | Rückennummer. Weglassen oder `0` setzen, dann vergibt das Spiel eine freie. |
| `position` | `TW`, `LA`, `RL`, `RM`, `RR`, `RA` oder `KM` |
| `nation` | Kürzel wie in `Namen.KULTUR_NAME` (`de`, `dk`, `is`, `hr`, `fo`, …) |
| `alter` | Alter zum Karrierestart |
| `staerke` | Gesamtstärke 0–100. Das Spiel würfelt die Einzelattribute passend zur Position aus und rechnet sie so zurecht, dass dieser Wert getroffen wird. |
| `attribute` | Einzelne Attribute festschreiben, statt sie auswürfeln zu lassen. Siehe unten. |
| `stammschuetze` | `true` heißt: dieser Spieler wirft die Siebenmeter seines Vereins, solange er auf dem Feld steht. |

### Einzelne Attribute festschreiben

```json
{"nummer": 7, "vorname": "Kai", "nachname": "Häfner", "position": "RR",
 "nation": "de", "alter": 36, "staerke": 84,
 "stammschuetze": true,
 "attribute": {"siebenmeter": 15.6, "nervenstaerke": 17}}
```

Erlaubt ist jeder Attributname aus `Spielerfabrik.ATTR_LABEL` — die Technik-,
Athletik-, Abwehr- und Mentalwerte der Feldspieler und die acht Torwartwerte.
Werte von 1 bis 20.

**Sparsam setzen.** Was nicht dasteht, würfelt das Spiel aus der Zielstärke
aus, und genau diese Streuung macht aus zwei gleich starken Spielern zwei
verschiedene. Festschreiben lohnt sich für das eine Merkmal, das einen Spieler
ausmacht — der Siebenmeterspezialist, der Abwehrchef, der Torwart mit der
außergewöhnlichen Fußabwehr —, nicht für alle zwanzig.

`stammschuetze` und `attribute.siebenmeter` gehören zusammen, sagen aber
Verschiedenes: das eine, **wer** wirft, das andere, **wie gut** er trifft. Ohne
diese Trennung müsste man den Attributwert hochdrehen, damit der Richtige
antritt, und behauptete damit eine Trefferquote, die nicht stimmt.

### Ein neuer Datensatz erreicht laufende Karrieren

Wer `kader.json` austauscht, muss keine Karriere neu anfangen. Beim nächsten
Laden vergleicht der Spielstand seinen Datenstand mit dem der Dateien und zieht
nach, was sich geändert hat.

Dabei wird **verschoben, nicht gesetzt**: steigt eine Stärke im Datensatz von
78 auf 84, gewinnt der Spieler sechs Punkte auf seinen jetzigen Wert. Wer sich
im Spiel von 78 auf 82 entwickelt hat, steht danach bei 88 — die Entwicklung
aus dem Spiel bleibt also drin. Einzelne `attribute` gelten dagegen
unmittelbar, denn wer einen Wert von Hand setzt, meint genau diesen Wert.
Position, Rückennummer und Siebenmeterschütze werden übernommen.

Damit der Abgleich anspringt, muss `stand` in der Datei sich ändern — er ist
das Kennzeichen, an dem der Spielstand erkennt, dass etwas Neues vorliegt.
Zugeordnet wird über Vor- und Nachnamen; zwei gleichnamige Spieler bleiben
außen vor, weil sich nicht entscheiden ließe, wer gemeint ist.

Geprüft wird das von `werkzeuge/Datenabgleichtest.tscn`.

Grobe Einordnung für `staerke`: 90+ Weltklasse, 80–89 Nationalmannschaft,
70–79 Erstligastammspieler, 60–69 Ergänzung, unter 55 Talent oder Zweitliga.

Jeder Kader wird auf Sollstärke aufgefüllt (3 Torhüter, 2 Außen je Seite,
3 Rückraum je Position, 3 Kreis). Erfundene Ergänzungsspieler bleiben bewusst
unter der Stärke des besten echten Spielers, damit sie die Leistungsträger nicht
überstrahlen. Im Spielerfenster sind sie mit **ERFUNDEN** gekennzeichnet.

---

## Wie genau ist das hier?

* **Verlässlich:** Vereinsnamen, Ligazugehörigkeit und Ligagrößen der Saison 2026/27.
* **Näherung:** Hallennamen, Kapazitäten, Gründungsjahre, Vereinsfarben, alle Ruf-Werte.
* **Vollständig:** die Kader aller 18 Bundesligisten — 327 Spieler, kein einziger
  ergänzt. Wer im Spiel für einen deutschen Erstligisten auf dem Bogen steht, steht
  dort auch in Wirklichkeit.
* **Lückenhaft:** alle übrigen Ligen. Dort sind nur einzelne Spieler hinterlegt,
  den Rest füllt das Spiel auf.
* **Schätzwerte, keine Tatsachenbehauptungen:** Alter und Stärke. Das Alter ist zum
  1. September 2026 gerechnet, die Stärke ordnet einen Spieler nur für die
  Simulation ein.

Kader veralten mit jedem Transferfenster. Die Dateien sind bewusst so einfach
gehalten, dass sie sich ohne Programmierkenntnisse pflegen lassen.

---

## Rechtliches

Vereins- und Personennamen sind hier zu dem Zweck erfasst, ein privates Spiel
realistisch zu machen. Für eine Veröffentlichung des Spiels wären Namens- und
Markenrechte zu klären. Wer das vermeiden will, startet eine Karriere mit
abgehaktem Häkchen "Echte Vereine" — dann erzeugt das Spiel wie zuvor eine
vollständig erfundene Welt.
