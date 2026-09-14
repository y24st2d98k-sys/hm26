class_name Videostudium
extends RefCounted
## Den nächsten Gegner am Bildschirm studieren.
##
## Ein Trainerteam sitzt vor jedem Spiel stundenlang vor Aufzeichnungen: wer
## wirft aus welcher Position, wann kommt die Manndeckung, was macht der
## Kreisläufer beim Sperrenlaufen. Das Spiel kannte davon nichts — die
## Vorbereitung bestand aus Training, Taktik und einem Matchplan, aber nicht
## aus der Arbeit, die diesem Matchplan vorausgeht.
##
## **Der Preis ist Trainingszeit.** Wer die Woche über Video schaut, steht
## solange nicht in der Halle: jede Einheit Videostudium kostet Entwicklung.
##
## **Und der Gegner schaut auch.** Das ist der Kern: die Wirkung im Spiel hängt
## nicht daran, wie viel man selbst gearbeitet hat, sondern am *Unterschied*
## zum Gegenüber. Wer gut vorbereitet gegen einen ebenso gut vorbereiteten
## Gegner antritt, hat gar nichts gewonnen — genau wie in Wirklichkeit. Wer gar
## nichts tut und auf ein Trainerteam trifft, das die ganze Woche studiert hat,
## merkt es dagegen.
##
## Die Wirkung ist bewusst klein. Videostudium gewinnt kein Spiel; es
## entscheidet ein enges.

## Wie viele Wocheneinheiten höchstens ins Video gehen.
const EINHEITEN_MAX := 3
## Was eine Einheit an Trainingsentwicklung kostet, als Anteil.
const KOSTEN_JE_EINHEIT := 0.13
## Wie viel Vorbereitung eine Einheit einbringt. Die zweite und dritte bringen
## weniger als die erste — irgendwann kennt man die Aufzeichnungen auswendig.
const ERTRAG := [0.0, 1.0, 1.7, 2.1]
## Der größte Vorsprung, den ein Unterschied im Studium im Spiel ausmacht.
## Zweieinhalb Prozent auf Angriff und Abwehr sind ein Tor über sechzig
## Minuten — spürbar in einer engen Partie, bedeutungslos in einer klaren.
const WIRKUNG_MAX := 0.025
## Ab welchem Vorsprung die volle Wirkung erreicht ist.
const VORSPRUNG_VOLL := 4.0

static func stand(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("videostudium"):
		v["videostudium"] = {"einheiten": 0, "gegner": "", "arbeit": 0.0}
	return v["videostudium"]

## Wie viele Einheiten der Verein in dieser Woche ansetzt.
static func einheiten(d: Dictionary, cid: String) -> int:
	return clampi(int(stand(d, cid).get("einheiten", 0)), 0, EINHEITEN_MAX)

static func einheiten_setzen(d: Dictionary, cid: String, anzahl: int) -> void:
	stand(d, cid)["einheiten"] = clampi(anzahl, 0, EINHEITEN_MAX)

## Was das Studium die Trainingsentwicklung kostet, als Faktor auf den Zuwachs.
static func trainingsfaktor(d: Dictionary, cid: String) -> float:
	return clampf(1.0 - float(einheiten(d, cid)) * KOSTEN_JE_EINHEIT, 0.5, 1.0)

## Eine Woche Arbeit. Wird im Wochenwechsel für jeden Verein aufgerufen.
##
## Studiert wird immer der nächste Gegner. Wechselt der — weil die Partie
## gespielt ist oder der Spielplan einen anderen bringt —, ist die Arbeit
## verfallen: Aufzeichnungen von Flensburg helfen gegen Erlangen nicht.
static func wochenwechsel(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var s := stand(d, cid)
		var naechster := _naechster_gegner(d, str(cid))
		if naechster != str(s.get("gegner", "")):
			s["gegner"] = naechster
			s["arbeit"] = 0.0
		if naechster == "":
			continue
		var anzahl: int = einheiten(d, str(cid))
		if anzahl <= 0:
			continue
		# Ein gutes Trainerteam holt mehr aus derselben Zeit.
		var guete: float = 0.65 + Training.trainerqualitaet(d, str(cid), "taktik") / 160.0
		s["arbeit"] = float(s["arbeit"]) + float(ERTRAG[clampi(anzahl, 0, EINHEITEN_MAX)]) * guete

static func _naechster_gegner(d: Dictionary, cid: String) -> String:
	var m: Dictionary = Welt.naechstes_spiel(cid)
	if m.is_empty():
		return ""
	return str(m["gast"]) if str(m["heim"]) == cid else str(m["heim"])

## Was die Vorbereitung in dieser Partie wert ist.
##
## Gerechnet wird der Unterschied, nicht der eigene Stand. Zwei gleich gut
## vorbereitete Mannschaften heben sich auf.
static func vorteil(d: Dictionary, cid: String, gegner: String) -> float:
	var eigen := stand(d, cid)
	var fremd := stand(d, gegner)
	var meine: float = float(eigen["arbeit"]) if str(eigen.get("gegner", "")) == gegner else 0.0
	var seine: float = float(fremd["arbeit"]) if str(fremd.get("gegner", "")) == cid else 0.0
	var vorsprung: float = meine - seine
	return clampf(vorsprung / VORSPRUNG_VOLL, -1.0, 1.0) * WIRKUNG_MAX

## Nach der Partie ist die Arbeit verbraucht.
static func verbrauchen(d: Dictionary, cid: String) -> void:
	var s := stand(d, cid)
	s["arbeit"] = 0.0
	s["gegner"] = ""

## Wie die Lage in Worten dasteht — für den Trainingsbildschirm.
static func lagetext(d: Dictionary, cid: String) -> String:
	var s := stand(d, cid)
	var gegner: String = str(s.get("gegner", ""))
	if gegner == "" or not d["vereine"].has(gegner):
		return "Kein nächster Gegner in Sicht."
	var meine: float = float(s["arbeit"])
	if meine < 0.4:
		return "Über %s liegt noch nichts Ausgewertetes vor." % str(d["vereine"][gegner]["name"])
	if meine < 1.6:
		return "Erste Aufzeichnungen über %s sind gesichtet." % str(d["vereine"][gegner]["name"])
	if meine < 3.2:
		return "%s ist ordentlich analysiert — die Abläufe sind bekannt." % str(d["vereine"][gegner]["name"])
	return "%s ist durchleuchtet. Mehr ist aus den Aufzeichnungen nicht herauszuholen." % str(d["vereine"][gegner]["name"])
