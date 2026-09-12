# HALLENHERZ

Ein Handball-Manager für Godot 4.x. Deutschsprachige Oberfläche, vollständig
prozedural erzeugte Grafik (keine einzige Bilddatei), ein zentraler Spielzustand
und eine Simulation, die den Sport ernst nimmt: Zeitstrafen erzeugen echte
Unterzahl, Abwehr und Angriff sind zwei getrennte Aufstellungen, und wer den
Torwart für das 7-gegen-6 herausnimmt, riskiert den Ball im leeren Tor.

---

## Starten

Godot 4.3 oder neuer. Getestet mit **4.3** und **4.7.2**.

Projektordner in Godot öffnen (oder `project.godot` anklicken) und auf Play
drücken. Beim ersten Öffnen importiert Godot das Projekt kurz.

```bash
godot4 --path .            # Spiel starten
```

Zum Prüfen ohne Editor:

```bash
godot4 --headless res://werkzeuge/Kaltstarttest.tscn           # Start ohne Spielstand
godot4 --headless res://werkzeuge/Datenbericht.tscn            # Abdeckung der echten Daten
godot4 --headless res://werkzeuge/Testlauf.tscn -- welt        # Weltgenerierung
godot4 --headless res://werkzeuge/Testlauf.tscn -- spiele      # 300 Partien, Kennzahlen
godot4 --headless res://werkzeuge/Testlauf.tscn -- halbsaison  # halbe Saison
godot4 --headless res://werkzeuge/Testlauf.tscn -- langzeit    # drei Saisons am Stück
godot4 --headless res://werkzeuge/Oberflaechentest.tscn        # alle Bildschirme + Live-Spiel + Speichern
godot4 --headless res://werkzeuge/Pruefung.tscn -- 740          # Integritätsprüfung über zwei Saisons
godot4 --headless res://werkzeuge/Testlauf.tscn -- rollen        # Verteilung der Rollenvorschläge
godot4 --headless res://werkzeuge/Testlauf.tscn -- wirkung       # Wirkung jeder Spieleranweisung
```

Die **Prüfung** ist der schärfste dieser Tests: Sie simuliert eine ganze Saison
und misst danach harte Zusagen der Welt — Ligagrößen bleiben konstant, jeder
Verein hat einen Torwart und sieben einsatzfähige Spieler, kein Spieler steht in
zwei Kadern, keine Aufstellung zeigt auf jemanden, der nicht im Kader ist, jede
Rückennummer gibt es nur einmal, jede Liga spielt eine vollständige Doppelrunde,
alle Werte bleiben im gültigen Bereich. Dazu ein Bericht darüber, was im
Spielstand wächst und wie die Wirtschaft jedes Vereins tatsächlich aussieht.
Was hier anschlägt, ist ein Fehler und keine Geschmacksfrage — der erste Lauf
förderte fünf davon zutage.

Und zum Ansehen der Oberfläche ohne Fenster — legt je Bildschirm ein PNG ab:

```bash
xvfb-run -a godot4 --rendering-driver opengl3 \
  res://werkzeuge/Bildschirmfoto.tscn -- /tmp/bilder buero kader live
```

Der **Kaltstarttest** ist der wichtigste davon: Er startet die Anwendung so, wie
sie ein Spieler startet — ohne geladenen Spielstand — und ruft in diesem Zustand
jeden Bildschirm und jedes Fenster auf. Genau diese Reihenfolge hatte der frühere
Oberflächentest nicht abgedeckt (er legte erst ein Spiel an und baute die
Oberfläche danach), wodurch Zugriffe auf noch nicht vorhandene Weltdaten
unentdeckt blieben.

---

## Echte Vereine oder erfundene Welt

Beim Anlegen einer Karriere entscheidet ein Häkchen, in welcher Welt Sie
arbeiten:

* **Echte Vereine** (Voreinstellung): fünf echte Ligastrukturen der Saison
  2026/27 — Handball-Bundesliga und 2. Bundesliga (je 18 Vereine), Herre
  Håndbold Ligaen, Liqui Moly Starligue, Liga ASOBAL und Orlen Superliga.
  96 echte Vereine mit Ort, Halle und Vereinsfarben, dazu echte Spieler,
  soweit im Datensatz hinterlegt.
* **Erfundene Welt**: wie bisher alles prozedural — eigene Vereine, eigene
  Spieler, eigene Namen.

Beides läuft über dieselbe Mechanik. Der Unterschied liegt nur in der
Datenquelle: `daten/ligen.json` und `daten/kader.json`. **Alles, was dort
fehlt, erfindet das Spiel** — Vereine ohne hinterlegte Spieler bekommen einen
vollständigen erfundenen Kader, Nationen ohne echtes Unterhaus bekommen eine
erfundene zweite Liga, damit Auf- und Abstieg überall funktioniert.

Wie weit die echten Daten reichen, zeigt

```bash
godot4 --headless res://werkzeuge/Datenbericht.tscn
```

Aktueller Stand: **96 von 136 Vereinen** echt, **94 echte Spieler** bei zehn
Vereinen; alle übrigen Kaderplätze sind gefüllt. In der Oberfläche ist das
nicht zu sehen: hinterlegte und erfundene Spieler stehen ununterschieden
nebeneinander, werden nach denselben Regeln erzeugt und entwickeln sich
gleich. Wer wissen will, wie weit der Datensatz reicht, ruft den
Datenbericht auf — im Spiel selbst soll die Welt aus einem Guss wirken.

Kader veralten mit jedem Transferfenster. Das Format ist in
[`daten/README.md`](daten/README.md) beschrieben und bewusst so einfach
gehalten, dass es sich ohne Programmierkenntnisse pflegen lässt.

> Vereins- und Spielernamen sind für den privaten Gebrauch erfasst. Für eine
> Veröffentlichung des Spiels wären Namens- und Markenrechte zu klären — dafür
> gibt es das Häkchen „Erfundene Welt".

---

## Die Oberfläche

Alles, was zu sehen ist, wird gezeichnet — es liegt keine einzige Bilddatei im
Projekt, keine Symbolschrift, kein fremdes Theme.

* **Ein Design-System als einzige Quelle.** `autoload/Stil.gd` hält Farbwelt,
  Höhenstaffelung der Flächen, Schriftgrößen, Abstände und jeden
  wiederverwendbaren Baustein: Karte mit Kopfzeile und Aktionsslot,
  Kennzahlenkachel, Abzeichen, segmentierte Umschaltleiste, Balken,
  Ringanzeige, Verlaufslinie, Säulenreihe, Hinweisstreifen, Leerzustand,
  Monogramm und Tabelle. Kein Bildschirm baut sich eigene Controls zusammen.
