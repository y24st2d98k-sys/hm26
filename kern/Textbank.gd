class_name Textbank
extends RefCounted
## Alles, was im Spiel gesprochen und geschrieben wird.
##
## Die Sätze standen verstreut in Matchsim, Presse, Vorstand und Medien, meist
## zu dritt oder zu viert. Nach zwei Spieltagen kannte man sie, nach einer
## Saison las man sie nicht mehr. Ein Managerspiel lebt aber davon, dass die
## Welt spricht — und eine Welt, die sich alle vierzig Minuten wiederholt,
## spricht nicht, sie klappert.
##
## Hier liegen sie zusammen, nach Situation sortiert. Der Bestand liefert
## immer eine Liste und zieht nie selbst: der Aufrufer nimmt seinen eigenen
## Zufallsgenerator. Nur so bleibt eine Partie bei gleicher Saat dieselbe
## Partie — und genau davon leben die Messsonden.

# =========================================================== Spielbericht ===
#
# Jede Zeile hat genau ein %s für den Namen des Werfers. Die Zeilen sind
# absichtlich kurz: sie laufen im Ticker durch, und was länger als eine Zeile
# ist, liest im Spiel niemand.

const TOR := {
	"KM": [
		"%s dreht sich am Kreis durch.",
		"Anspiel an den Kreis — %s trifft.",
		"%s setzt sich im Zweikampf durch und trifft.",
		"%s nimmt den Ball im Fallen und drückt ihn über die Linie.",
		"Der Kreisläufer steht frei: %s bedankt sich.",
		"%s wird angespielt, dreht ein und trifft aus dem Sechser.",
		"Kurzes Anspiel, kurzer Weg — %s vollendet.",
		"%s behauptet den Raum und trifft aus der Drehung.",
		"Die Abwehr rückt zu spät zusammen, %s ist durch.",
		"%s fängt den Ball im Sprung und trifft im Fallen.",
	],
	"LA": [
		"%s fliegt vom Flügel ein.",
		"%s hebelt den Torwart vom Flügel aus.",
		"Sauberer Winkel: %s trifft von außen.",
		"%s zieht in den Kreis und hebt den Ball über den Torwart.",
		"Von ganz außen: %s findet den kurzen Winkel.",
		"%s springt weit in den Kreis hinein und trifft.",
		"Der Linksaußen kommt frei — %s macht keinen Fehler.",
		"%s wirft den Torwart aus und trifft im langen Eck.",
	],
	"RA": [
		"%s fliegt vom Flügel ein.",
		"%s trifft aus dem spitzen Winkel.",
		"Der Rechtsaußen ist da: %s verwandelt.",
		"%s zieht nach innen und schließt ab.",
		"Schneller Seitenwechsel, %s steht frei und trifft.",
		"%s hebt den Ball über den herauslaufenden Torwart.",
		"Von der rechten Außenbahn: %s trifft ins kurze Eck.",
		"%s nimmt den Winkel, den es gar nicht gibt — drin.",
	],
	"RM": [
		"%s zieht selbst ab und trifft.",
		"%s findet die Lücke im Zentrum.",
		"Der Spielmacher entscheidet sich selbst: %s trifft.",
		"%s täuscht den Pass an und wirft.",
		"Durch die Mitte: %s setzt sich gegen zwei Gegenspieler durch.",
		"%s nimmt Tempo auf und schließt aus dem Rückraum Mitte ab.",
		"Kein Abspiel — %s macht es allein.",
		"%s wartet, bis der Block springt, und wirft unten durch.",
	],
	"RUECKRAUM": [
		"%s hämmert den Ball aus dem Rückraum ins Netz.",
		"Schlagwurf von %s — drin.",
		"%s trifft nach Doppelpass aus dem Rückraum.",
		"%s zieht von neun Metern ab und trifft.",
		"Über den Block: %s findet den Weg.",
		"%s setzt zum Sprungwurf an und trifft aus vollem Lauf.",
		"Die Abwehr rückt heraus, %s wirft trotzdem — und trifft.",
		"%s dreht sich aus dem Block heraus und wirft.",
		"Aus zehn Metern: %s lässt dem Torwart keine Chance.",
		"%s nimmt Anlauf und schlägt den Ball auf den Boden ins Tor.",
	],
	"SIEBENMETER": [
		"%s verwandelt den Siebenmeter sicher.",
		"%s legt sich den Ball zurecht und trifft.",
		"Vom Strich: %s bleibt ruhig.",
		"%s wartet den Torwart aus und schiebt ein.",
		"Kein Zögern — %s trifft vom Siebenmeter.",
		"%s trifft flach ins lange Eck.",
	],
	"GEGENSTOSS": [
		"Tempogegenstoß! %s schließt eiskalt ab.",
		"Der lange Pass sitzt — %s läuft allein aufs Tor.",
		"%s ist als Erster unterwegs und vollendet.",
		"Nach dem Ballgewinn geht es schnell: %s trifft.",
		"Zweite Welle, %s zieht durch und trifft.",
		"%s wird geschickt und lässt dem Torwart keine Chance.",
	],
	"SIEBEN_GEGEN_SECHS": [
		"Im 7-gegen-6 findet %s die Lücke.",
		"Die Überzahl im Angriff zahlt sich aus: %s trifft.",
		"Mit dem siebten Feldspieler: %s steht frei.",
		"%s nutzt den freien Raum, den das leere Tor erkauft.",
	],
}

