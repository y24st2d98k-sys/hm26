class_name Konkurrenz
extends RefCounted
## Wer sonst noch hinter einem Spieler her ist.
##
## Ein Transfer war bisher ein Gespräch unter vier Augen: der Trainer bietet,
## der Verein antwortet, der Spieler sagt ja oder nein. Niemand sonst wollte
## denselben Mann. Damit fehlte dem Markt die einzige Kraft, die ihn zu einem
## Markt macht — dass ein anderer schneller sein kann.
##
## Dieser Bestand beantwortet zwei Fragen: Wer interessiert sich noch? Und:
## Was passiert, wenn ich zu lange überlege?

## Wie viele Vereine höchstens genannt werden. Mehr liest niemand, und eine
## Liste mit zwölf Namen sagt weniger als eine mit dreien.
const HOECHSTENS := 4
## Ab diesem Interesse gilt ein Verein als ernsthafter Bewerber.
const SCHWELLE := 0.42

## Die Vereine, die diesen Spieler wollen, mit ihrem Interesse (0 bis 1).
## [{verein, interesse, name}] — stärkstes Interesse zuerst.
## Ein Tagesspeicher fuer die Interessentenliste.
##
## Gemessen hat der Transferbildschirm 10 152 ms gebraucht und einzelne
## Tageswechsel bis 10 579 ms. Der Grund stand hier: die Abloesevorstellung
## jedes Spielers fragt den Preisaufschlag, der Preisaufschlag die
## Interessenten, und die Interessenten jeden der 156 Vereine der Welt —
## jeden mit einem Durchlauf durch seinen Kader. Bei 3624 Spielern sind das
## Millionen Schritte fuer eine Zahl, die sich an einem Tag nicht aendert.
##
## Also wird sie an einem Tag auch nur einmal gerechnet. Ein Transfer macht
## den Speicher ungueltig, denn danach stimmt der Kader nicht mehr, aus dem
## der Bedarf gelesen wurde.
static var _speicher := {}
static var _speicher_tag := -1

static func speicher_leeren() -> void:
	_speicher.clear()
	_speicher_tag = -1

## Wie weit ein Verein vom Niveau eines Spielers entfernt sein darf.
##
## Das ist nicht nur schneller, sondern richtiger: ein Verein, dessen Niveau
## sechsundzwanzig Punkte neben dem Spieler liegt, ist kein Mitbewerber —
## er kann ihn nicht bezahlen oder wuerde ihn nie aufstellen. Vorher konnte
## ein solcher Verein ueber Bedarf und Plan trotzdem ueber die Schwelle
## kommen.
const NIVEAU_FENSTER := 26.0

static func interessenten(d: Dictionary, sid: String) -> Array:
	var aus: Array = []
	var sp: Dictionary = (d.get("spieler", {}) as Dictionary).get(sid, {})
	if sp.is_empty() or bool(sp.get("jugendspieler", false)):
		return aus
	var heute: int = Welt.tag()
	if heute != _speicher_tag:
		_speicher.clear()
		_speicher_tag = heute
	if _speicher.has(sid):
		return (_speicher[sid] as Array).duplicate()
	var verein: String = str(sp.get("verein", ""))
	var staerke: float = Spielerfabrik.gesamt(sp)
	var pos: String = str(sp["position"])
	for cid in Weltgenerator.clubs(d):
		if cid == verein or cid == Welt.mein_verein_id:
			continue
		var v: Dictionary = d["vereine"][cid]
		if bool(v.get("ist_nationalteam", false)) or bool(v.get("ist_mensch", false)):
			continue
		# Erst die billigen Ausschluesse, dann die teure Rechnung.
		if (v.get("kader", []) as Array).size() >= 22:
			continue
		if absf(staerke - (float(v.get("ruf", 60.0)) * 0.9 + 6.0)) > NIVEAU_FENSTER:
			continue
		var wert: float = _interesse(d, cid, sp, staerke, pos)
		if wert < SCHWELLE:
			continue
		aus.append({"verein": cid, "interesse": wert, "name": str(v["name"])})
	aus.sort_custom(func(a, b): return float(a["interesse"]) > float(b["interesse"]))
	aus = aus.slice(0, HOECHSTENS)
	_speicher[sid] = aus
	return aus.duplicate()