* **Tabellen sehen überall gleich aus.** `Stil.tabelle()` liefert ein Raster,
  das Zebrastreifen, Kopflinie und Hervorhebung der eigenen Mannschaft selbst
  hinter die Zellen zeichnet — die Bildschirme müssen dafür nichts tun.
* **Ein eigener Symbolsatz.** `ui/widgets/Symbol.gd` zeichnet rund dreißig
  Icons aus Linien und Polygonen in einem 0..1-Raum. Sie skalieren verlustfrei
  und tragen die Navigation, die Kopfzeile und die Bedienelemente.
* **Seitenleiste und Kopfzeile.** Links Wortmarke, nach Bereichen gruppierte
  Navigation mit Symbol, Aktivmarke und Zähler für ungelesene Nachrichten,
  unten der Trainer. Oben Wappen, Verein, Liga, Kasse, Spieltag, Saison,
  Nachrichtenglocke und der Weiter-Knopf.
* **Anzeigetafel im Spiel.** Heimseite, Spielstand mit Uhr, Gastseite — mit
  Wappen und Vereinsnamen beider Mannschaften, darunter Wettbewerb und
  Hallenpuls.

### Spielergesichter

Jeder Spieler hat ein Gesicht, und zwar dauerhaft dasselbe: aus der Spieler-ID
wird ein Zufallsstrom abgeleitet, der Kopfform, Kinn, Hautton, Haarfarbe,
Frisur, Augen, Brauen, Nase, Mund, Bart und Ohren festlegt. Herkunft und Alter
wirken mit — die Hauttöne folgen der Nation, Haare ergrauen und weichen mit den
Jahren zurück, ab dreißig kommen Falten dazu. Der Hintergrund und die Schultern
tragen die Vereinsfarben, sodass ein Portrait auch bei 22 Pixeln in der
Kaderliste noch etwas aussagt. Alles gezeichnet, keine Bilddateien.

### Nationalflaggen

`ui/widgets/Flagge.gd` zeichnet die Flaggen aus kleinen Rezepten — waagerechte
und senkrechte Streifen, Nordkreuz, Schweizer Kreuz, Mittelbalken, Viertelung,
einfarbig mit Scheibe. Sie stehen überall dort, wo eine Herkunft genannt wird.

### Vereinswappen

Jeder Verein hat ein Wappen aus vier Schichten: Grundform (Schild, Rundschild,
Kreis, Sechseck, Wimpel, Raute, Banner, Rechteck), heraldische Teilung (Pfahl,
Bänder, Schräge, Sparren, Viertelung, Streifen, Kopfband, Ringband, Spaltung),
das Vereinskürzel oder ein Symbol, dazu Rand, Innenkante und Schattierung.

Die echten Vereine bekommen ihre **tatsächlichen Vereinsfarben** und ihr
**Kürzel**; Form und Teilung stehen für die bekannten Vereine im Datensatz und
ergeben sich sonst aus einer Prüfsumme des Vereinsnamens — dasselbe Wappen also
in jeder Karriere. Damit ist jeder Verein auf einen Blick zu erkennen, ohne dass
eine fremde Grafik im Projekt liegt: eingebundene Original-Logos wären Bilddateien
und damit sowohl gegen die Bauvorgabe „keine externen Assets" als auch gegen
fremde Markenrechte. Wer eigene Wappenrezepte will, ändert in `daten/ligen.json`
beim Verein einfach `"wappen": {"form": …, "muster": …, "symbol": …}`.

---

## Was Hallenherz eigen ist

Acht Systeme, die es so nicht als Pflichtanforderung gab und die das Spiel prägen:

### Hallenpuls
Die Atmosphäre in der Halle ist eine eigene Größe (0–100), die sich **während**
der Partie bewegt: Tore, Paraden, Torläufe und Zeitstrafen treiben sie hoch,
Rückschläge drücken sie. Sie wirkt direkt auf Wurfgüte und Paradenwert — die
Heimmannschaft profitiert, die Gastmannschaft leidet, aber nur so stark, wie
ihre Nervenstärke es zulässt. Fantreue, Auslastung und Hallenausbau bestimmen,
wie weit der Ausschlag geht. In der Live-Ansicht ist der Puls sichtbar und
erklärt, warum ein Spiel plötzlich kippt.

### Lastkonto und Regenerationsbudget
Jeder Spieler führt ein Lastkonto (0–100). Es füllt sich mit jeder Spielminute
und jeder harten Trainingswoche und leert sich langsam über Regeneration.
Ein hohes Lastkonto senkt Form und Leistung und erhöht das Verletzungsrisiko
spürbar. Dagegen steht ein **begrenztes Regenerationsbudget** pro Woche
(abhängig von Physiotherapeut und Regenerationsbereich), das einzelnen Spielern
zugeteilt werden kann — wer regeneriert, entwickelt sich in dieser Woche aber
kaum. Rotation ist dadurch kein Komfort, sondern eine Entscheidung mit Preis.

### Die Handschrift des Trainers
Sechs Achsen (Tempo, Abwehr, Jugend, Wagemut, Rotation, Strenge) richten sich
langsam danach aus, wie man **tatsächlich** arbeitet — gemessen an gesetzten
Taktiken und an der Spielzeit, die junge Spieler wirklich bekommen. Erreicht
eine Achse einen Extremwert, entsteht eine **Prägung**: ein dauerhafter Effekt,
der in der Simulation wirkt (z. B. „Tempodiktat" verbessert Gegenstöße,
„Hasardeur" senkt das Risiko beim 7-gegen-6, „Talentflüsterer" beschleunigt die
Entwicklung junger Spieler). Die Handschrift überlebt jeden Vereinswechsel und
ist damit die eigentliche Karrierewährung.

### Die Kabine
Eine Mannschaft ist kein Attributdurchschnitt. Aus Führungsstärke, Alter,
Rolle und Leistung ergibt sich der Einfluss jedes Spielers; daraus entstehen
Wortführer und Gruppen (nach Herkunft und Altersschicht). Zusammen mit
individueller Unzufriedenheit ergibt das ein **Kabinenklima**, das als
Leistungsfaktor direkt in die Simulation eingeht und eigene Ereignisse
auslöst. Vier Gesprächstonlagen (Lob, Kritik, Vertrauen, Druck) wirken je nach
Charakter des Spielers unterschiedlich — und können nach hinten losgehen.