## Ein Torwart haelt in einer Bundesligapartie rund dreiundzwanzig Mal. Mit
## zehn Saetzen stand jeder davon zweimal im Ticker; deshalb sind es jetzt
## mehr. Ein Platzhalter, und Zeilen ohne Namen sind erlaubt — Textbank.satz
## setzt nur ein, wo etwas einzusetzen ist.
const PARADE := [
	"Parade!",
	"Gehalten — starke Reaktion.",
	"%s ist im Weg und hält.",
	"Der Torwart wehrt ab.",
	"%s bringt noch die Hand dran.",
	"Gehalten! Der Torwart war früher unten.",
	"%s pariert mit dem Fuß.",
	"Kein Durchkommen — %s hält den Ball fest.",
	"Der Wurf war platziert, %s war besser.",
	"%s wirft sich in den Winkel und kratzt den Ball heraus.",
	"%s hat die Ecke gelesen.",
	"Mit dem Oberschenkel geklärt — %s bleibt dran.",
	"%s macht sich lang und hält.",
	"Der Ball klatscht %s auf die Brust.",
	"Stark! %s war schon unterwegs, bevor der Ball kam.",
	"%s lässt sich nicht täuschen.",
	"Die Halle steht: %s hält den Ball.",
	"Aus kurzer Distanz gehalten — das war Reflex, nicht Stellung.",
	"%s wehrt mit dem Handrücken ab, der Ball springt ins Seitenaus.",
	"%s bleibt lange stehen und macht das Tor zu.",
]

const FEHLWURF := [
	"%s setzt den Ball an den Pfosten.",
	"%s wirft vorbei.",
	"Daneben — %s ärgert sich.",
	"%s zielt zu hoch, der Ball geht über die Latte.",
	"An die Querlatte und darüber.",
	"%s trifft nur das Außennetz.",
	"Der Wurf von %s verfehlt das Tor deutlich.",
	"Pfosten! %s kann es nicht fassen.",
	"%s zieht ab und verzieht.",
	"Innenpfosten und heraus — %s hält sich den Kopf.",
	"%s wirft aus der Drehung und trifft nichts.",
	"Am kurzen Eck vorbei.",
	"%s bekommt den Arm nicht frei und wirft ins Nichts.",
	"Der Ball segelt über das Tor in die Zuschauer.",
]

## Fuer den Fall, dass kein Blocker feststeht. Ein Platzhalter: der Werfer.
const BLOCK := [
	"Block! Der Wurf von %s wird abgewehrt.",
	"Die Abwehr stellt sich in den Weg — Block gegen %s.",
	"%s findet keinen Weg vorbei, der Ball wird geblockt.",
	"Geblockt. Die Hände standen richtig.",
	"%s wirft in den Block.",
]

## Und der Normalfall: der Blocker ist bekannt.
##
## Achtung, die Reihenfolge ist fest: erst der Blocker, dann der Werfer. Und
## jede Zeile braucht genau zwei Platzhalter, sonst bricht der Aufruf.
##
## Diese Bank gab es nicht, und deshalb war die alte darueber praktisch tot:
## Matchsim zog einen Satz und ueberschrieb ihn anschliessend mit einem festen
## "X stellt sich in den Wurf von Y", sobald ein Blocker feststand — und das
## stand er fast immer. Knapp acht Blocks je Partie, ein einziger Satzbau.
const BLOCK_NAMEN := [
	"%s stellt sich in den Wurf von %s.",
	"%s blockt den Wurf von %s.",
	"%s bekommt die Hände hoch — geblockt gegen %s.",
	"Block von %s! %s findet keinen Weg durch.",
	"%s wirft %s den Ball vom Arm.",
	"%s steht richtig und wehrt den Wurf von %s ab.",
	"%s greift zu und blockt %s.",
	"Da ist %s im Weg, und %s bleibt nur der Ärger.",
	"%s macht den Raum zu, %s wirft in die Hände.",
	"Der Wurf von %s prallt an %s ab.",
]

## Ohne bekannten Verursacher. Keine Platzhalter.
const BALLVERLUST := [
	"Ballverlust.",
	"Der Pass kommt nicht an.",
	"Technischer Fehler — der Ball ist weg.",
	"Der Angriff verpufft, der Ball geht zurück.",
	"Schrittfehler.",
	"Der Ball rutscht durch die Hände.",
	"Abgefangen! Die Abwehr liest den Pass.",
	"Stürmerfoul — Ball und Angriff sind weg.",
]

