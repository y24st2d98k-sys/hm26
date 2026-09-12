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

## Was Hallenherz eigen ist

Fünf Systeme, die es so nicht als Pflichtanforderung gab und die das Spiel prägen:

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

### Das Gespür der Scouts
Scouts sind nicht nur Werte, sondern haben einen eigenen Ruf. Jede Empfehlung
eines jungen Spielers wird zwei Saisons später daran gemessen, ob er sich
wirklich entwickelt hat. Wer richtig lag, wird zuverlässiger: seine Berichte
werden enger, seine Einschätzungen glaubwürdiger. Wer danebenliegt, verliert
an Gespür — und seine Berichte sind entsprechend zu lesen.

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
* **Team der Saison.** Zum Saisonende wählt jede erste Liga ihre beste Sieben:
  je Position der Spieler mit der besten Durchschnittsnote bei mindestens
  zwölf Einsätzen. Die Berufungen zählen lebenslang und stehen in der
  Laufbahn jedes Spielers.

---

## Die neun Säulen im Überblick

| Säule | Umsetzung |
|---|---|
| **1 Liga-Welt** | 5 Nationen / 10 Ligen / 136 Vereine, Auf- und Abstieg, 5 Pokale, 2 Europapokale, Supercups, Nationalmannschaften mit EM und WM, vollständig eigenständige KI |
| **2 Matchsimulation** | Angriffsweise Engine, 4 Deckungen × 5 Angriffsstile, Zeitstrafen mit Unterzahl, 7-gegen-6, Auszeiten, Kabinenansprachen, Kräftehaushalt, Live-Ansicht mit gezeichnetem Feld |
| **3 Kader** | 29 Attribute, Form, Moral, Fitness, Lastkonto, Verletzungsanfälligkeit, Persönlichkeit, Potenzial, Alterskurve, individuelle Förderprogramme, eigene Nachwuchsakademie |
| **4 Transfer & Scouting** | Aktive Suche mit acht Filtern, zweistufige Verhandlung (Verein, dann Spieler), Gegenangebote, Leihen, Erfolgsprämien im Vertrag, Transferfenster mit Fristmeldungen, Scoutaufträge mit Unschärfe, gestufte Spielvorbereitung |
| **5 Vereinsführung** | Einnahmen aus Zuschauern, Sponsoring, Medien, Merchandising und Preisgeldern; sechs Ausbaubereiche; sieben Personalrollen mit messbarer Wirkung; Vorstand mit Ziel, Vertrauen, Warnstufen und Entlassung |
| **6 Trainerkarriere** | Eigener Vertrag, Ruf, Stationen, Titelsammlung, Jobangebote, Handschrift mit Prägungen — alles vereinsübergreifend |
| **7 Zeitablauf** | Tageskalender mit Vorbereitung, Trainingsalltag und Wochenrhythmus (Montag: Abrechnung, Training, Presse, Vorstand; Donnerstag: Kabine, Gerüchte), Winterpause, Transferfenster; eine Drei-Wochen-Vorschau zeigt Spiele, Fristen, Scoutberichte und Bauabschlüsse |
| **8 Immersion** | Presse und „Hallenfunk" reagieren auf Ergebnis, Derbycharakter, Serien, Einzelleistungen und Vereinslage; Pressekonferenzen vor Pflichtspielen; Rivalitäten wachsen aus Duellen; Chronik mit Titeln, Legenden, Rekorden und Saisonverlauf |
| **9 Persistenz** | 5 Speicherplätze plus automatische Sicherung (jeden Montag und zu jedem Saisonwechsel), vollständiger Zustand in einer Datei, Klartext-Beschreibung daneben, automatische Ergänzung fehlender Felder beim Laden |

---

## Aufbau des Projekts

```
project.godot
autoload/
  Stil.gd            Design-System: Farben, Typografie, Theme, Karten,
                     Abzeichen, Balken, Tabellen, Geldformatierung
  Namen.gd           Kombinatorische Namensgebung (14 Kulturen, Vor- und
                     Nachnamen getrennt, Nachnamen zusätzlich aus Stamm+Endung,
                     Orte aus Präfix+Suffix, Firmen aus Präfix+Branche+Rechtsform)
  Welt.gd            DER Spielzustand + Zeitablauf + Persistenz
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
  Vorbericht.gd      Spielvorbereitung: gestufte Gegneranalyse
  Echtdaten.gd       Lader und Zwischenspeicher für die JSON-Datensätze
  KI.gd              Aufstellung, Taktik, Training, Verträge, Ausbau der KI-Vereine
ui/
  App.gd/.tscn       Rahmen: Kopfzeile, Navigation, Bildschirmwechsel
  Bildschirm.gd      Grundklasse aller Bildschirme
  LiveSpiel.gd       Live-Ansicht einer Partie
  widgets/           Wappen, Spielfeld, Bausteine, Spieler-, Vereins-, Bericht-,
                     Presse- und Vorberichtsfenster
  bildschirme/       22 Bildschirme
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

**Bildschirme werden gebaut, nicht erzeugt.** Alle 22 Bildschirme hängen von
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