### Erfolgsprämien statt Festgehalt
Jeder Vertrag kann eine Tor- und eine Siegprämie enthalten. Der Spieler
rechnet sie gegen sein Festgehalt auf — aber nicht zum vollen Wert: ein
ehrgeiziger Profi traut sich die Prämien zu und verzichtet dafür spürbar auf
Grundgehalt, ein Zweifler will Sicherheit und rechnet sie kaum an. Für den
Verein ist das eine echte Wette: In schwachen Wochen bleibt Luft in der
Gehaltsliste, in erfolgreichen wird es teuer. Ausgezahlte Prämien heben
zusätzlich die Stimmung des Spielers. Die Finanzübersicht führt beides
getrennt — die erwartete Wochenlast und das, was in dieser Saison tatsächlich
geflossen ist.

### Patenschaften
Ein erfahrener Spieler (ab 27) nimmt ein Talent (bis 23) an die Hand. Wie gut
das funktioniert, hängt an Führung, Profitum und Temperament des Paten, am
Klassenunterschied, an gleicher Position und gleicher Sprache — und daran, ob
der Pate selbst zufrieden ist. Eine Patenschaft braucht eine gemeinsame
Vorbereitung, bis sie voll wirkt. Dann wächst der Schützling in Entscheidung,
Übersicht und Nervenstärke schneller, seine Moral steigt, seine
Unzufriedenheit sinkt — **und sein Charakter zieht langsam in Richtung seines
Vorbilds**. Wer einen Söldner zum Paten macht, hat in zwei Jahren einen
zweiten Söldner. Drei Patenschaften trägt eine Kabine, nicht mehr. Zu finden
unter *Kabine*.

### Der Sponsorenmarkt
Sponsoring ist im Hallenhandball die grösste Einnahmequelle, und es ist keine
feste Zahl. Ein Verein hat fünf Plätze — Trikotbrust, Hallenname, Ausrüster,
Ärmel, Rückenpartner —, die unterschiedlich viel wert sind. Was er dafür
aufrufen kann, hängt an Etat, Liga, Fanzufriedenheit, Treue und den Titeln der
letzten drei Jahre. Verträge laufen aus; dann liegen neue Angebote auf dem
Tisch, und **solange nicht unterschrieben wird, bleibt der Platz leer und das
Geld aus**. Jeder Vertrag trägt eine Titelprämie, die bei einem Titelgewinn
tatsächlich ausgezahlt wird. Aufstieg, Erfolg und volle Hallen zahlen sich
dadurch mit einem Jahr Verzögerung aus — und ein Absturz auch.

### Das Gespür der Scouts
Scouts sind nicht nur Werte, sondern haben einen eigenen Ruf. Jede Empfehlung
eines jungen Spielers wird zwei Saisons später daran gemessen, ob er sich
wirklich entwickelt hat. Wer richtig lag, wird zuverlässiger: seine Berichte
werden enger, seine Einschätzungen glaubwürdiger. Wer danebenliegt, verliert
an Gespür — und seine Berichte sind entsprechend zu lesen.

---

## Ton

Es liegt keine Audiodatei im Projekt. `autoload/Klang.gd` berechnet beim Start
jeden Klang als PCM-Puffer und legt ihn als `AudioStreamWAV` in den Speicher:

* **Schiedsrichterpfeife** aus zwei leicht verstimmten Sinustönen mit Vibrato
  und einem Hauch Luftrauschen (Grundton rund 2,9 kHz).
* **Torjubel** aus zweifach tiefpassgefiltertem Rauschen mit schnellem Anstieg,
  langem Ausklingen und einem tiefen Rumpler als Körper — in drei Stärken für
  eigenes Tor, Gegentor und Parade.
* **Hallenatmosphäre** als sechs Sekunden lange, nahtlos geschlossene
  Rauschschleife mit langsamer Wellenbewegung. **Ihre Lautstärke folgt dem
  Hallenpuls der laufenden Partie** — die Halle wird hörbar lauter, wenn das
  Spiel kippt.
* **Ball**, **Schlusssirene**, **Klick** und ein weiches **Blättern** beim
  Seitenwechsel.
* **Menümusik**: eine zwölf Sekunden lange Schleife in a-Moll aus Pad-Akkorden
  (mehrere leicht verstimmte Sinusanteile), einem weichen Bass und einer
  sparsamen Melodie.

Alles läuft über zwei zur Laufzeit angelegte Audiobusse: **Halle** trägt einen
Nachhall und eine leichte Höhenabsenkung, sodass jedes Spielgeräusch nach
Sporthalle klingt statt nach Kopfhörer; **Musik** bekommt wenig Raum und eine
Kompression. Jubel und Hallengemurmel bestehen nicht aus schlichtem Rauschen,
sondern aus mehreren Resonanzbändern im Stimmbereich plus eingestreuten
Klatschtransienten und vereinzelten Rufen — das ist der Unterschied zwischen
„Wind" und „Menschen". Die Pfeife hat einen Anblas-Chirp und das Rasseln der
Erbse als schnelles Vibrato.

Hauptschalter und drei Regler (Musik, Effekte, Atmosphäre) stehen unter
*Spielstand*. Die Werte gehören zum Spielstand und werden mitgespeichert.

### Eigene Bilder und Klänge

Wem das Gezeichnete oder Synthetisierte nicht gefällt, legt eigene Dateien in
`assets/` ab — ohne eine Zeile Code zu ändern:

* `assets/wappen/<Kürzel>.png` ersetzt das gezeichnete Wappen eines Vereins
  (`SCM.png`, `THW.png`, …; auch `svg`, `jpg`, `webp`).
* `assets/klang/<Name>.ogg` ersetzt einen Klang (`tor`, `pfiff`, `atmo`,
  `musik`, …; auch `wav`, `mp3`).

Wo nichts liegt, bleibt es bei der eingebauten Variante — ein Datensatz aus
zehn Logos und zwei Klängen funktioniert genauso wie ein vollständiger. Welche
Klänge aus Dateien stammen, steht im Spielstandsbildschirm. Die Einzelheiten
stehen in [`assets/README.md`](assets/README.md).

Zum Anhören ohne Spiel schreibt der Klangtest alle Klänge als WAV:

```bash
godot4 --headless res://werkzeuge/Klangtest.tscn -- /tmp/klang
```

Zum Prüfen ohne Lautsprecher:

```bash
godot4 --headless res://werkzeuge/Klangtest.tscn   # Länge, Spitze, RMS, Nulldurchgänge
```