## Wie sehr ein Verein diesen Spieler will.
##
## Drei Dinge entscheiden: passt er zur Stärke des Vereins, fehlt er dort auf
## seiner Position, und passt er zum Plan der Spielzeit. Ein Verein im Umbruch
## will den Zwanzigjährigen, einer im Abstiegskampf den fertigen Mann.
static func _interesse(d: Dictionary, cid: String, sp: Dictionary, staerke: float,
		pos: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var kader: Array = v.get("kader", [])
	if kader.size() >= 22:
		return 0.0
	# Zu stark ist so uninteressant wie zu schwach: niemand holt einen, den er
	# nicht bezahlen kann, und niemand holt einen, der nie spielen würde.
	var niveau: float = float(v.get("ruf", 60.0)) * 0.9 + 6.0
	var passung: float = clampf(1.0 - absf(staerke - niveau) / 26.0, 0.0, 1.0)
	var auf_position := 0
	for s2 in kader:
		var anderer: Dictionary = (d["spieler"] as Dictionary).get(str(s2), {})
		if not anderer.is_empty() and str(anderer["position"]) == pos:
			auf_position += 1
	var bedarf: float = clampf(1.0 - float(auf_position) * 0.34, 0.0, 1.0)
	var plan: float = clampf(Vereinsplan.kandidatengewicht(d, cid, sp), 0.35, 1.25)
	# Hier bewusst der Marktwert und nicht Transfermarkt.abloesevorstellung():
	# die fragt inzwischen nach dem Preisaufschlag, der Preisaufschlag fragt
	# nach den Interessenten, und die Interessenten fragen wieder nach dem
	# Preis. Eine Endlosrekursion, die sich erst im laufenden Spiel gezeigt
	# haette.
	var geld: float = clampf(float(v.get("transferbudget", 0.0))
		/ maxf(float(sp.get("wert", 1.0)), 1.0), 0.0, 1.2)
	return clampf(passung * 0.4 + bedarf * 0.3 + (plan - 0.35) * 0.3 + geld * 0.18, 0.0, 1.0)

## Ein Satz für die Oberfläche: wie es um die Konkurrenz steht.
static func lage(d: Dictionary, sid: String) -> String:
	var liste := interessenten(d, sid)
	if liste.is_empty():
		return "Kein anderer Verein zeigt Interesse. Sie haben Zeit."
	if liste.size() == 1:
		return "%s beobachtet ihn ebenfalls." % str((liste[0] as Dictionary)["name"])
	var namen: Array = []
	for e in liste.slice(0, 3):
		namen.append(str((e as Dictionary)["name"]))
	return "%s sind ebenfalls dran. Wer zu lange überlegt, verliert ihn." % ", ".join(
		PackedStringArray(namen))

## Was die Konkurrenz kostet.
##
## Ein Spieler, hinter dem drei Vereine her sind, wird teurer — beim Verein
## wie beim Spieler selbst. Das ist der ganze Unterschied zwischen einer
## Preisliste und einem Markt.
const AUFSCHLAG_JE_BEWERBER := 0.09

static func preisaufschlag(d: Dictionary, sid: String) -> float:
	var liste := interessenten(d, sid)
	var summe := 0.0
	for e in liste:
		summe += float((e as Dictionary)["interesse"])
	return 1.0 + clampf(summe * AUFSCHLAG_JE_BEWERBER, 0.0, 0.42)

## Einmal pro Woche: greift ein Konkurrent zu?
##
## Nur für Spieler, die der Mensch gerade im Blick hat — beobachtet, auf der
## Merkliste oder in einer laufenden Verhandlung. Für alle anderen erledigt
## das die gewöhnliche KI-Transferrunde, und ein Bestand, der über jeden
## Spieler der Welt würfelt, kostet Rechenzeit ohne Gegenwert.
const ZUGRIFF_GRUNDRISIKO := 0.16

static func wochenrunde(d: Dictionary) -> void:
	var cid: String = Welt.mein_verein_id
	if cid == "" or not Transfermarkt.fenster_offen(d):
		return
	for sid in _im_blick(d, cid):
		var sp: Dictionary = (d["spieler"] as Dictionary).get(sid, {})
		if sp.is_empty() or str(sp.get("verein", "")) == cid:
			continue
		var liste := interessenten(d, sid)
		if liste.is_empty():
			continue
		var bester: Dictionary = liste[0]
		if Namen.zufall() > ZUGRIFF_GRUNDRISIKO * float(bester["interesse"]):
			continue
		_zugreifen(d, sid, str(bester["verein"]))

## Die Spieler, die der Trainer im Blick hat.
static func _im_blick(d: Dictionary, cid: String) -> Array:
	var aus: Array = []
	for sid in (d.get("scouting", {}).get("beobachtung", []) as Array):
		aus.append(str(sid))
	for a in (d.get("transfermarkt", {}).get("angebote", []) as Array):
		var ang: Dictionary = a
		if str(ang.get("nach", "")) == cid and not (str(ang.get("status", "")) in
				["abgeschlossen", "abgelehnt", "zurueckgezogen"]):
			aus.append(str(ang["spieler"]))
	return aus

static func _zugreifen(d: Dictionary, sid: String, kaeufer: String) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var von: String = str(sp.get("verein", ""))
	var abloese: float = Transfermarkt.ablösevorstellung(d, sid) if von != "" else 0.0
	var v: Dictionary = d["vereine"][kaeufer]
	if abloese > float(v.get("transferbudget", 0.0)):
		return
	var gehalt: float = Spielerfabrik.gehaltsvorstellung(sp, float(v["ruf"]),
		Finanzen.lohnniveau(d, kaeufer))
	Transfermarkt.transfer_durchfuehren(d, sid, kaeufer, abloese, gehalt,
		Namen.wuerfel(2, 4), "rotation")
	Welt.nachricht({
		"typ": "transfer", "wichtig": true,
		"betreff": "%s wechselt zu %s" % [Spielerfabrik.voller_name(sp), str(v["name"])],
		"text": "Sie hatten ihn im Blick — %s war schneller. Ablöse: %s.\n\nWer einen Spieler beobachtet und nicht handelt, überlässt ihn jemandem, der handelt." % [
			str(v["name"]), Stil.geld(abloese)],
		"daten": {"spieler": sid},
	})
