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

Erlaubte Endungen: `png`, `svg`, `jpg`, `webp`. Das Seitenverhältnis ist egal —
das Logo wird eingepasst, nicht verzerrt: die längere Kante füllt das Feld, die
kürzere sitzt mittig. 256 Pixel an der längeren Kante reichen vollkommen, das
Spiel zeigt die Wappen zwischen 16 und 50 Pixeln an und verkleinert mit
Mipmaps, damit nichts flimmert.

Wichtig ist der **transparente Hintergrund** und dass das Logo auf dunklem
Grund lesbar bleibt. Ein Logo, das für weißes Papier gezeichnet wurde — dunkle
Linien ohne Fläche — verschwindet in der Oberfläche. Solche Logos vorher mit
einer hellen Fläche hinterlegen.

Für welche Vereine ein Logo fehlt, ist unproblematisch: dort wird weiterhin
das gezeichnete Wappen aus Vereinsfarben und Kürzel benutzt.

## Eigene Schrift — `assets/schrift/`

Die Engine bringt genau einen Schriftschnitt mit. Das Spiel fettet ihn bei
Bedarf synthetisch nach, aber nur sehr maßvoll: Godot versetzt dafür die
Kontur nach außen, und ab etwa 0.08 überschneidet sie sich mit sich selbst —
dann bekommen große Zahlen Sporne an den Ecken und zugelaufene Punzen. Für
einen echten Fettschnitt braucht es eine Datei.

```
assets/schrift/normal.ttf     → Grundschrift
assets/schrift/halbfett.ttf   → Werte, Knöpfe, Spielernamen, Etiketten
assets/schrift/fett.ttf       → Überschriften und große Zahlen
```

Erlaubte Endungen: `ttf`, `otf`, `woff2`, `woff`. Liegt eine Datei da, wird die
synthetische Fettung für diesen Schnitt abgeschaltet — sie wäre dann nicht nur
überflüssig, sondern schädlich. Fehlt eine Datei, bleibt es beim
Engine-Schnitt. Gut geeignet sind Schriften mit klaren Ziffern und schmalen
Punzen, etwa Inter, Barlow oder Archivo.

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