## Warum das Spiel zweidimensional ist — und wo nicht

Eine Draufsicht liest sich in einem Manager besser als eine Kameraperspektive:
Man sieht alle sieben Feldspieler, ihre Abstände und die Deckungsformation auf
einen Blick. Eine 3D-Spielansicht würde das verschlechtern und wäre ein
Vielfaches an Aufwand. An **einer** Stelle verdient sich 3D seinen Platz: beim
gewonnenen Titel. `ui/widgets/Pokal3D.gd` baut eine Trophäe aus
Godot-Grundkörpern (Zylinder, Kugel, Torus, Kasten), gibt ihr ein metallisches
Material und dreht sie langsam in einem eigenen Viewport — in Gold ab drei
Titeln, sonst in Silber. Auch hier: kein geladenes Modell, keine Textur.

---

## Die Simulation

Die Partie läuft angriffsweise ab (rund 120 Angriffe pro Spiel) und wird von
**derselben Engine** gerechnet, ob sie live angeschaut oder still weggerechnet
wird. Kennzahlen aus 300 Testpartien:

| Kennzahl | Hallenherz | Realität (1. Liga) |
|---|---|---|
| Tore pro Spiel (gesamt) | 59,8 | ~58 |
| Heim : Gast | 30,7 : 29,1 | ~30 : 28 |
| Zeitstrafen pro Spiel | 7,8 | ~8 |
| Siebenmeter pro Spiel | 7,1 | ~7 |
| Technische Fehler | 19,5 | ~20 |
| Paraden pro Spiel | 25,0 | ~28 |
| Heimsiegquote | 57,0 % | ~57 % |
| Ø Torabstand | 5,9 | ~6 |
| Partien mit 10+ Toren Unterschied | 19,0 % | ~20 % |

Abgebildet sind unter anderem:

* **Getrennte Angriffs- und Abwehrformation.** Zwei Siebener, frei besetzbar.
  Die *Wechselintensität* bestimmt, wie konsequent rotiert wird — das kostet
  Kraft und kann einen Wechselfehler samt Zeitstrafe produzieren.
* **Zeitstrafen mit echter Unterzahl.** Numerische Überzahl verschiebt die
  Chancenqualität deutlich; die dritte Zeitstrafe eines Spielers ist Rot.
* **7-gegen-6.** Fünf Auslöser („nie", „bei Unterzahl", „bei Rückstand",
  „Schlussphase", „immer"). Der Angriff wird stärker, technische Fehler
  wahrscheinlicher — und jeder zweite davon landet im leeren Tor.
* **Abwehrformationen** 6-0, 5-1, 3-2-1 und 4-2 mit unterschiedlichen Profilen
  aus Blockstärke, Ballgewinnen, Zeitstrafenrisiko und Kraftverbrauch, dazu
  eine Wirkungsmatrix gegen fünf Angriffsausrichtungen.
* **Kraftverschleiß** über 60 Minuten, abhängig von Ausdauer, Tempo,
  Deckungsart und Wechselintensität — mit automatischer oder manueller Rotation.
* **Auszeiten** (drei pro Mannschaft), die einen Lauf des Gegners brechen.
* **Kabinenansprachen** vor dem Anpfiff und zur Halbzeit: vier Tonlagen
  (ruhig, anfeuern, kritisieren, Vertrauen aussprechen), deren Wirkung von
  Spielstand, Kabinenklima und der Handschrift des Trainers abhängt. Eine
  Ansprache verschiebt Angriffs- und Abwehrkraft für den Rest der Partie —
  in beide Richtungen.
* **Verletzungen während der Partie** mit sofortigem Ausfall.
* **Tempogegenstöße**, Blocks, Ballgewinne, Siebenmeter, Zeitspiel,
  Verlängerung und Siebenmeterwerfen in K.-o.-Partien.

In der Live-Ansicht sieht man das Feld mit beiden Siebenern, den Ball an der
Wurfposition, den Ticker, den Hallenpuls und die Kräfte jedes Spielers — und
kann jederzeit wechseln, Auszeit nehmen, die Deckung umstellen oder den Torwart
herausnehmen.

---

## Die Spielwelt

* **5 Nationen, 10 Ligen, 136 Vereine, ~2.700 Spieler.** Jede Nation hat zwei
  Spielklassen mit echtem Auf- und Abstieg (je zwei Vereine pro Saison).
  In Deutschland sind beide Ligen echt besetzt, in den übrigen Nationen die
  oberste; die Unterhäuser dort sind erfunden.
* **5 nationale Pokale** im K.-o.-System mit Freilosen für die stärksten
  Vereine und Heimrecht für den unterklassigen Verein.
* **Zwei internationale Wettbewerbe:** die *Kontinentalkrone* (16 Teams, vier
  Gruppen, dann K.-o. mit Hin- und Rückspiel) und die *Challenge-Trophäe*
  (reines K.-o.). Qualifikation über die Abschlusstabellen und Pokalsieger.
* **Nationale Supercups** zwischen Meister und Pokalsieger.
* **Nationalmannschaften und ein Winterturnier.** In jeder Winterpause spielen
  16 Nationen ein Turnier aus — in geraden Saisons eine Europameisterschaft,
  sonst eine Weltmeisterschaft, mit Gruppenphase und K.-o.-Runde. Die Kader
  werden aus den besten verfügbaren Spielern der Welt nominiert; wer
  nominiert wird, fehlt dem Verein und kommt mit Belastung zurück. Die
  Turnierpartien laufen durch dieselbe Engine, zählen aber in keine
  Vereinswertung.
* **Vorbereitungsspiele** im Juli und August: fünf Testspiele gegen Gegner
  ähnlicher Stärke, die für keine Tabelle zählen, aber Spielpraxis, Fitness
  und einen ersten Blick auf den neuen Kader liefern.
* Die Welt lebt ohne Zutun weiter: KI-Vereine stellen auf, passen ihre Taktik
  an den Gegner an, transferieren, verlängern Verträge, bauen aus, ersetzen
  altersbedingt ausscheidendes Personal und ziehen jedes Jahr eigene Talente
  nach.

---

## Die echten Kader selbst pflegen

Der mitgelieferte Datensatz deckt zehn Vereine ab. Wer die Bundesliga
vollständig will, trägt sie im Bildschirm **Kaderdaten** selbst ein: links alle
96 Vereine mit ihrem Füllstand, rechts der Kader des gewählten Vereins, Zeile
für Zeile bearbeitbar.

