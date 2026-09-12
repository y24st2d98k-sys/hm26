# Eigene Bilder und Klänge

Hallenherz kommt ohne eine einzige Mediendatei aus — alles wird zur Laufzeit
gezeichnet und synthetisiert. Wer eigene Dateien einsetzen möchte, legt sie
hier ab. Das Spiel bevorzugt dann die Datei und fällt auf die eingebaute
Variante zurück, wo keine liegt. Es muss nichts am Code geändert werden.

## Vereinslogos — `assets/wappen/`

Dateiname ist das **Kürzel des Vereins**, so wie es in `daten/ligen.json` unter
`"kurz"` steht:

```
assets/wappen/SCM.png     → SC Magdeburg
assets/wappen/THW.png     → THW Kiel
assets/wappen/PSG.png     → Paris Saint-Germain Handball
```

Erlaubte Endungen: `png`, `svg`, `jpg`, `webp`. Quadratisch und mit
transparentem Hintergrund sieht am besten aus; 256 × 256 Pixel reichen
vollkommen, das Spiel zeigt die Wappen zwischen 16 und 50 Pixeln an.

Für welche Vereine ein Logo fehlt, ist unproblematisch: dort wird weiterhin
das gezeichnete Wappen aus Vereinsfarben und Kürzel benutzt.

## Klänge — `assets/klang/`

Dateiname ist der Name des Klangs. Erlaubte Endungen: `ogg`, `wav`, `mp3`.

| Datei | Wann er läuft |
|---|---|
| `anpfiff` | Anpfiff einer Partie |
| `pfiff` | Zeitstrafe, Siebenmeter, Auszeit, Halbzeit |
| `tor` | Tor der eigenen Mannschaft |
| `tor_gegen` | Gegentor |
| `parade` | Parade des eigenen Torwarts |
| `raunen` | Parade des gegnerischen Torwarts |
| `ball` | technischer Fehler, Block |
| `sirene` | Schlusssirene |
| `klick` | Knopfdruck |
| `blaettern` | Wechsel des Bildschirms |
| `atmo` | Hallenatmosphäre, läuft während der Partie in Schleife |
| `musik` | Menümusik, läuft in Schleife |

`atmo` und `musik` sollten sauber schleifenfähig sein (Anfang und Ende
gleich laut, kein Knacks). Die Lautstärke der Atmosphäre steuert das Spiel
selbst über den Hallenpuls — die Datei also gleichmäßig laut anlegen und nicht
selbst ein- und ausblenden.

Alles läuft über zwei Audiobusse: **Halle** (Nachhall, leichte Höhenabsenkung)
für alle Spielgeräusche und **Musik** (wenig Raum, Kompression). Wer trockene
Aufnahmen einsetzt, bekommt den Hallenklang also geschenkt.

## Rechtliches

Die mitgelieferten Wappen sind gezeichnet und enthalten keine fremden Marken.
Wer echte Vereinslogos einsetzt, sollte das nur für den privaten Gebrauch tun —
für eine Veröffentlichung wären Namens- und Markenrechte zu klären. Dasselbe
gilt für Klangdateien: bitte nur eigene Aufnahmen oder solche unter einer
Lizenz, die die Nutzung erlaubt.