## Mit bekanntem Verursacher — ein Platzhalter, sein Name.
##
## Dieselbe Geschichte wie beim Block: Matchsim schrieb bisher immer
## "Schrittfehler: Müller." und liess die Bank darueber liegen. Rund elf
## technische Fehler je Mannschaft und Partie in genau einer Form.
## Die Art des Fehlers steht bewusst nicht in diesen Zeilen: sie wird an
## anderer Stelle gewuerfelt, und eine Zeile, die "vertaendelt" sagt, passt
## nicht zu jedem gezogenen Grund.
const BALLVERLUST_NAMEN := [
	"%s vertändelt den Ball.",
	"%s bringt den Pass nicht an.",
	"Der Ball rutscht %s durch die Hände.",
	"%s wird abgefangen — der Angriff ist vorbei.",
	"%s geht einen Schritt zu weit.",
	"%s setzt sich durch und wird dafür gepfiffen.",
	"Die Abwehr liest %s wie ein Buch.",
	"%s verliert den Ball am Kreis.",
	"%s will zu viel und verliert den Ball.",
	"Der Pass von %s landet im Seitenaus.",
	"%s stolpert über den eigenen Anlauf.",
	"Ballverlust durch %s — die Halle stöhnt.",
]

const ZEITSTRAFE := [
	"Zwei Minuten für %s.",
	"%s muss runter — Zeitstrafe.",
	"Das war zu viel: %s sieht die Zeitstrafe.",
	"Die Schiedsrichter zeigen auf die Bank. %s nimmt Platz.",
	"%s geht für zwei Minuten vom Feld.",
	"Gestreckter Arm, klare Sache: zwei Minuten für %s.",
	"%s hält fest und wird dafür bestraft.",
	"Der Pfiff kommt sofort — %s sitzt zwei Minuten.",
	"%s diskutiert, aber die Zeitstrafe steht.",
	"Zeitstrafe gegen %s. Die Mannschaft spielt in Unterzahl weiter.",
]

const AUSZEIT := [
	"%s nimmt die Auszeit.",
	"Grüne Karte: %s unterbricht.",
	"%s holt die Mannschaft zusammen.",
	"Auszeit %s — die Tafel kommt hoch.",
	"%s reißt die Partie an sich und nimmt die Auszeit.",
	"Die grüne Karte von %s liegt auf dem Tisch.",
	"%s bittet zur Besprechung an die Bank.",
	"Auszeit für %s. Der Trainer zeichnet auf die Tafel.",
]

## Der Wechsel ist das haeufigste Ereignis des Spiels: neunzehn Mal je Partie,
## gemessen mit werkzeuge/Tickersonde.gd, und bis hierher immer derselbe Satz —
## sechshundertsiebenundfuenfzig Mal in vierunddreissig Partien. Kein anderer
## Text im Spiel kam auf ein Zehntel davon.
##
## Drei Platzhalter in fester Reihenfolge: Verein, der Kommende, der Gehende.
const WECHSEL := [
	"Wechsel bei %s: %s kommt für %s.",
	"%s wechselt: %s für %s.",
	"%s bringt %s, %s geht vom Feld.",
	"Bei %s kommt %s für %s.",
	"%s tauscht %s ein, %s aus.",
	"Wechsel an der Bank von %s — %s für %s.",
	"%s schickt %s aufs Feld, %s nimmt Platz.",
	"%s: %s ersetzt %s.",
	"Frische Beine bei %s: %s kommt, %s geht.",
	"%s nimmt %s vom Feld und bringt dafür %s.",
	"Neu bei %s: %s, dafür raus %s.",
	"%s wechselt durch — %s kommt für %s.",
]

## Der gehaltene Siebenmeter hat seinen eigenen Satz, weil er ein eigenes
## Ereignis ist — der Torwart gegen einen Mann, sonst nichts. Ein Platzhalter:
## der Torwart. Zeilen ohne Namen sind erlaubt.
const SIEBENMETER_GEHALTEN := [
	"%s hält den Siebenmeter!",
	"Gehalten! %s bleibt Sieger im Duell vom Punkt.",
	"%s ahnt die Ecke und hält.",
	"Der Strafwurf bleibt liegen — %s war da.",
	"%s hält! Die Halle explodiert.",
	"Vom Punkt gehalten. %s hat sich nicht bewegt, bis der Ball kam.",
	"%s wehrt den Siebenmeter mit dem Fuß ab.",
	"Kein Tor vom Punkt — %s hat gelesen, wohin er geht.",
]

## Ein Platzhalter: der Verwarnte.
const VERWARNUNG := [
	"Gelbe Karte für %s.",
	"%s sieht die Gelbe Karte.",
	"Verwarnung gegen %s.",
	"Die Schiedsrichter verwarnen %s.",
	"Gelb für %s — die nächste Aktion kostet zwei Minuten.",
	"%s wird verwarnt und weiß, was das heißt.",
	"Erste Verwarnung für %s.",
	"Gelbe Karte: %s hat zu hart zugepackt.",
]