Für einen ganzen Kader auf einmal gibt es das CSV-Feld:

```
Vorname;Nachname;Position;Nation;Alter;Staerke
Mathias;Gidsel;RM;dk;27;92
Hans;Lindberg;RA;dk;40;78
```

Trennzeichen darf Semikolon, Tabulator oder Komma sein, eine Kopfzeile wird
erkannt, Leerzeilen und `#`-Zeilen werden übersprungen. Der Parser repariert,
was sich reparieren lässt — eine unbekannte Position wird zu RM, eine
unbekannte Nation zu `de` — und sagt in beiden Fällen, was er getan hat, statt
die Zeile stillschweigend wegzuwerfen.

Gespeichert wird nach `user://kader_eigen.json`, also außerhalb des Projekts:
Die Pflege überlebt jede Aktualisierung des Spiels und liegt beim Laden über
dem mitgelieferten Datensatz. Ein Knopf schreibt alles zusammen zurück nach
`daten/kader.json`, wenn man aus dem Projektordner spielt.

**Änderungen wirken auf neu angelegte Karrieren.** Eine laufende Karriere hat
ihre Spieler bereits im Spielstand und bleibt unberührt — sonst würden
Statistiken, Verträge und Transferhistorie ins Leere zeigen.

---

## Zum Datum springen

Ein Knopf in der Kopfzeile öffnet das Vorspulfenster. Entweder eine feste Marke
— nächstes eigenes Spiel, nächster Montag, Ligastart, Winterpause,
Transferfenster, letzter Spieltag, Saisonende — oder ein frei gewähltes Datum.

Das Spiel schaltet dann Tag für Tag weiter und hält an, sobald etwas eine
Entscheidung verlangt: die eigene Partie (die sich wahlweise mitsimulieren
lässt), der Saisonwechsel oder der Verlust des Vereins. Eine harte Obergrenze
von einem Kalenderjahr verhindert, dass ein falsch eingegebenes Datum das Spiel
in eine sehr lange Schleife schickt.

---

## Zwischen den Spielen

* **Spielvorbereitung.** Vor jeder eigenen Partie liefert die Analyseabteilung
  einen Vorbericht über den Gegner — voraussichtliche Aufstellung,
  Schlüsselspieler mit Saisonzahlen, Ausrichtung, Stärken, Ansatzpunkte und
  eine Empfehlung, welche Deckung gegen den Angriffsstil des Gegners am besten
  wirkt. Der Detailgrad ist gestuft (0 bis 3) und hängt von Scoutbericht,
  ausgebauter Analyseabteilung und Kenntnis der gegnerischen Spieler ab: ohne
  Vorarbeit bleibt es bei Vermutungen, mit voller Analyse liegt sogar die
  Wurfverteilung des Gegners offen.
* **Pressekonferenzen.** Am Tag vor Pflichtspielen stellt die Presse Fragen —
  bei Derbys, in der Krise und vor internationalen Partien immer, sonst
  gelegentlich. Die Fragen greifen die tatsächliche Lage auf: eine Serie von
  Niederlagen, ein Platz an der Spitze, ein wechselwilliger Spieler. Jede
  Antwort wirkt auf Fans, Vorstand, Mannschaftsmoral — und auf die Motivation
  des Gegners, der mitliest.
* **Spieler kommen zu Ihnen.** Wer zu wenig spielt, wer nach einem gebrochenen
  Versprechen wartet, wessen Vertrag ausläuft, wer die Kabine anführen will
  oder wer nicht in die Saison findet, klopft von sich aus an die Tür — mit
  seinem Gesicht, seinem Anliegen und drei möglichen Antworten. Jedes Anliegen
  hat eine Frist von zwei Wochen. Wer es aussitzt, verliert Moral, Vertrauen
  und ein Stück Kabinenklima, und der Spieler erfährt es aus dem Schweigen.
* **Vertragsverhandlung über mehrere Runden.** Der Spieler eröffnet mit einer
  Forderung, man macht ein Angebot, er nimmt an, lässt nachbessern oder steht
  auf. Geduld und Laune stehen sichtbar daneben. Bewertet wird das ganze Paket:
  Prämien und eine Ablöseklausel rechnet er sich aufs Gehalt an, eine größere
  Rolle wiegt bares Geld auf, und die Laufzeit wirkt je nach Alter in
  verschiedene Richtungen. Das Ganze spielt in einem **3D-Verhandlungsraum**:
  Tisch, Lampe, Wappen an der Wand — und der Spieler, dessen prozedurales
  Gesicht als Textur in der Szene hängt. Die Beleuchtung folgt seiner Laune.
* **Einzelgespräche mit Versprechen.** Jeder eigene Spieler hat ein Verhältnis
  zum Trainer (0–100). Welche Themen anstehen, ergibt sich aus seiner Lage:
  eine gute oder schlechte Serie, zu wenig Einsatzzeit, ein Wechselwunsch, ein
  auslaufender Vertrag, oder die Frage, ob er Verantwortung übernehmen soll.
  Jedes Thema hat mehrere Antworten mit unterschiedlichem Risiko; wie sie
  ankommen, hängt an Charakter, Moral, dem bisherigen Verhältnis und der
  **Strenge in der Handschrift des Trainers** — eine harte Ansage trägt bei
  einem Profi und einem strengen Trainer, bei einem Hitzkopf geht sie nach
  hinten los.
  Zwei Antworten sind **Versprechen**: mehr Einsatzzeit oder eine Freigabe im
  nächsten Transferfenster. Sie werden gespeichert und nach sechs Wochen
  überprüft. Wer Wort hält, bindet den Spieler dauerhaft. Wer es bricht,
  verliert Vertrauen und Moral, oft den Spieler — und die Kabine erfährt davon.
* **Spieleranweisungen.** Die Mannschaftstaktik gibt den Rahmen, die Anweisung
  sagt, was der Einzelne darin tun soll. Im Angriff: ausgeglichen, Abschluss
  suchen, Spiel eröffnen, Eins gegen Eins, Kreis anspielen. In der Abwehr:
  Position halten, Vorschieben, Block stellen, Absichern. Jede Rolle hat einen
  Preis — wer öfter abzieht, trifft aus schlechteren Lagen; wer nur eröffnet,
  spielt die Mannschaft fest und verliert Angriffe an die Uhr; wer vorschiebt,
  gewinnt Bälle und kassiert Zeitstrafen. Der Trainerstab macht auf Knopfdruck
  einen Vorschlag je Spieler, die Computervereine nutzen dasselbe System.
