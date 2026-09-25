class_name Jugend
extends RefCounted
## Das Nachwuchszentrum.
##
## Talente kommen nicht mehr fertig in den Profikader, sondern in einen eigenen
## Jugendbereich. Dort entwickeln sie sich schneller als Profis, aber nur so gut,
## wie Jugendarbeit und Nachwuchskoordinator es hergeben. Wer bis 20 nicht
## befördert wird, verlässt den Verein — die Entscheidung, wann ein Talent den
## Sprung schafft, liegt beim Trainer.

const HOECHSTALTER := 20
const KADER_GRENZE := 26

static func liste(d: Dictionary, cid: String) -> Array:
	var v: Dictionary = d["vereine"].get(cid, {})
	if v.is_empty():
		return []
	if not v.has("jugend"):
		v["jugend"] = []
	var sortiert: Array = (v["jugend"] as Array).duplicate()
	sortiert.sort_custom(func(a, b):
		return float(d["spieler"][a]["potenzial"]) > float(d["spieler"][b]["potenzial"]))
	return sortiert

## Qualität der Nachwuchsarbeit eines Vereins (0..100).
static func arbeitsqualitaet(d: Dictionary, cid: String) -> float:
	var v: Dictionary = d["vereine"][cid]
	var basis: float = float(v["infrastruktur"]["jugendarbeit"]) * 7.0
	for pid in v["personal"]:
		var mp: Dictionary = d["personal"].get(pid, {})
		if str(mp.get("rolle", "")) == "nachwuchs":
			basis += float((mp["attr"] as Dictionary).get("jugendarbeit", 8.0)) * 1.6
	if Trainerkarriere.bonus_fuer(d, cid, "talentfluesterer"):
		basis += 8.0
	return clampf(basis, 5.0, 100.0)

# ------------------------------------------------------------ Jahrgang ---

## Wie oft ein Jahrgang jemanden hervorbringt, der die Decke der Jugendarbeit
## durchstoesst. Bei rund zehn Talenten je Jahrgang und Verein heisst das etwa
## alle zwei Jahre einen in der ganzen Liga.
const AUSNAHMETALENT := 0.045

static func erzeuge_jahrgang(d: Dictionary, cid: String, anzahl: int) -> Array:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("jugend"):
		v["jugend"] = []
	var qualitaet := arbeitsqualitaet(d, cid)
	var neue: Array = []
	for i in range(anzahl):
		var positionen: Array = Spielerfabrik.POSITIONEN
		var pos: String = str(positionen[Namen.wuerfel(0, positionen.size() - 1)])
		var basis: float = 20.0 + qualitaet * 0.13 + float(v["ruf"]) * 0.10
		var ziel: float = clampf(Namen.glocke(basis, 5.0, 12.0, 55.0), 12.0, 55.0)
		var sid := Weltgenerator.neue_spieler_id(d)
		var sp := Spielerfabrik.erzeuge(sid, Namen.kultur_zufall(str(v["nation"]), 0.85),
			Namen.wuerfel(16, 18), ziel, pos, int(d["startjahr"]))
		# Die Jugendarbeit entscheidet vor allem über das Potenzial.
		sp["potenzial"] = clampf(float(sp["potenzial"]) + qualitaet * 0.22 + Namen.bereich(-6.0, 10.0), ziel + 4.0, 96.0)
		# Und selten kommt einer, der alles überragt.
		#
		# Ohne diese Ausnahme hatte die Akademie eine harte Decke: das beste
		# Potenzial, das sie je vergab, lag bei knapp achtzig. Über die Jahre
		# sank das Niveau der Liga damit zwangsläufig auf das der Jugendarbeit
		# ab, weil die echten Spieler abtraten und niemand nachkam, der sie
		# ersetzen konnte. Ein Jahrgang alle paar Jahre bringt jetzt einen, der
		# es bis ganz nach oben schaffen kann — schaffen muss er es selbst.
		if Namen.zufall() < AUSNAHMETALENT:
			sp["potenzial"] = clampf(float(sp["potenzial"]) + Namen.bereich(9.0, 26.0), ziel + 4.0, 97.0)
		sp["verein"] = cid
		sp["jugendspieler"] = true
		sp["aus_eigener_jugend"] = true
		sp["kenntnis"] = clampf(45.0 + qualitaet * 0.35, 40.0, 92.0)
		# Kein Gehalt.
		#
		# In einer Akademie verdient niemand etwas — es ist eine Ausbildung
		# mit Schule daneben, kein Arbeitsverhältnis. Bis hierher stand hier
		# ein Wochengehalt von zwei- bis dreihundert Euro; bezahlt wurde es
		# nie (Finanzen.spielergehaelter zählt nur den Profikader), aber es
		# stand im Vertrag, wurde angezeigt und ging bei der Beförderung als
		# Untergrenze in das erste Profigehalt ein. Was die Ausbildung kostet,
		# steht ohnehin woanders: in der Ausbaustufe Jugendarbeit.
		sp["vertrag"] = {
			"bis_saison": Welt.saison_index() + Namen.wuerfel(2, 4),
			"gehalt": 0.0,
			"rolle": "talent",
			"ablöseklausel": 0.0,
			"unterschrieben_saison": Welt.saison_index(),
			"praemie_tor": 0.0, "praemie_sieg": 0.0,
		}
		sp["wert"] = Spielerfabrik.marktwert(sp)
		d["spieler"][sid] = sp
		(v["jugend"] as Array).append(sid)
		neue.append(sid)
	return neue

