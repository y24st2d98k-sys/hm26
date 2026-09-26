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
| `ligen[].teams` | Ligagröße. Ist `vereine` leer, erfindet das Spiel so viele Vereine; nennt `vereine` weniger, ergänzt es erfundene bis zu dieser Zahl. |
| `ligen[].playoffs` | `8` oder `4`: Meister wird, wer die Play-offs gewinnt (Viertel-, Halbfinale, Finale mit Hin- und Rückspiel). Die Hauptrunde endet dann Anfang April. |
| `ligen[].teilweise_echt` | Nur Kennzeichnung: die Liga nennt einige echte Vereine, der Rest ist erfunden. |
| `nationen[].cl_plaetze` / `el_plaetze` | Startplätze in EHF Champions League und European League. Ohne Angabe entscheidet der Ruf der Nation. |
| `ligen[].erzeugt` | Nur Kennzeichnung für den Datenbericht. |
| `vereine[].ruf` | Ansehen des Vereins (0–100). **Der wichtigste Wert:** er bestimmt Kaderstärke, Etat, Hallenpuls und die Erwartung des Vorstands. |
| `vereine[].farben` | Zwei Hex-Farben für das prozedural gezeichnete Wappen. |
| `vereine[].trainer` | Cheftrainer: `{"vorname", "nachname", "nation", "alter", "seit": 2021, "archetyp"}` oder einfach `"Vorname Nachname"`. Er sitzt als Gegnertrainer auf der Bank, bis er entlassen wird. `archetyp` ist einer aus `Gegnertrainer.ARCHETYPEN` (`techniker`, `tempomacher`, `betonmischer`, …); ohne Angabe wird gewürfelt. |
| `vereine[].stab` | Namen im Trainerstab: `{"cotrainer": "…", "torwarttrainer": "…", "athletiktrainer": "…", "physio": "…", "analyst": "…", "nachwuchs": "…"}`. Die Fähigkeiten würfelt das Spiel. |
| `vereine[].etat` | Jahresetat in Euro. Verschiebt den Richtwert des Vereins dauerhaft — als Verhältnis, damit Auf- und Abstieg weiter wirken. |
| `vereine[].sponsoren` | Echte Partner je Platz: `{"Trikotbrust": "…", "Hallenname": "…", "Ausrüster": "…", "Ärmel": "…", "Rückenpartner": "…"}`. Die Summen schätzt das Spiel. |
| `vereine[].zuschauerschnitt` | Zuschauerschnitt der Vorsaison. Eine volle Halle heißt treue, zufriedene Fans. |
| `geprueft` | `false` heißt: nach Wissensstand eingetragen, nicht gegen eine Quelle geprüft. Bitte kontrollieren. Gilt auch in `kader.json`. |

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
| `bild` | Dateiname des Portraitfotos in `assets/gesichter/` (ohne Endung). Ohne Angabe wird er aus dem Namen abgeleitet — siehe `assets/README.md`. |
| `geburtsdatum` | `"1994-02-28"` oder `"28.02.1994"`. Geht vor `alter`; der Spieler hat dann an seinem echten Tag Geburtstag. |
| `hand` | `"L"` oder `"R"`: Wurfhand. **Wirkt:** ein Rechtshänder, der auf Rückraum rechts oder Rechtsaußen umgestellt wird, verliert deutlich an Eignung, ein Linkshänder gewinnt dort. Ohne Angabe würfelt das Spiel nach Position (rechte Seite fast immer links). |
| `groesse` / `gewicht` | In Zentimetern und Kilogramm. Nur Anzeige. |
| `zweitpositionen` | Weitere Positionen, z. B. `["RL", "RM"]`. Dort spielt er fast so gut wie auf seiner eigenen. |
| `vertrag_bis` | Jahr, in dem der Vertrag am 30. Juni endet (`2028` = bis Ende der Saison 2027/28). |
| `gehalt` | Jahresgehalt brutto in Euro. |
| `klausel` | Festgeschriebene Ausstiegsklausel in Euro. |
| `verletzt` | Verletzt zum Start: `{"art": "Kreuzbandriss", "tage": 180}` oder `{"art": "…", "bis": "2027-01-15"}`. |
| `vorvertrag` | Exakter Name des Vereins, bei dem er für die nächste Saison schon unterschrieben hat. Er wechselt im Sommer ablösefrei. |
| `kapitaen` | `true`: trägt die Binde. |

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

* **Verlässlich:** Vereinsnamen, Ligazugehörigkeit und Ligagrößen der Saison 2026/27
  für die Bundesliga, Frankreich, Spanien, Dänemark, Polen, Ungarn, Slowenien,
  Rumänien und Österreich — abgeglichen über die Ansetzungen des ersten Spieltags.
  Die Teilnehmer der Champions League 2026/27 (21 von 24) aus der Auslosung.
  Die DHB-Schiedsrichtergespanne 2026/27.
* **Nach Wissensstand, ungeprüft:** die Ligen in Portugal, Norwegen, Schweden,
  Kroatien, Nordmazedonien und der Schweiz, die Unterhäuser außerhalb
  Deutschlands, die internationalen Gespanne und alle Einträge mit
  `"geprueft": false`. Was im Einzelnen zu prüfen ist, steht in
  [`PRUEFLISTE.md`](PRUEFLISTE.md) — neu erzeugen mit `python3 werkzeuge/pruefliste.py`.