* **Rückennummern.** Jeder Spieler trägt eine eigene Nummer, vergeben nach der
  Gewohnheit des Handballs: die Eins gehört dem Torwart, die Sieben dem
  Linksaußen, die Zehn dem Spielmacher. Sie steht in der Kaderliste, im
  Spielerfenster, in den Aufstellungsfeldern — und auf dem Trikot auf dem
  gezeichneten Spielfeld. Wer eine Nummer schon trägt, behält sie beim Wechsel,
  wenn sie im neuen Kader frei ist; ändern lässt sie sich im Spielerfenster.
* **Nachwuchsakademie.** Jede Saison rückt ein eigener Jahrgang nach. Talente
  entwickeln sich schneller als Profis, aber nur so gut, wie die Jugendarbeit
  des Vereins es hergibt. Wer überzeugt, wird in den Profikader befördert; wer
  mit 20 nicht weit genug ist, wird freigegeben. Auch KI-Vereine pflegen ihre
  Jugend.
* **Statistikzentrum.** Zwölf Spielerwertungen je Liga (Tore, Tore je Spiel,
  Vorlagen, Wurfquote, Siebenmeter, Paraden, Paradenquote, Durchschnittsnote,
  Einsatzzeit, Zeitstrafen, Ballgewinne, Blocks) mit Mindesteinsatzhürden, dazu
  vier Mannschaftswertungen (bester Angriff, beste Abwehr, Zuschauerschnitt,
  Zeitstrafen) — und in jeder Wertung die Platzierung des eigenen Kaders.
* **Spielbericht mit Wurfkarte und Torverlauf.** Nach jeder Partie zeigt der
  Bericht, von wo abgeschlossen wurde: je Position ein Kreis auf der
  angegriffenen Hälfte, Größe nach Zahl der Würfe, Füllung und Farbe nach
  Trefferquote, Siebenmeter separat. Daneben der Torverlauf als Treppenkurve
  um die Nulllinie in den Vereinsfarben — man sieht auf einen Blick, wann ein
  Spiel gekippt ist. Die Engine hält dafür nur Summen je Position fest, keine
  Einzelwürfe.
* **Saisonprognose der Buchmacher.** Vor jeder Saison wird für jede Liga eine
  Quote je Verein gebildet, aus Vereinsruf und der tatsächlichen Stärke der
  zehn besten Spieler. Die Tabelle stellt der Prognose den aktuellen Platz
  gegenüber — grün, wer über der Erwartung liegt, rot, wer darunter.
* **Die Laufbahn jedes Spielers.** Neben der Statistik führt jeder Spieler eine
  Chronik seines Sportlerlebens: Pflichtspieldebüt, jeder Wechsel mit Ablöse,
  Leihen, der Sprung aus der eigenen Jugend, gewonnene Titel (nur für die, die
  mindestens fünf Saisonspiele hatten), Berufungen ins Team der Saison,
  Torschützenkronen, Nominierungen für EM und WM, schwere Verletzungen ab acht
  Wochen Ausfall und runde Marken — das 100. Pflichtspiel, der 200.
  Karrieretreffer, die 1000. Parade. Nach Saisons gruppiert im Spielerfenster
  unter *Entwicklung*. Damit ist ein Transferziel keine Zeile mit Zahlen mehr,
  sondern jemand mit Vergangenheit.
* **Stärkeverlauf.** Alle vier Wochen wird der Gesamtwert jedes Spielers
  festgehalten. Im Spielerfenster ergibt das eine Kurve über bis zu vier Jahre:
  ob jemand wirklich besser wird, sieht man erst daran.
* **Team der Saison.** Zum Saisonende wählt jede erste Liga ihre beste Sieben:
  je Position der Spieler mit der besten Durchschnittsnote bei mindestens
  zwölf Einsätzen. Die Berufungen zählen lebenslang und stehen in der
  Laufbahn jedes Spielers.

---

## Die neun Säulen im Überblick

| Säule | Umsetzung |
|---|---|
| **1 Liga-Welt** | 5 Nationen / 10 Ligen / 136 Vereine, Auf- und Abstieg, 5 Pokale, 2 Europapokale, Supercups, Nationalmannschaften mit EM und WM, vollständig eigenständige KI |
| **2 Matchsimulation** | Angriffsweise Engine, 4 Deckungen × 5 Angriffsstile, individuelle Spieleranweisungen (5 im Angriff, 4 in der Abwehr), Zeitstrafen mit Unterzahl, 7-gegen-6, Auszeiten, Kabinenansprachen, Kräftehaushalt, Live-Ansicht mit gezeichnetem Feld |
| **3 Kader** | 29 Attribute, Form, Moral, Fitness, Lastkonto, Verletzungsanfälligkeit, Persönlichkeit, Potenzial, Alterskurve, individuelle Förderprogramme, Rückennummern, Patenschaften, eigene Nachwuchsakademie |
| **4 Transfer & Scouting** | Aktive Suche mit acht Filtern, zweistufige Verhandlung (Verein, dann Spieler), Gegenangebote, Leihen, Erfolgsprämien im Vertrag, Transferfenster mit Fristmeldungen, Scoutaufträge mit Unschärfe, gestufte Spielvorbereitung |
| **5 Vereinsführung** | Einnahmen aus Zuschauern, einem eigenen Sponsorenmarkt mit auslaufenden Verträgen, Medien, Merchandising und Preisgeldern; sechs Ausbaubereiche; sieben Personalrollen mit messbarer Wirkung; Vorstand mit Ziel, Vertrauen, Warnstufen und Entlassung |
| **6 Trainerkarriere** | Eigener Vertrag, Ruf, Stationen, Titelsammlung, Jobangebote, Handschrift mit Prägungen — alles vereinsübergreifend |
| **7 Zeitablauf** | Tageskalender mit Vorbereitung, Trainingsalltag und Wochenrhythmus (Montag: Abrechnung, Training, Presse, Vorstand; Donnerstag: Kabine, Gerüchte), Winterpause, Transferfenster; eine Drei-Wochen-Vorschau zeigt Spiele, Fristen, Scoutberichte und Bauabschlüsse |
| **8 Immersion** | Presse und „Hallenfunk" reagieren auf Ergebnis, Derbycharakter, Serien, Einzelleistungen und Vereinslage; Pressekonferenzen vor Pflichtspielen; Rivalitäten wachsen aus Duellen; Chronik mit Titeln, Legenden, Rekorden und Saisonverlauf |
| **9 Persistenz** | 5 Speicherplätze plus automatische Sicherung (jeden Montag und zu jedem Saisonwechsel), vollständiger Zustand in einer Datei, Klartext-Beschreibung daneben, automatische Ergänzung fehlender Felder beim Laden |