## Zwei Platzhalter in fester Reihenfolge: Verein, dann der Schuetze.
const SIEBENMETER := [
	"Siebenmeter für %s — %s legt sich den Ball zurecht.",
	"Strafwurf für %s. %s tritt an.",
	"Siebenmeter! %s bekommt ihn, %s nimmt ihn.",
	"Die Schiedsrichter zeigen auf den Punkt: Siebenmeter für %s, %s wirft.",
	"%s hat den Strafwurf, %s stellt sich an die Linie.",
	"Siebenmeter für %s — %s greift sich den Ball.",
	"Strafwurf: %s, ausgeführt von %s.",
	"Vom Punkt für %s: %s.",
]

## Ein Platzhalter: der Verein, der den Torwart herausnimmt.
const SIEBEN_GEGEN_SECHS_AN := [
	"%s nimmt den Torwart heraus und spielt 7 gegen 6.",
	"%s geht ins Risiko: leeres Tor, sieben Feldspieler.",
	"Der Torwart von %s verlässt das Tor — 7 gegen 6.",
	"%s stellt um auf sieben Feldspieler.",
	"Leeres Tor bei %s. Jetzt zählt jeder Ballverlust doppelt.",
	"%s bringt den siebten Feldspieler und lässt das Tor leer.",
	"Hohes Risiko bei %s: 7 gegen 6.",
]

## Ein Platzhalter: der Verein, der zurueckstellt.
const SIEBEN_GEGEN_SECHS_AUS := [
	"%s stellt wieder auf regulären Angriff um.",
	"Der Torwart von %s geht zurück ins Tor.",
	"%s beendet das Spiel mit sieben Feldspielern.",
	"Wieder regulär bei %s — das Tor ist besetzt.",
	"%s nimmt das Risiko heraus und spielt 6 gegen 6.",
	"Der siebte Feldspieler von %s geht runter.",
]

## Ein Platzhalter: der Verein, dem das Vorwarnzeichen gilt.
const PASSIV := [
	"Vorwarnzeichen gegen %s — das Spiel wird passiv.",
	"Die Hand geht hoch: Vorwarnzeichen gegen %s.",
	"%s muss zum Abschluss kommen — Vorwarnzeichen.",
	"Vorwarnzeichen. %s hat jetzt wenige Pässe.",
	"Zu wenig Tempo bei %s, die Schiedsrichter warnen vor.",
	"%s spielt auf Zeit, das Vorwarnzeichen steht.",
	"Passives Spiel bei %s wird angezeigt.",
]

## Achtung, die Reihenfolge der Platzhalter ist fest: erst die Zahl, dann der
## Verein. Eine Zeile, die es andersherum haette, bricht den Aufruf.
const LAUF := [
	"%d Tore in Folge für %s!",
	"%d Treffer nacheinander — %s zieht davon.",
	"Ein Lauf von %d Toren: %s dreht auf.",
	"%d Tore am Stück für %s, die Halle steht.",
	"%d in Serie — %s hat den Faden gefunden.",
]

# ============================================================ Pressefragen ===
#
# Jede Situation hat mehrere Fragen, jede Frage ihre eigenen Antworten. Die
# Wirkungswerte stehen dabei und nicht woanders: eine Antwort ohne Folge ist
# keine Entscheidung, und wer die Folge sucht, soll sie neben dem Satz finden.
#
# fans / vorstand / moral verschieben die jeweiligen Werte.
# gegner_motivation ist der Anteil, um den der Gegner zulegt — große Klappe
# kostet hier.