# ------------------------------------------------------------ Ablauf ---

## Entwicklung der Talente. Läuft parallel zum Profitraining, aber nach
## eigenen Regeln: schneller, dafür stärker von der Jugendarbeit abhängig.
static func wochenwechsel(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		if not v.has("jugend"):
			v["jugend"] = []
		var qualitaet: float = arbeitsqualitaet(d, cid) / 100.0
		# Wer in einer kommunalen Halle mit Harzverbot trainiert, wirft mit
		# einem kleineren, harzfreien Ball. Die Ballbehandlung ist eine
		# andere, und der Uebergang in den Profikader wird dadurch schwerer —
		# eine Eigenheit, die es so nur im Handball gibt.
		qualitaet *= Lizenzierung.nachwuchsfaktor(d, str(cid))
		for sid in (v["jugend"] as Array).duplicate():
			if not d["spieler"].has(sid):
				(v["jugend"] as Array).erase(sid)
				continue
			var sp: Dictionary = d["spieler"][sid]
			var gesamt: float = Spielerfabrik.gesamt(sp)
			var luft: float = clampf((float(sp["potenzial"]) - gesamt) / maxf(float(sp["potenzial"]), 1.0), 0.0, 1.0)
			var arbeitseinsatz: float = float(sp["attr"]["arbeitseinsatz"]) / 20.0
			# Spielpraxis ist der Teil der Entwicklung, den kein Training
			# ersetzt. Wer in der Zweiten Minuten sammelt, kommt schneller
			# voran als jemand, der nur mittrainiert.
			var praxis: float = Zweite.entwicklungsschub(sp)
			var zuwachs: float = 0.085 * (0.35 + 1.2 * luft) * (0.45 + 0.9 * qualitaet) * (0.6 + 0.6 * arbeitseinsatz) * praxis
			if zuwachs > 0.0:
				var attr_liste: Array = _foerderattribute(sp)
				for i in range(2):
					if attr_liste.is_empty():
						break
					var a: String = str(Namen.waehle(attr_liste))
					sp["attr"][a] = clampf(float(sp["attr"][a]) + zuwachs * Namen.bereich(0.5, 1.7), 1.0, 20.0)
				Spielerfabrik.staerke_verwerfen(sp)
			sp["kenntnis"] = clampf(float(sp["kenntnis"]) + 0.35 + qualitaet, 0.0, 100.0)
			sp["wert"] = Spielerfabrik.marktwert(sp)
			sp["fitness"] = clampf(float(sp["fitness"]) + 1.0, 40.0, 100.0)
			sp["last"] = clampf(float(sp["last"]) - 2.0, 0.0, 100.0)
		if not bool(v.get("ist_mensch", false)):
			ki_pflege(d, cid)

static func _foerderattribute(sp: Dictionary) -> Array:
	if bool(sp["ist_torwart"]):
		return Spielerfabrik.ATTR_TORWART.duplicate()
	var gew: Dictionary = Spielerfabrik.ANGRIFF_GEWICHTE.get(str(sp["position"]), {})
	var liste: Array = gew.keys()
	liste.append_array(["block", "deckungsarbeit", "zweikampf", "ausdauer", "physis"])
	return liste

## Zum Saisonwechsel: zu alte Talente verlassen den Verein.
static func jahreswechsel(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		var v: Dictionary = d["vereine"][cid]
		for sid in (v["jugend"] as Array).duplicate():
			if not d["spieler"].has(sid):
				(v["jugend"] as Array).erase(sid)
				continue
			var sp: Dictionary = d["spieler"][sid]
			if int(sp["alter"]) < HOECHSTALTER:
				continue
			# Wer den Sprung nicht schafft, sucht sich einen anderen Weg.
			(v["jugend"] as Array).erase(sid)
			sp["jugendspieler"] = false
			sp["verein"] = ""
			KI.freie_leeren()  # er steht jetzt im Markt der Vereinslosen
			sp["vertrag"] = {}
			if cid == Welt.mein_verein_id:
				Welt.nachricht({
					"typ": "jugend",
					"betreff": "%s verlässt den Nachwuchs" % Spielerfabrik.voller_name(sp),
					"text": "%s ist mit %d Jahren aus dem Jugendbereich herausgewachsen und wurde nicht befördert. Er ist jetzt vereinslos." % [
						Spielerfabrik.voller_name(sp), int(sp["alter"])],
				})

# --------------------------------------------------------- Entscheidungen ---

static func befoerdern(d: Dictionary, sid: String) -> Dictionary:
	var sp: Dictionary = d["spieler"].get(sid, {})
	if sp.is_empty():
		return {"ok": false, "grund": "Spieler nicht gefunden."}
	var cid: String = str(sp["verein"])
	var v: Dictionary = d["vereine"][cid]
	if not (v["jugend"] as Array).has(sid):
		return {"ok": false, "grund": "Dieser Spieler ist nicht im Nachwuchs."}
	if (v["kader"] as Array).size() >= KADER_GRENZE:
		return {"ok": false, "grund": "Der Profikader ist voll (max. %d Spieler)." % KADER_GRENZE}
	(v["jugend"] as Array).erase(sid)
	(v["kader"] as Array).append(sid)
	Trikot.vergeben(d, cid, sid)
	Laufbahn.aus_der_jugend(d, sid, cid)
	sp["jugendspieler"] = false
	# Wer hier hochkommt, bleibt ein Eigengewaechs dieses Vereins — auch wenn
	# er in zehn Jahren woanders spielt. Der Vorstand rechnet damit, die Fans
	# rechnen damit, und die Laufbahn erzaehlt es.
	sp["ausbildungsverein"] = cid
	sp["kenntnis"] = 100.0
	sp["moral"] = clampf(float(sp["moral"]) + 15.0, 5.0, 100.0)
	sp["vertrag"]["rolle"] = "talent"
	# Der erste Profivertrag. Er bemisst sich an dem, was der Spieler heute
	# kann — nicht an dem, was in seinem Fördervertrag stand, denn dort stand
	# nichts.
	sp["vertrag"]["gehalt"] = Finanzen.gehaltswunsch(d, cid, sp) * 0.6
	# Der Vorstand sieht Nachwuchsarbeit gern — je nach eigener Haltung.
	var jugendfokus: float = float(v["vorstand"].get("jugendfokus", 50.0))
	v["vorstand"]["vertrauen"] = clampf(float(v["vorstand"]["vertrauen"]) + jugendfokus * 0.02, 0.0, 100.0)
	if cid == Welt.mein_verein_id:
		Medien.artikel(d, "%s rückt in den Profikader" % Spielerfabrik.voller_name(sp),
			"Der %d-jährige %s aus der eigenen Jugend erhält einen Platz im Profikader von %s." % [
				int(sp["alter"]), Spielerfabrik.POSITION_NAME[str(sp["position"])], str(v["name"])],
			"lob", "jugend", {"spieler": sid})
	return {"ok": true, "grund": "%s gehört ab sofort zum Profikader." % Spielerfabrik.voller_name(sp)}

static func freigeben(d: Dictionary, sid: String) -> Dictionary:
	var sp: Dictionary = d["spieler"].get(sid, {})
	if sp.is_empty():
		return {"ok": false, "grund": "Spieler nicht gefunden."}
	var cid: String = str(sp["verein"])
	(d["vereine"][cid]["jugend"] as Array).erase(sid)
	sp["jugendspieler"] = false
	sp["verein"] = ""
	KI.freie_leeren()  # er steht jetzt im Markt der Vereinslosen
	sp["vertrag"] = {}
	return {"ok": true, "grund": "%s wurde aus dem Nachwuchs entlassen." % Spielerfabrik.voller_name(sp)}

## KI-Vereine befördern von selbst, wenn ein Talent gut genug ist.
static func ki_pflege(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if (v["jugend"] as Array).is_empty():
		return
	var schnitt := 0.0
	var n := 0
	for sid in v["kader"]:
		schnitt += Spielerfabrik.gesamt(d["spieler"][sid])
		n += 1
	schnitt = schnitt / maxf(float(n), 1.0)
	for sid2 in (v["jugend"] as Array).duplicate():
		var sp: Dictionary = d["spieler"][sid2]
		var reif: bool = Spielerfabrik.gesamt(sp) > schnitt - 14.0 and int(sp["alter"]) >= 18
		# Wer aus der Jugend herauswaechst, bekommt eine zweite Chance — aber
		# keinen Freifahrtschein.
		#
		# Bis hierher genuegte dafuer das Potenzial. Ein Neunzehnjaehriger mit
		# einer Decke von 74 rueckte damit auf, auch wenn er erst bei 41 stand,
		# und blieb dann im Profikader stehen, weil er dort keine Minuten
		# bekommt. Gemessen an der Alterskurve, die der Weltgenerator anlegt,
		# fehlten den Neunzehnjaehrigen der Liga dadurch 15,8 Punkte und den
		# Zwanzigjaehrigen 11,8 — im Mittel 8,11 ueber die Jahrgaenge 19 bis 28.
		#
		# In der Wirklichkeit steht im Profikader eines Bundesligisten kein
		# Neunzehnjaehriger, der noch nicht so weit ist. Wer es nicht schafft,
		# geht eine Liga tiefer — und genau das passiert jetzt:
		# Jugend.jahreswechsel gibt ihn mit zwanzig frei, und dort holt ihn
		# ein Verein, zu dem er passt.
		var draengt: bool = int(sp["alter"]) >= HOECHSTALTER - 1 \
			and float(sp["potenzial"]) > schnitt \
			and Spielerfabrik.gesamt(sp) > schnitt - 22.0
		if (reif or draengt) and (v["kader"] as Array).size() < 24:
			befoerdern(d, sid2)

## Einschätzung eines Talents in Worten — abhängig davon, wie gut man es kennt.
static func einschaetzung(d: Dictionary, sid: String) -> String:
	var sp: Dictionary = d["spieler"][sid]
	var kenntnis: float = float(sp["kenntnis"])
	var abstand: float = float(sp["potenzial"]) - Spielerfabrik.gesamt(sp)
	var text := Scouting.potenzial_text(d, sid)
	if kenntnis < 60.0:
		return "%s (noch schwer zu greifen)" % text
	if abstand < 8.0:
		return "%s — fast am Limit" % text
	if abstand > 30.0:
		return "%s — noch weit entfernt" % text
	return "%s, %s" % [text, Scouting.tempo_text(d, sid)]