* **Näherung:** Hallennamen, Kapazitäten, Gründungsjahre, Vereinsfarben, alle Ruf-Werte.
* **Vollständig:** die Kader aller 18 Bundesligisten — 327 Spieler, kein einziger
  ergänzt. Wer im Spiel für einen deutschen Erstligisten auf dem Bogen steht, steht
  dort auch in Wirklichkeit.
* **Lückenhaft:** alle übrigen Ligen. Bei den Europapokal-Teilnehmern sind die
  tragenden Spieler und die Neuzugänge 2026/27 hinterlegt, soweit sie sich
  belegen ließen; den Rest füllt das Spiel auf. Die 2. Bundesliga hat noch keine
  echten Spieler.
* **Schätzwerte, keine Tatsachenbehauptungen:** Alter und Stärke. Das Alter ist zum
  1. September 2026 gerechnet, die Stärke ordnet einen Spieler nur für die
  Simulation ein.

Kader veralten mit jedem Transferfenster. Die Dateien sind bewusst so einfach
gehalten, dass sie sich ohne Programmierkenntnisse pflegen lassen.

---

## `spielplan.json` — echte Ansetzungen

Ohne diese Datei lost das Spiel eine Doppelrunde aus. Sie ist eine Doppelrunde,
aber nicht die richtige — und ob die drei schwersten Auswärtsspiele im
September oder im April liegen, entscheidet über eine Saison mit.

```json
{
  "version": 1,
  "stand": "September 2026",
  "spielplaene": {
    "Opel Handball-Bundesliga": {
      "saison": "2026/27",
      "partien": [
        {"spieltag": 1, "datum": "2026-08-27", "zeit": "19:00",
         "heim": "THW Kiel", "gast": "TBV Lemgo Lippe"}
      ]
    }
  }
}
```

Der Schlüssel ist der **exakte Liganame** aus `ligen.json`, die Vereinsnamen
ebenso. `datum` und `zeit` dürfen leer bleiben; gebraucht werden `spieltag`,
`heim` und `gast`.

**Vollständig oder angefangen.** Sind alle Partien hinterlegt — bei 18 Vereinen
sind das 306 —, gilt der Plan unverändert. Das ist der Normalfall für einen
offiziellen Spielplan. Ist er unvollständig, muss mindestens ein Spieltag
komplett sein: an dem verankert sich das Spiel und ergänzt den Rest zu einer
sauberen Doppelrunde. Ohne einen vollständigen Spieltag gibt es nichts zu
verankern, dann wird ausgelost.

**Warum nicht einfach auffüllen?** Eine Doppelrunde ist keine beliebige
Verteilung von Paarungen auf Spieltage, sondern eine Zerlegung in lauter
vollständige Paarungsrunden. Wer sie Partie für Partie füllt, sitzt am Ende
zuverlässig mit zwei Mannschaften da, die schon gegeneinander gespielt haben;
sechzig Anläufe eines gierigen Verfahrens sind in der Erprobung ausnahmslos
gescheitert. Das Spiel geht deshalb vom Kreisverfahren aus, das eine gültige
Doppelrunde von sich aus liefert, und benennt die Mannschaften so um, dass der
verankerte Spieltag genau aufgeht.

**Geht ein Plan nicht auf, wird er ganz verworfen** und die Saison ausgelost.
Ein halb richtiger Spielplan wäre schlechter als ein ausgeloster: er sähe echt
aus und wäre es nicht. Warum er verworfen wurde, steht als Warnung im Protokoll.

Einspielen lässt sich ein Plan auch aus dem Spiel heraus: Datenbildschirm,
Abschnitt „Spielplan einspielen", eine Zeile je Partie als
`Spieltag;Datum;Zeit;Heim;Gast`. Das landet in `user://spielplan_eigen.json`
und überlebt jede Aktualisierung des Spiels. Wirksam wird es beim Anlegen
einer neuen Karriere — eine laufende Saison behält ihren Spielplan, weil ein
Neuansetzen mitten im Oktober gespielte Partien verwerfen würde.

Geprüft wird das von `werkzeuge/Spielplantest.tscn`.

---

## `schiedsrichter.json` — echte Gespanne

```json
{"gespanne": [{"a": "Robert Schulze", "b": "Tobias Tönnies", "nation": "de", "erfahrung": 12}]}
```

Die Namen stehen fest, Strenge, Zweikampflinie, Heimneigung und Konstanz
würfelt das Spiel — außer sie stehen als Zahl von 5 bis 95 im Eintrag
(`"strenge": 70`). Ligaspiele bekommen ein Gespann aus dem eigenen Land; wo
der Datensatz weniger als drei kennt, ergänzt das Spiel erfundene.

---

## Rechtliches

Vereins- und Personennamen sind hier zu dem Zweck erfasst, ein privates Spiel
realistisch zu machen. Für eine Veröffentlichung des Spiels wären Namens- und
Markenrechte zu klären. Wer das vermeiden will, startet eine Karriere mit
abgehaktem Häkchen "Echte Vereine" — dann erzeugt das Spiel wie zuvor eine
vollständig erfundene Welt.