const PRESSE_GEGNER := [
	{
		"frage": "Wie gehen Sie die Partie gegen %s an?",
		"antworten": [
			{"text": "Wir sind klar besser und werden das zeigen.",
				"fans": 3.0, "vorstand": 0.0, "moral": 2.0, "gegner_motivation": 0.045,
				"echo": "Selbstbewusste Ansage vor dem Spiel."},
			{"text": "Ein starker Gegner. Wir müssen an unser Limit gehen.",
				"fans": 0.5, "vorstand": 1.0, "moral": 0.5, "gegner_motivation": -0.015,
				"echo": "Respektvolle Töne vor dem Anpfiff."},
			{"text": "Über den Gegner rede ich nicht, nur über uns.",
				"fans": -1.0, "vorstand": 0.5, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Wortkarg vor dem Spiel."},
			{"text": "Wir haben sie analysiert. Wir wissen, wo es wehtut.",
				"fans": 1.5, "vorstand": 1.5, "moral": 1.5, "gegner_motivation": 0.01,
				"echo": "Der Trainer verweist auf die Vorbereitung."},
		],
	},
	{
		"frage": "Was macht %s so schwer auszurechnen?",
		"antworten": [
			{"text": "Nichts. Wir kennen jeden ihrer Spielzüge.",
				"fans": 2.0, "vorstand": 0.0, "moral": 1.5, "gegner_motivation": 0.04,
				"echo": "Der Trainer gibt sich unbeeindruckt."},
			{"text": "Ihre Abwehr ist die beste der Liga. Daran muss man sich abarbeiten.",
				"fans": 0.0, "vorstand": 1.0, "moral": 0.0, "gegner_motivation": -0.02,
				"echo": "Anerkennung für den Gegner."},
			{"text": "Sie leben von ihrem Tempospiel. Das müssen wir unterbinden.",
				"fans": 1.0, "vorstand": 1.5, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer nennt den Schlüssel der Partie."},
		],
	},
	{
		"frage": "Auswärts bei %s — eine Halle, in der man selten gewinnt.",
		"antworten": [
			{"text": "Hallen gewinnen keine Spiele. Mannschaften tun das.",
				"fans": 2.5, "vorstand": 0.5, "moral": 2.0, "gegner_motivation": 0.03,
				"echo": "Der Trainer lässt sich nicht beeindrucken."},
			{"text": "Wir wissen, was da auf uns zukommt, und stellen uns darauf ein.",
				"fans": 0.0, "vorstand": 1.0, "moral": 0.5, "gegner_motivation": 0.0,
				"echo": "Nüchterne Vorbereitung auf ein schweres Auswärtsspiel."},
			{"text": "Ein Punkt dort wäre schon etwas wert.",
				"fans": -2.0, "vorstand": 0.0, "moral": -0.5, "gegner_motivation": 0.02,
				"echo": "Bescheidene Zielsetzung vor dem Auswärtsspiel."},
		],
	},
]

const PRESSE_DERBY := [
	{
		"frage": "Derby gegen %s — was bedeutet dieses Spiel für Sie?",
		"antworten": [
			{"text": "Für die Stadt ist es alles. Für uns sind es zwei Punkte.",
				"fans": -1.5, "vorstand": 1.0, "moral": 0.5, "gegner_motivation": 0.01,
				"echo": "Der Trainer nimmt dem Derby die Bedeutung."},
			{"text": "Wir wissen, was den Leuten dieses Spiel bedeutet. Wir liefern.",
				"fans": 4.5, "vorstand": 0.5, "moral": 2.5, "gegner_motivation": 0.03,
				"echo": "Klares Bekenntnis vor dem Derby."},
			{"text": "Ich habe meiner Mannschaft gesagt: Köpfe kühl halten.",
				"fans": 0.0, "vorstand": 1.5, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer mahnt zur Ruhe."},
			{"text": "Ich habe in dieser Woche kein anderes Spiel im Kopf gehabt.",
				"fans": 3.0, "vorstand": 0.0, "moral": 2.0, "gegner_motivation": 0.02,
				"echo": "Der Trainer macht seine Priorität deutlich."},
		],
	},
	{
		"frage": "Beim letzten Derby gab es Ärger auf den Rängen. Sorgen Sie sich?",
		"antworten": [
			{"text": "Das ist Sache der Vereine und der Ordner, nicht meine.",
				"fans": -1.0, "vorstand": -1.0, "moral": 0.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer weicht der Frage aus."},
			{"text": "Ich wünsche mir ein lautes Derby und ein faires.",
				"fans": 2.5, "vorstand": 2.0, "moral": 0.5, "gegner_motivation": 0.0,
				"echo": "Versöhnliche Worte vor dem Derby."},
			{"text": "Unsere Kurve weiß, wie man sich benimmt.",
				"fans": 3.5, "vorstand": 0.0, "moral": 0.0, "gegner_motivation": 0.0,
				"echo": "Rückendeckung für die eigenen Fans."},
		],
	},
]

const PRESSE_AUSSENSEITER := [
	{
		"frage": "%s gilt als Favorit. Sehen Sie das auch so?",
		"antworten": [
			{"text": "Papier wirft keine Tore.",
				"fans": 3.0, "vorstand": 0.0, "moral": 2.5, "gegner_motivation": 0.035,
				"echo": "Kampfansage des Außenseiters."},
			{"text": "Ja. Und genau deshalb haben wir nichts zu verlieren.",
				"fans": 0.5, "vorstand": 1.0, "moral": 3.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer nimmt die Last von seiner Mannschaft."},
			{"text": "Wir sind Außenseiter, der Druck liegt woanders.",
				"fans": -2.0, "vorstand": -0.5, "moral": 3.0, "gegner_motivation": 0.02,
				"echo": "Der Trainer nimmt seiner Mannschaft die Last."},
			{"text": "Favoriten gibt es nur vorher. Hinterher gibt es Ergebnisse.",
				"fans": 2.0, "vorstand": 1.0, "moral": 1.5, "gegner_motivation": 0.01,
				"echo": "Nüchtern und kämpferisch zugleich."},
		],
	},
]

const PRESSE_KRISE := [
	{
		"frage": "Drei Niederlagen nacheinander. Was läuft schief?",
		"antworten": [
			{"text": "Die Mannschaft arbeitet hart, das dreht sich wieder.",
				"fans": 0.0, "vorstand": 0.5, "moral": 3.0, "gegner_motivation": 0.0,
				"echo": "Rückendeckung für die Mannschaft."},
			{"text": "Das war zu wenig. So kann es nicht weitergehen.",
				"fans": 3.0, "vorstand": 1.5, "moral": -3.5, "gegner_motivation": 0.0,
				"echo": "Deutliche Kritik an der eigenen Mannschaft."},
			{"text": "Verletzungen und der Terminplan fordern ihren Tribut.",
				"fans": -2.5, "vorstand": -1.5, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer verweist auf die Umstände."},
			{"text": "Die Verantwortung dafür trage ich.",
				"fans": 2.0, "vorstand": -0.5, "moral": 2.5, "gegner_motivation": 0.0,
				"echo": "Der Trainer nimmt die Schuld auf sich."},
		],
	},
	{
		"frage": "Im Angriff fällt Ihrer Mannschaft seit Wochen nichts ein. Woran liegt das?",
		"antworten": [
			{"text": "An der Konsequenz. Wir erarbeiten uns Chancen und werfen sie weg.",
				"fans": 1.0, "vorstand": 1.5, "moral": -1.5, "gegner_motivation": 0.0,
				"echo": "Der Trainer benennt das Problem."},
			{"text": "Wir arbeiten im Training genau daran. Das braucht Zeit.",
				"fans": -0.5, "vorstand": 0.5, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer bittet um Geduld."},
			{"text": "Mir fällt genug ein. Es muss nur jemand auf dem Feld umsetzen.",
				"fans": 2.0, "vorstand": -1.0, "moral": -4.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer schiebt die Schuld auf die Mannschaft."},
		],
	},
	{
		"frage": "Die Kurve hat nach dem Abpfiff gepfiffen. Können Sie das verstehen?",
		"antworten": [
			{"text": "Ja. Für das, was wir gezeigt haben, waren die Pfiffe milde.",
				"fans": 3.5, "vorstand": 0.5, "moral": -2.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer gibt den Fans recht."},
			{"text": "Ich verstehe es, aber es hilft uns nicht weiter.",
				"fans": -1.0, "vorstand": 0.5, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Zwiespältige Reaktion auf die Pfiffe."},
			{"text": "Wer pfeift, treibt die Mannschaft nicht an. Wir brauchen Unterstützung.",
				"fans": -3.5, "vorstand": 0.0, "moral": 2.5, "gegner_motivation": 0.0,
				"echo": "Der Trainer geht die eigenen Fans an."},
		],
	},
]

const PRESSE_HOEHENFLUG := [
	{
		"frage": "Platz %d — reden Sie schon von der Meisterschaft?",
		"antworten": [
			{"text": "Ja. Wir wollen diesen Titel.",
				"fans": 4.0, "vorstand": 1.0, "moral": 1.5, "gegner_motivation": 0.035,
				"echo": "Der Trainer ruft das Titelziel aus."},
			{"text": "Wir schauen von Spiel zu Spiel.",
				"fans": 0.0, "vorstand": 1.0, "moral": 0.5, "gegner_motivation": 0.0,
				"echo": "Betont nüchtern trotz Tabellenführung."},
			{"text": "Dafür ist es viel zu früh.",
				"fans": -1.5, "vorstand": 0.5, "moral": 1.0, "gegner_motivation": -0.01,
				"echo": "Der Trainer bremst die Erwartungen."},
			{"text": "Fragen Sie mich das im Mai wieder.",
				"fans": 1.0, "vorstand": 1.5, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer vertagt die Frage."},
		],
	},
	{
		"frage": "Ihre Mannschaft spielt über ihren Möglichkeiten. Wie lange geht das gut?",
		"antworten": [
			{"text": "Das ist kein Zufall, das ist Arbeit. Es geht so lange gut, wie wir arbeiten.",
				"fans": 3.0, "vorstand": 2.0, "moral": 2.5, "gegner_motivation": 0.02,
				"echo": "Der Trainer verweist auf die Arbeit im Hintergrund."},
			{"text": "Über ihren Möglichkeiten? Vielleicht schätzen Sie die Möglichkeiten falsch ein.",
				"fans": 2.5, "vorstand": 0.5, "moral": 3.0, "gegner_motivation": 0.03,
				"echo": "Der Trainer weist die Einschätzung zurück."},
			{"text": "Irgendwann kommt ein Rückschlag. Dann zeigt sich, was wir sind.",
				"fans": -0.5, "vorstand": 1.5, "moral": 0.5, "gegner_motivation": 0.0,
				"echo": "Der Trainer warnt vor dem Rückschlag."},
		],
	},
]

const PRESSE_STUHL := [
	{
		"frage": "Wie sicher ist Ihr Stuhl noch?",
		"antworten": [
			{"text": "Ich mache mir keine Gedanken darüber.",
				"fans": 0.0, "vorstand": 0.0, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Gelassen trotz der Lage."},
			{"text": "Das entscheidet der Vorstand, nicht ich.",
				"fans": -2.0, "vorstand": -1.5, "moral": -1.5, "gegner_motivation": 0.0,
				"echo": "Der Trainer weicht aus."},
			{"text": "Ich stehe für meine Arbeit ein. Die Ergebnisse kommen.",
				"fans": 2.5, "vorstand": 2.0, "moral": 2.0, "gegner_motivation": 0.0,
				"echo": "Kämpferischer Auftritt."},
			{"text": "Solange ich hier sitze, wird gearbeitet. Danach auch.",
				"fans": 1.5, "vorstand": 1.0, "moral": 1.5, "gegner_motivation": 0.0,
				"echo": "Trotzige Antwort auf die Trainerfrage."},
		],
	},
	{
		"frage": "Es heißt, der Vorstand habe sich bereits nach Nachfolgern erkundigt.",
		"antworten": [
			{"text": "Dann weiß der Vorstand mehr als ich. Ich arbeite weiter.",
				"fans": 1.0, "vorstand": 0.5, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer bleibt betont ruhig."},
			{"text": "Solche Geschichten schreiben Sie, nicht der Vorstand.",
				"fans": 0.5, "vorstand": 1.5, "moral": 0.5, "gegner_motivation": 0.0,
				"echo": "Der Trainer geht die Presse an."},
			{"text": "Wenn das stimmt, soll man es mir sagen und nicht Ihnen.",
				"fans": 3.0, "vorstand": -2.5, "moral": 0.0, "gegner_motivation": 0.0,
				"echo": "Offene Kritik am eigenen Vorstand."},
		],
	},
]

const PRESSE_SPIELER := [
	{
		"frage": "%s hat einen Wechselwunsch geäußert. Wie gehen Sie damit um?",
		"antworten": [
			{"text": "Er hat einen Vertrag. Der gilt.",
				"fans": 2.0, "vorstand": 1.5, "moral": -1.5, "gegner_motivation": 0.0,
				"echo": "Der Trainer pocht auf den Vertrag."},
			{"text": "Wir reden miteinander. Niemand wird gehalten, der nicht will.",
				"fans": -1.0, "vorstand": 0.0, "moral": 2.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer zeigt sich gesprächsbereit."},
			{"text": "Dazu sage ich öffentlich nichts.",
				"fans": -0.5, "vorstand": 1.0, "moral": 0.5, "gegner_motivation": 0.0,
				"echo": "Der Trainer blockt ab."},
		],
	},
	{
		"frage": "%s ist seit Wochen in herausragender Form. Ihr Verdienst?",
		"antworten": [
			{"text": "Das ist seiner. Ich stelle ihn nur auf.",
				"fans": 1.5, "vorstand": 0.5, "moral": 3.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer stellt den Spieler heraus."},
			{"text": "Wir haben im Training gezielt daran gearbeitet.",
				"fans": 0.5, "vorstand": 2.0, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer verweist auf die Trainingsarbeit."},
			{"text": "Er ist in Form. Formen halten nicht ewig, das weiß er auch.",
				"fans": -1.0, "vorstand": 0.5, "moral": -1.5, "gegner_motivation": 0.0,
				"echo": "Nüchterne Einordnung einer Hochform."},
		],
	},
	{
		"frage": "Der Nachwuchs sitzt bei Ihnen auf der Bank. Warum?",
		"antworten": [
			{"text": "Weil sie noch nicht so weit sind. Ich verheize niemanden.",
				"fans": -1.5, "vorstand": 1.0, "moral": 0.5, "gegner_motivation": 0.0,
				"echo": "Der Trainer nimmt die Jungen in Schutz."},
			{"text": "Das ändert sich. Ich habe zwei im Blick.",
				"fans": 2.5, "vorstand": 0.5, "moral": 1.0, "gegner_motivation": 0.0,
				"echo": "Der Trainer kündigt Einsätze für den Nachwuchs an."},
			{"text": "Wir spielen um Punkte, nicht um Ausbildung.",
				"fans": -3.0, "vorstand": 0.5, "moral": 0.0, "gegner_motivation": 0.0,
				"echo": "Klare Absage an den Nachwuchs."},
		],
	},
]

## Wie die Kurve auf einen Auftritt reagiert, nach Stimmung gestaffelt.
const FANECHO := {
	"gut": [
		"In der Kurve kommt das gut an.",
		"Die Fanszene teilt den Auftritt hundertfach.",
		"Zustimmung aus dem Block: genau so habe man sich das gewünscht.",
		"Die Kurve zitiert den Satz noch am selben Abend auf einem Banner.",
	],
	"mittel": [
		"Die Reaktionen halten sich die Waage.",
		"In den Foren wird diskutiert, mehr nicht.",
		"Die Fanszene nimmt es zur Kenntnis.",
		"Ein Auftritt, über den am nächsten Tag niemand mehr spricht.",
	],
	"schlecht": [
		"In der Kurve kommt das schlecht an.",
		"Die Fanszene reagiert verschnupft.",
		"Aus dem Block heißt es, der Trainer habe den Verein nicht verstanden.",
		"Der Auftritt sorgt für Unmut unter den Anhängern.",
	],
}

# ============================================================== Vorstand ===

const VORSTAND_ZUFRIEDEN := [
	"Der Vorstand ist zufrieden mit der Entwicklung.",
	"Aus dem Präsidium heißt es, man arbeite vertrauensvoll zusammen.",
	"Der Vorstand sieht die Mannschaft auf dem vereinbarten Weg.",
	"Man sei froh, diesen Trainer verpflichtet zu haben, heißt es intern.",
	"Der Vorstand betont, dass er keinen Anlass zur Sorge sehe.",
	"Im Präsidium wird über eine vorzeitige Verlängerung nachgedacht.",
]

const VORSTAND_MAHNUNG := [
	"Der Vorstand erwartet eine Reaktion auf dem Feld.",
	"Man habe Geduld, aber sie sei nicht unbegrenzt, heißt es.",
	"Der Vorstand erinnert an das ausgegebene Saisonziel.",
	"Im Präsidium wird die Entwicklung aufmerksam verfolgt.",
	"Der Vorstand wünscht sich mehr Konstanz in den Ergebnissen.",
	"Man werde in den kommenden Wochen genau hinsehen.",
]

const VORSTAND_WARNUNG := [
	"Der Vorstand stellt die Trainerfrage.",
	"Im Präsidium wird offen über Konsequenzen gesprochen.",
	"Der Vorstand sieht die sportliche Führung in der Pflicht.",
	"Man könne nicht ausschließen, dass gehandelt werden müsse.",
	"Der Vorstand hat den Trainer zu einem Gespräch gebeten.",
	"Aus dem Präsidium dringt Unzufriedenheit nach außen.",
]

const VORSTAND_FINANZEN := [
	"Der Vorstand mahnt zur Sparsamkeit.",
	"Das Präsidium erinnert daran, dass der Etat eine Grenze hat.",
	"Der Vorstand erwartet, dass die Kasse am Saisonende ausgeglichen ist.",
	"Man habe kein Geld zu verschenken, heißt es aus der Geschäftsstelle.",
	"Der Vorstand verweist auf die Auflagen der Lizenzierung.",
]

const VORSTAND_LOB_JUGEND := [
	"Der Vorstand lobt ausdrücklich den Mut, auf die eigene Jugend zu setzen.",
	"Dass Eigengewächse spielen, kommt im Präsidium gut an.",
	"Der Vorstand sieht die Nachwuchsarbeit als Aushängeschild.",
	"Man schätze, dass der Weg über die eigene Akademie gegangen werde.",
]

# ============================================================ Spielerworte ===

const SPIELER_LOB_ANGENOMMEN := [
	"%s nimmt das Lob dankbar an.",
	"%s sagt, er habe es gebraucht.",
	"Man sieht %s an, dass die Worte angekommen sind.",
	"%s nickt nur — und arbeitet am nächsten Tag härter.",
]

const SPIELER_LOB_ABGEPRALLT := [
	"%s wirkt unbeeindruckt.",
	"%s hat das schon oft gehört.",
	"%s nimmt es hin, ohne dass sich etwas ändert.",
]

const SPIELER_KRITIK_ANGENOMMEN := [
	"%s nimmt die Kritik an und verspricht mehr Einsatz.",
	"%s widerspricht nicht. Er weiß, dass es stimmt.",
	"%s sagt, er werde es besser machen — und meint es.",
]

const SPIELER_KRITIK_ABGEPRALLT := [
	"%s fühlt sich ungerecht behandelt.",
	"%s sieht die Schuld woanders.",
	"%s verlässt das Gespräch, ohne etwas zu sagen.",
	"%s findet, andere hätten die Kritik nötiger.",
]

const SPIELER_TRANSFERWUNSCH := [
	"%s sagt, er brauche eine neue Aufgabe.",
	"%s findet, er sei hier an einem Punkt angekommen.",
	"%s bittet darum, sich mit anderen Vereinen unterhalten zu dürfen.",
	"%s sagt, es liege nicht am Verein, sondern an ihm.",
]

# =========================================================== Zugriff ===
#
# Die Bank zieht nie selbst. Wer einen Satz braucht, nimmt seinen eigenen
# Zufallsgenerator — sonst wäre eine Partie bei gleicher Saat nicht mehr
# dieselbe Partie, und genau davon leben die Sonden.

## Die Liste für eine Wurfposition. RL, RR und alles Unbekannte teilen sich
## den Rückraum.
static func tortexte(pos: String) -> Array:
	if TOR.has(pos):
		return TOR[pos]
	return TOR["RUECKRAUM"]

## Ein Satz aus einer Liste, gezogen mit dem Generator des Aufrufers.
static func waehle(liste: Array, rng: RandomNumberGenerator) -> String:
	if liste.is_empty():
		return ""
	return str(liste[rng.randi_range(0, liste.size() - 1)])

## Ein Satz mit eingesetzten Namen — und zwar auch dann, wenn die gezogene
## Zeile gar keinen Platzhalter hat.
##
## Nicht jede Zeile braucht einen Namen: "An die Querlatte und darüber." steht
## für sich. Wer stumpf % anwendet, bekommt von Godot ein "not all arguments
## converted" und einen leeren Text im Ticker — genau das ist beim ersten
## Anschluss passiert. Deshalb prüft diese Funktion, ob überhaupt etwas
## einzusetzen ist.
static func satz(liste: Array, rng: RandomNumberGenerator, werte: Variant = null) -> String:
	var t := waehle(liste, rng)
	if werte == null or not (t.contains("%s") or t.contains("%d")):
		return t
	return t % werte
