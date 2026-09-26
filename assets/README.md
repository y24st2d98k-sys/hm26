# Eigene Bilder und Klänge

Hallenherz braucht keine einzige Mediendatei — alles kann zur Laufzeit
gezeichnet und synthetisiert werden. Wer eigene Dateien einsetzen möchte, legt sie
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

Für 135 Vereine liegen bereits echte Logos bei (aus Wikipedia-Infoboxen,
Sportradar über sport1.de und den Ligaseiten). Woher jedes einzelne stammt,
steht in [`WAPPEN_QUELLEN.md`](WAPPEN_QUELLEN.md).

## Spielergesichter — `assets/gesichter/`

Das Spiel zeichnet jedes Gesicht selbst. Wer für echte Spieler echte Fotos
möchte, legt sie hier ab:

```
assets/gesichter/kai_haefner.png
assets/gesichter/gisli_thorgeir_kristjansson.png
```

Der Dateiname ist **Vor- und Nachname, kleingeschrieben, ohne Umlaute und
Sonderzeichen**, Leerzeichen und Bindestriche werden zu Unterstrichen:

| Spieler | Datei |
|---|---|
| Kai Häfner | `kai_haefner` |
| Gísli Þorgeir Kristjánsson | `gisli_thorgeir_kristjansson` |
| Petter Øverby | `petter_oeverby` |
| Nikolaj Læsø | `nikolaj_laesoe` |
| Elias Ellefsen á Skipagøtu | `elias_ellefsen_a_skipagoetu` |
| Fynn-Luca Nicolaus | `fynn_luca_nicolaus` |

Erlaubte Endungen: `png`, `jpg`, `webp`. Wer den Namen nicht treffen will oder
zwei gleichnamige Spieler hat, setzt in `daten/kader.json` das Feld `bild`:

```json
{"vorname": "Max", "nachname": "Müller", "bild": "max_mueller_kiel", …}
```

Das Bild wird **rund beschnitten, nicht gestaucht**: die kürzere Kante füllt
den Kreis, oben wird etwas großzügiger stehen gelassen als unten, weil dort der
Kopf sitzt. Hochformat, Quadrat und Breitformat funktionieren also alle.
Portraits von 256 bis 512 Pixel reichen; das Spiel zeigt sie zwischen 20 und
96 Pixeln und verkleinert mit Mipmaps.

Für wen kein Foto daliegt, wird weiterhin gezeichnet — beides steht problemlos
nebeneinander im selben Kader. Zwei Probebilder (`_probe_hoch`,
`_probe_quadrat`) liegen bei; sie gehören zu `werkzeuge/Gesichtertest.tscn`
und tragen bewusst keinen Spielernamen.

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

## Rechtliches

Die mitgelieferten Wappen und Gesichter sind gezeichnet und enthalten keine
fremden Marken. Wer echte Vereinslogos einsetzt, sollte das nur für den
privaten Gebrauch tun — für eine Veröffentlichung wären Namens- und
Markenrechte zu klären. Für Spielerfotos gilt das doppelt: an einem Portrait
hängen neben dem Urheberrecht des Fotografen auch die Persönlichkeitsrechte
des Abgebildeten. Dasselbe
gilt für Klangdateien: bitte nur eigene Aufnahmen oder solche unter einer
Lizenz, die die Nutzung erlaubt.
