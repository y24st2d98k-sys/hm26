# HALLENHERZ

Ein Handball-Manager für Godot 4.x. Deutschsprachige Oberfläche, vollständig
prozedural erzeugte Grafik (keine einzige Bilddatei), ein zentraler Spielzustand
und eine Simulation, die den Sport ernst nimmt: Zeitstrafen erzeugen echte
Unterzahl, Abwehr und Angriff sind zwei getrennte Aufstellungen, und wer den
Torwart für das 7-gegen-6 herausnimmt, riskiert den Ball im leeren Tor.

---

## Starten

```bash
godot4 --path .            # Spiel starten
```

Zum Prüfen ohne Editor:

```bash
godot4 --headless res://werkzeuge/Testlauf.tscn -- welt        # Weltgenerierung
godot4 --headless res://werkzeuge/Testlauf.tscn -- spiele      # 300 Partien, Kennzahlen
godot4 --headless res://werkzeuge/Testlauf.tscn -- halbsaison  # halbe Saison
godot4 --headless res://werkzeuge/Testlauf.tscn -- langzeit    # drei Saisons am Stück
godot4 --headless res://werkzeuge/Oberflaechentest.tscn        # alle Bildschirme + Live-Spiel + Speichern
```

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
| Tore pro Spiel (gesamt) | 58,1 | ~58 |
| Heim : Gast | 29,7 : 28,4 | ~30 : 28 |
| Zeitstrafen pro Spiel | 8,0 | ~8 |
| Siebenmeter pro Spiel | 7,2 | ~7 |
| Technische Fehler | 19,0 | ~20 |
| Paraden pro Spiel | 28,0 | ~28 |
| Heimsiegquote | 55,0 % | ~57 % |

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
* **Verletzungen während der Partie** mit sofortigem Ausfall.
* **Tempogegenstöße**, Blocks, Ballgewinne, Siebenmeter, Zeitspiel,
  Verlängerung und Siebenmeterwerfen in K.-o.-Partien.

In der Live-Ansicht sieht man das Feld mit beiden Siebenern, den Ball an der
Wurfposition, den Ticker, den Hallenpuls und die Kräfte jedes Spielers — und
kann jederzeit wechseln, Auszeit nehmen, die Deckung umstellen oder den Torwart
herausnehmen.

---

## Die Spielwelt

* **5 Nationen, 8 Ligen, 96 Vereine, ~1.900 Spieler.** Deutschland, Dänemark
  und Frankreich mit zwei Spielklassen und echtem Auf- und Abstieg (je zwei
  Vereine pro Saison), Spanien und Polen eingleisig.
* **5 nationale Pokale** im K.-o.-System mit Freilosen für die stärksten
  Vereine und Heimrecht für den unterklassigen Verein.
* **Zwei internationale Wettbewerbe:** die *Kontinentalkrone* (16 Teams, vier
  Gruppen, dann K.-o. mit Hin- und Rückspiel) und die *Challenge-Trophäe*
  (reines K.-o.). Qualifikation über die Abschlusstabellen und Pokalsieger.
* **Nationale Supercups** zwischen Meister und Pokalsieger.
* Die Welt lebt ohne Zutun weiter: KI-Vereine stellen auf, passen ihre Taktik
  an den Gegner an, transferieren, verlängern Verträge, bauen aus, ersetzen
  altersbedingt ausscheidendes Personal und ziehen jedes Jahr eigene Talente
  nach.

---

## Die neun Säulen im Überblick

| Säule | Umsetzung |
|---|---|
| **1 Liga-Welt** | 5 Nationen / 8 Ligen / 96 Vereine, Auf- und Abstieg, 5 Pokale, 2 Europapokale, Supercups, vollständig eigenständige KI |
| **2 Matchsimulation** | Angriffsweise Engine, 4 Deckungen × 5 Angriffsstile, Zeitstrafen mit Unterzahl, 7-gegen-6, Auszeiten, Kräftehaushalt, Live-Ansicht mit gezeichnetem Feld |
| **3 Kader** | 29 Attribute, Form, Moral, Fitness, Lastkonto, Verletzungsanfälligkeit, Persönlichkeit, Potenzial, Alterskurve, individuelle Förderprogramme |
| **4 Transfer & Scouting** | Aktive Suche mit acht Filtern, zweistufige Verhandlung (Verein, dann Spieler), Gegenangebote, Leihen, Transferfenster mit Fristmeldungen, Scoutaufträge mit Unschärfe |
| **5 Vereinsführung** | Einnahmen aus Zuschauern, Sponsoring, Medien, Merchandising und Preisgeldern; sechs Ausbaubereiche; sieben Personalrollen mit messbarer Wirkung; Vorstand mit Ziel, Vertrauen, Warnstufen und Entlassung |
| **6 Trainerkarriere** | Eigener Vertrag, Ruf, Stationen, Titelsammlung, Jobangebote, Handschrift mit Prägungen — alles vereinsübergreifend |
| **7 Zeitablauf** | Tageskalender mit Trainingsalltag, Wochenrhythmus (Montag: Abrechnung, Training, Presse, Vorstand; Donnerstag: Kabine, Gerüchte), Winterpause, Transferfenster |
| **8 Immersion** | Presse und „Hallenfunk" reagieren auf Ergebnis, Derbycharakter, Serien, Einzelleistungen und Vereinslage; Rivalitäten wachsen aus Duellen; Chronik mit Titeln, Legenden, Rekorden und Saisonverlauf |
| **9 Persistenz** | 5 Speicherplätze, vollständiger Zustand in einer Datei, Klartext-Beschreibung daneben, automatische Ergänzung fehlender Felder beim Laden |

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
  Statistik.gd       Tabellen, Vereins- und Spielerstatistik, Torjäger
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
  KI.gd              Aufstellung, Taktik, Training, Verträge, Ausbau der KI-Vereine
ui/
  App.gd/.tscn       Rahmen: Kopfzeile, Navigation, Bildschirmwechsel
  Bildschirm.gd      Grundklasse aller Bildschirme
  LiveSpiel.gd       Live-Ansicht einer Partie
  widgets/           Wappen, Spielfeld, Bausteine, Spieler-/Vereins-/Berichtsfenster
  bildschirme/       19 Bildschirme
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

**Bildschirme werden gebaut, nicht erzeugt.** Alle 19 Bildschirme hängen von
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

**Taktikänderungen im Spiel gelten nur für dieses Spiel.** Die Simulation
arbeitet auf einer Kopie der Vereinstaktik. Wer dauerhaft umstellen will, tut
das auf dem Aufstellungsbildschirm.