---

## Aufbau des Projekts

```
project.godot
autoload/
  Stil.gd            Design-System: Farben, Typografie, Theme, Karten, Kacheln,
                     Abzeichen, Balken, Ringe, Verlaufslinien, Schalter,
                     Tabellen mit Zebrastreifen, Geldformatierung
  Namen.gd           Kombinatorische Namensgebung (14 Kulturen, Vor- und
                     Nachnamen getrennt, Nachnamen zusätzlich aus Stamm+Endung,
                     Orte aus Präfix+Suffix, Firmen aus Präfix+Branche+Rechtsform)
  Welt.gd            DER Spielzustand + Zeitablauf + Persistenz
  Klang.gd           Synthese aller Geraeusche und der Musik
kern/
  Kalender.gd        Datumsrechnung (365-Tage-Jahr, Saison 1. Juli – 30. Juni)
  Spielerfabrik.gd   Spielererzeugung, Positionsgewichte, Marktwert, Alterskurve
  Weltgenerator.gd   Nationen, Ligen, Vereine, Wappen, Kader, Personal, Rivalitäten
  Spielplan.gd       Doppelrunde, Pokalauslosung, Gruppen- und K.-o.-Phasen
  Matchsim.gd        Die Spielsimulation
  Statistik.gd       Tabellen, Vereins- und Spielerstatistik, Torjäger, Ranglisten
  Finanzen.gd        Einnahmen, Ausgaben, Budgets, Ausbauprojekte
  Medizin.gd         Verletzungen, Genesung, Belastungssteuerung
  Training.gd        Wochenplan, Entwicklung, Regenerationsbudget
  Transfermarkt.gd   Suche, Verhandlung, Leihe, Verträge, KI-Markt
  Scouting.gd        Aufträge, Berichte, Unschärfe, Scout-Gespür
  Kabine.gd          Einfluss, Wortführer, Gruppen, Klima, Gespräche
  Trainerkarriere.gd Vertrag, Ruf, Stationen, Handschrift, Prägungen
  Vorstand.gd        Saisonziel, Vertrauen, Warnungen, Entlassung
  Chronik.gd         Rekorde, Rivalitäten, Legenden, Vereinsgeschichte
  Medien.gd          Presse und Hallenfunk
  Saison.gd          Abschluss, Ehrungen, Auf-/Abstieg, Nachwuchs, neue Saison
  Nationalteam.gd    Nominierung, EM/WM im Winter, Turnierspielplan
  Presse.gd          Pressekonferenzen: Fragen, Antworten, Wirkung
  Jugend.gd          Nachwuchsakademie: Jahrgänge, Entwicklung, Beförderung
  Praemien.gd        Erfolgsprämien: Bewertung, Auszahlung, Wirkung
  Gespraech.gd       Einzelgespräche, Verhältnis zum Trainer, Versprechen
  Anliegen.gd        Spieler, die von sich aus etwas wollen, samt Frist
  Verhandlung.gd     Vertragsverhandlung über mehrere Runden
  Kaderpflege.gd     Eigene Kaderdaten, CSV-Import, Export ins Projekt
  Vorbericht.gd      Spielvorbereitung: gestufte Gegneranalyse
  Echtdaten.gd       Lader und Zwischenspeicher für die JSON-Datensätze
  Anweisungen.gd     Individuelle Spieleranweisungen für Angriff und Abwehr
  Sponsoren.gd       Sponsorenmarkt: Plätze, Marktwert, Auslauf, Angebote, Prämien
  Laufbahn.gd        Chronik eines Spielerlebens: Debüt, Wechsel, Titel, Marken
  Trikot.gd          Rückennummern: Vergabe nach Position, Eindeutigkeit im Kader
  Mentoring.gd       Patenschaften: Passung, Reifung, Charakterübertragung
  KI.gd              Aufstellung, Taktik, Training, Verträge, Ausbau der KI-Vereine
ui/
  App.gd/.tscn       Rahmen: Kopfzeile, Navigation, Bildschirmwechsel
  Bildschirm.gd      Grundklasse aller Bildschirme
  LiveSpiel.gd       Live-Ansicht einer Partie
  widgets/           Wappen, Portraet (Gesichter), Flagge, Symbol (Icon-Satz),
                     NavKnopf, Spielfeld, Wurfkarte, Radar, Pokal3D,
                     Verhandlungsraum (3D), Bausteine, Spieler-, Vereins-,
                     Bericht-, Presse-, Vorbericht-, Anliegen-, Verhandlungs-
                     und Vorspulfenster
  bildschirme/       23 Bildschirme
daten/               ligen.json und kader.json — die echten Vereine und Kader
werkzeuge/           Test- und Kalibrierungsszenen
```

---

## Bewusste Entwurfsentscheidungen

**Ein Dictionary als Spielzustand.** `Welt.daten` enthält die komplette Welt als
verschachteltes Dictionary. Dadurch ist jede neue Zustandsvariable automatisch
Teil von Speichern und Laden, sobald sie dort abgelegt wird — es gibt keinen
zweiten Ort, an dem Zustand entstehen könnte. Gespeichert wird binär über
`store_var`, weil das Typen exakt erhält; daneben liegt eine kleine JSON-Datei
mit Verein, Trainer, Saison und Datum, damit die Spielstandsliste nichts laden muss.

**Kein Schema-Zwang beim Laden.** `Welt._daten_auffrischen()` ergänzt fehlende
Felder aus einer Vorlage. Ein Spielstand aus einer älteren Version verliert
dadurch nichts und stürzt nicht ab, wenn neue Systeme hinzukommen.

**Bildschirme werden gebaut, nicht erzeugt.** Alle 23 Bildschirme hängen von
Anfang an im Baum und werden nur über `visible` gewechselt. Innerhalb eines
Bildschirms liegen dauerhafte Knoten (Kopfzeilen, Reiterleisten, Meldungszeilen)
strikt außerhalb der Container, die bei jeder Aktualisierung geleert werden.

**Vereinfachtes Jahr mit 365 Tagen.** Keine Schaltjahre. Damit ist jeder
Tagindex eindeutig in ein Datum umrechenbar und Spielpläne bleiben über
beliebig viele Saisons stabil.

**Attribute 1–20, Gesamtwert 0–100.** Attribute sind intern Fließkommazahlen,
damit Entwicklung in kleinen Schritten laufen kann; angezeigt wird gerundet
und eingefärbt. Der Gesamtwert ist eine positionsgewichtete Mischung aus
Angriffs- und Abwehrwert — beim Kreisläufer zählt die Abwehr mehr als beim Außen.

**Unschärfe statt versteckter Wahrheit.** Fremde Spieler zeigen Spannen statt
Zahlen und eine Formulierung statt eines Potenzialwerts. Die Spanne verengt
sich mit der Kenntnis, die durch Scoutaufträge wächst.

**Ligen ohne Unterbau steigen nicht ab.** Spanien und Polen sind im Spiel
eingleisig; dort gibt es folgerichtig keinen Abstieg. Auf- und Abstieg findet
in Deutschland, Dänemark und Frankreich statt.

**Echte Daten gehören nicht in den Code.** Vereine und Spieler stehen in JSON
und werden geladen, nicht einprogrammiert. Dadurch lässt sich der Datenbestand
pflegen, ohne GDScript anzufassen — und weil der Generator jede Lücke füllt,
kann ein unvollständiger Datensatz die Welt nicht kaputt machen. Genau deshalb
sind auch nur belegbare Spieler hinterlegt statt aus dem Gedächtnis
zusammengeschriebener Kader.

**Die Zielstärke muss auch ankommen.** Die Attribute eines Spielers werden
gestreut ausgewürfelt; der daraus zurückgerechnete Gesamtwert lag dadurch
systematisch unter der Vorgabe. Ein mit 90 hinterlegter Weltklassetorwart kam
als 77er im Spiel an. Seit der Nachkalibrierung trifft der Gesamtwert die
Vorgabe auf etwa einen Punkt genau — das gilt für echte wie erfundene Spieler
und macht den Ruf eines Vereins erst zu einer verlässlichen Stellschraube.

**Stärkeunterschiede dürfen nicht durchschlagen.** Mit den echten Ligen wurde
sichtbar, was vorher in gemittelten Zahlen unterging: 55 % aller Partien gingen
mit zehn oder mehr Toren Unterschied aus, der Schnitt lag bei 11,4. Handball
ist nicht so. Die Wirkung von Stärkeunterschieden pro Angriff wurde mehr als
halbiert und die Ruf-Spanne der Ligen gestaucht — jetzt liegt der Schnitt bei
5,9 Toren und 19 % der Partien enden zweistellig, bei unveränderter
Tabellenordnung: die starken Vereine stehen weiterhin oben, sie gewinnen nur
nicht mehr jedes Spiel zweistellig.

**Gehalt richtet sich nach der Größe des Vereins, nicht nur nach dem Spieler.**
Ohne diesen Faktor zahlte ein polnischer Zweitligist dieselben Wochengehälter
wie der THW Kiel — das Ergebnis war eine Welt, in der 119 von 136 Vereinen im
Minus standen und die Summe aller Kassen bei minus 104 Millionen lag. Jeder
Verein hat jetzt ein Lohnniveau, das sich aus seinem Jahresetat ergibt und in
Gehaltsforderungen, Erfolgsprämien und die Betriebskosten der Abteilungen
eingeht. Zusammen mit dem Sponsorenmarkt kippt die Bilanz: 10 Vereine im Minus,
Summe aller Kassen deutlich positiv.

**Ein neuer Trainer bekommt Zeit.** Jobangebote kommen von Vereinen, die ihr
Ziel verfehlt haben — also von Vereinen mit niedrigem Vorstandsvertrauen und
einem Saisonziel, das die Mannschaft nicht einlösen kann. Wer dort anfing, war
in wenigen Wochen wieder entlassen: im Langzeittest fünf Stationen in drei
Saisons bei 55 % Siegquote. Beim Amtsantritt setzt der Vorstand das Vertrauen
deshalb zurück, streicht die Warnstufe und formuliert das Ziel neu, gemessen an
der Lage, die der neue Trainer vorfindet. Zusätzlich ergibt sich das Saisonziel
jetzt aus derselben Größe, an der auch jedes einzelne Spiel bewertet wird —
vorher war es der Vereinsruf, während die Spiele an der Kaderstärke gemessen
wurden.

**Der Spielstand darf nicht mitwachsen.** Ein vollständiger Spielbericht mit
Einzelbewertungen, Wurfkarte und Spielverlauf hängt an jeder Partie — bei über
4000 Partien im Archiv waren das 48 MB nach einer Saison. Von Partien ohne
eigene Beteiligung wird der Bericht direkt nach dem Verbuchen auf Ergebnis und
Mannschaftswerte eingedampft, beim Saisonwechsel auch der Rest. Dazu haben
Transferverlauf, Chronikereignisse und Entwicklungsprotokolle jetzt einen
Deckel. Ergebnis: knapp 25 MB nach zwei Saisons, ohne dass etwas fehlt, was
angezeigt wird.

**Die Welt darf nicht ausbluten.** Ein Manager-Spiel, das KI-Vereine nur
verwalten lässt, läuft nach wenigen Saisons leer. Deshalb verlängern KI-Vereine
auslaufende Verträge nach nachvollziehbaren Regeln, füllen Kaderlücken aus dem
freien Markt und verpflichten im Notfall auch kurzfristig — keine Mannschaft
kann mit zu wenigen Spielern antreten. Ein Testlauf über drei Saisons zeigt
stabile Kader (Ø 20 Spieler, kleinster 15) und rund 500 Transfers.

**Der Vorstand misst an der Mannschaft, nicht nur am Ruf.** Die Erwartung an eine
Partie ergibt sich aus einer Mischung von Vereinsruf und tatsächlicher Stärke der
zehn besten Spieler. Sonst würde ein Verein mit großem Namen und dünnem Kader
seinen Trainer für Ergebnisse bestrafen, die dem Kader entsprechen.

**Automatische Aufstellung ist voreingestellt, aber abschaltbar.** Ohne sie
würde eine Mannschaft mit müden oder formschwachen Spielern auflaufen, solange
niemand eingreift — während KI-Vereine vor jeder Partie neu aufstellen. Wer
selbst aufstellen will, schaltet sie auf dem Aufstellungsbildschirm ab und
bekommt dort stattdessen Warnungen zu Spielern, die nicht in Verfassung sind.

**Taktikänderungen im Spiel gelten nur für dieses Spiel.** Die Simulation
arbeitet auf einer Kopie der Vereinstaktik. Wer dauerhaft umstellen will, tut
das auf dem Aufstellungsbildschirm.
