class_name KI
extends RefCounted
## Die Entscheidungen der Computervereine: Aufstellung, Taktik, Trainingsplan,
## Vertragsverlaengerungen und Personalarbeit. Die Welt lebt dadurch auch dann
## weiter, wenn der Spieler sich um nichts kuemmert.

static func aufstellung_pruefen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if bool(v.get("ist_nationalteam", false)):
		# Betreut der Spieler diese Auswahl, bleibt seine Aufstellung stehen.
		if not bool(v.get("ist_mensch", false)):
			Weltgenerator.setze_standardaufstellung(d, cid)
		elif not (v["aufstellung"].get("angriff", {}) as Dictionary).has("TW"):
			Weltgenerator.setze_standardaufstellung(d, cid)
		return
	# Vor jeder Partie: jeder im Kader traegt eine eindeutige Rueckennummer.
	Trikot.kader_nummerieren(d, cid)
	var mensch: bool = bool(v.get("ist_mensch", false))
	if mensch:
		# Gespeicherte Spielidee zur Lage gegen diesen Gegner ziehen.
		var naechstes: Dictionary = Welt.naechstes_spiel(cid)
		if not naechstes.is_empty():
			var gegner: String = str(naechstes["gast"]) if str(naechstes["heim"]) == cid else str(naechstes["heim"])
			var gezogen := Taktikprofile.automatisch_anwenden(d, cid, gegner)
			if gezogen != "" and str(v.get("letztes_profil", "")) != gezogen:
				v["letztes_profil"] = gezogen
				Welt.nachricht({
					"typ": "taktik",
					"betreff": "Spielidee gewechselt: %s" % gezogen,
					"text": "Gegen %s greift Ihre hinterlegte Regel für die Lage „%s“." % [
						str(d["vereine"].get(gegner, {}).get("name", "den Gegner")),
						str(Taktikprofile.LAGEN[Taktikprofile.lage_gegen(d, cid, gegner)]["name"])],
				})
	var auf: Dictionary = v["aufstellung"]
	var neu_aufstellen := false
	if mensch:
		if bool(d["einstellungen"].get("auto_aufstellung", true)):
			# Der Trainerstab stellt vor jeder Partie die beste verfügbare Sieben.
			Weltgenerator.setze_standardaufstellung(d, cid)
			return
		# Sonst nur eingreifen, wenn jemand ausfaellt.
		for block in ["angriff", "abwehr"]:
			for pos in (auf.get(block, {}) as Dictionary).keys():
				var sid: String = str(auf[block][pos])
				if sid == "" or not d["spieler"].has(sid):
					neu_aufstellen = true
					continue
				var sp: Dictionary = d["spieler"][sid]
				if not (sp["verletzung"] as Dictionary).is_empty() or int(sp["sperre"]) > 0 or str(sp["verein"]) != cid:
					neu_aufstellen = true
		if not neu_aufstellen:
			auf["bank"] = Weltgenerator.bank_aus_kader(d, cid, auf)
			return
		Weltgenerator.setze_standardaufstellung(d, cid)
		return
	Weltgenerator.setze_standardaufstellung(d, cid)
	taktik_anpassen(d, cid)

## Wie viele Partien ein Trainerteam zurueckschaut, wenn es den Gegner liest.
const LESEFENSTER := 6
## Ab welchem Anteil ein Angriff als Handschrift gilt und nicht als Zufall.
const HANDSCHRIFT := 0.5

## Was ein Verein zuletzt gespielt hat — die Grundlage jeder Vorbereitung.
##
## Ohne diese Liste kann niemand den Gegner lesen, und ohne Lesen gibt es
## keine Gegenmassnahme. Sechs Eintraege reichen: wer in sechs Partien
## viermal dasselbe gespielt hat, hat eine Handschrift.
static func stil_verbuchen(d: Dictionary, cid: String, stil: String) -> void:
	if not (d.get("vereine", {}) as Dictionary).has(cid):
		return
	var v: Dictionary = d["vereine"][cid]
	var liste: Array = v.get("angriffsverlauf", [])
	liste.append(stil)
	while liste.size() > LESEFENSTER:
		liste.pop_front()
	v["angriffsverlauf"] = liste

## Der Angriff, den ein Verein erkennbar bevorzugt — oder "" fuer unlesbar.
static func handschrift(d: Dictionary, cid: String) -> String:
	var liste: Array = (d.get("vereine", {}) as Dictionary).get(cid, {}).get("angriffsverlauf", [])
	if liste.size() < 3:
		return ""
	var zaehler := {}
	for e in liste:
		zaehler[str(e)] = int(zaehler.get(str(e), 0)) + 1
	var oft := ""
	var n := 0
	for k in zaehler.keys():
		if int(zaehler[k]) > n:
			n = int(zaehler[k])
			oft = str(k)
	return oft if float(n) / float(liste.size()) >= HANDSCHRIFT else ""

## Alle Computertrainer eines Spieltags bereiten sich vor — vor dem Anwurf.
##
## Das passiert nicht erst in Matchsim, damit der Vorbericht den Plan zeigen
## kann, bevor die Partie laeuft. Wer Videostudium betrieben hat, soll wissen,
## was auf ihn zukommt; das ist der Ertrag dieser Arbeit.
static func matchplaene_fuer_tag(d: Dictionary, partien: Array) -> void:
	for mid in partien:
		var m: Dictionary = (d.get("spiele", {}) as Dictionary).get(str(mid), {})
		if m.is_empty() or bool(m.get("gespielt", false)) or str(m.get("art", "")) == "turnier":
			continue
		matchplan_stellen(d, str(m["heim"]), str(m["gast"]), str(mid))
		matchplan_stellen(d, str(m["gast"]), str(m["heim"]), str(mid))

## Der Matchplan eines Computertrainers gegen genau diesen Gegner.
##
## Bis hierher war der Gegnerplan ein Werkzeug, das nur der Mensch hatte. Das
## ist der eigentliche Grund, warum es eine goldene Regel geben konnte: wer
## immer dasselbe spielt, bekam nie die Quittung. Ein Trainerteam, das eine
## Woche Zeit hat, sieht sich sechs Partien des Gegners an — und wenn darin
## viermal derselbe Angriff steht, stellt es sich darauf ein.
##
## Es gelingt nicht immer. Ob ueberhaupt ein Plan entsteht, haengt am Trainer
## (ein Abwehrfanatiker bereitet gruendlicher vor als ein Hasardeur) und am
## Verein (wer Analysten bezahlen kann, sieht mehr). Und ein Plan kostet:
## Manndeckung oeffnet die Abwehr, Kreis zustellen laesst den Rueckraum frei.
## Genau deshalb ist es eine Entscheidung und kein Automatismus.
static func matchplan_stellen(d: Dictionary, cid: String, gegner: String, spiel: String = "") -> void:
	if not (d.get("vereine", {}) as Dictionary).has(cid):
		return
	var v: Dictionary = d["vereine"][cid]
	if bool(v.get("ist_mensch", false)) or bool(v.get("ist_nationalteam", false)):
		return
	# Einmal je Partie. Wer bei jedem Aufruf neu wuerfelt, zeigt im Vorbericht
	# etwas anderes, als er dann spielt.
	if spiel != "":
		var vorhanden := Gegnerplan.plan(d, cid)
		if str(vorhanden.get("spiel", "")) == spiel:
			return
	# Wie gruendlich bereitet dieser Trainer vor? Die Abwehrachse sagt es, der
	# Ruf des Vereins entscheidet mit, wie viel Zuarbeit er bekommt.
	var sorgfalt: float = Gegnertrainer.achse(d, cid, "bollwerk") * 0.7 \
		+ clampf(float(v.get("ruf", 50.0)) / 100.0, 0.0, 1.0) * 0.3
	if Namen.zufall() > sorgfalt * 0.8:
		Gegnerplan.setzen(d, cid, gegner, "keins", "", spiel)
		return
	var stil := handschrift(d, gegner)
	# Ein Gegner, der immer ueber den Kreis kommt, bekommt den Innenblock
	# zugestellt. Das ist die Antwort, die es im Spiel schon gab — sie wurde
	# nur nie von einem Computertrainer gegeben.
	if stil == "kreisfokus":
		Gegnerplan.setzen(d, cid, gegner, "kreis_zustellen", "", spiel)
		return
	# Sonst gilt der Mann, der die Tore wirft. Ein Hasardeur geht in
	# Manndeckung, ein vorsichtiger Trainer doppelt nur.
	var ziel := _gefaehrlichster(d, gegner)
	if ziel == "":
		Gegnerplan.setzen(d, cid, gegner, "keins", "", spiel)
		return
	var mutig: bool = Gegnertrainer.achse(d, cid, "wagemut") > 0.55
	Gegnerplan.setzen(d, cid, gegner, "manndeckung" if mutig else "doppeln", ziel, spiel)

## Wer beim Gegner die Tore wirft. Gezaehlt wird die laufende Saison; wer
## wenig gespielt hat, faellt heraus.
static func _gefaehrlichster(d: Dictionary, gegner: String) -> String:
	var best := ""
	var bw := 0.0
	for sid in ((d["vereine"][gegner].get("kader", [])) as Array):
		var sp: Dictionary = d["spieler"].get(str(sid), {})
		if sp.is_empty() or bool(sp.get("ist_torwart", false)):
			continue
		var saison: Dictionary = (sp.get("stats", {}) as Dictionary).get("saison", {})
		var spiele: int = int(saison.get("spiele", 0))
		if spiele < 3:
			continue
		var quote: float = float(saison.get("tore", 0)) / float(spiele)
		if quote > bw:
			bw = quote
			best = str(sid)
	# Unter vier Toren je Partie ist niemand ein Fall fuer Manndeckung.
	return best if bw >= 4.0 else ""

## Legt die Handschrift eines Vereins fest: welche Deckung er spielt und
## worauf sein Angriff ausgerichtet ist.
##
## Das passiert einmal in der Saisonvorbereitung und sonst nie. Ein Verein,
## der seine Deckung staendig wechselt, bekommt sie nie eingeschliffen — das
## gilt fuer die Computertrainer genauso wie fuer den Spieler.
static func formation_festlegen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if bool(v.get("ist_mensch", false)):
		return
	var t: Dictionary = v["taktik"]
	var beweglich := 0.0
	var n := 0
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp["ist_torwart"]):
			continue
		beweglich += float(sp["attr"]["beweglichkeit"]) + float(sp["attr"]["antizipation"])
		n += 1
	var schnitt: float = beweglich / maxf(float(n) * 2.0, 1.0)
	var wunsch: String = str(t.get("abwehr", "6-0"))
	if schnitt > 13.5 and Namen.zufall() < 0.5:
		wunsch = str(Namen.waehle(["5-1", "3-2-1"]))
	elif schnitt < 10.0:
		wunsch = "6-0"
	elif Namen.zufall() < 0.25:
		wunsch = str(Namen.waehle(["6-0", "5-1"]))
	# Eine eingespielte Deckung gibt man nicht leichtfertig auf. Nur wenn der
	# Kader wirklich nicht mehr dazu passt — oder das System ohnehin noch nicht
	# sitzt — wird umgestellt.
	var sitzt: float = Vertrautheit.wert(d, cid, "abwehr", str(t.get("abwehr", "6-0")))
	if wunsch != str(t.get("abwehr", "6-0")) and sitzt >= 80.0 and Namen.zufall() < 0.72:
		wunsch = str(t.get("abwehr", "6-0"))
	t["abwehr"] = wunsch
	t["angriff"] = _bester_angriffsstil(d, cid)
	v["stammabwehr"] = wunsch
	v["stammangriff"] = str(t["angriff"])

## Stellt vor einer Partie die festgelegte Formation wieder her. Legt sie beim
## ersten Mal an, damit auch aeltere Spielstaende sofort eine haben.
static func formation_sichern(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if str(v.get("stammabwehr", "")) == "":
		formation_festlegen(d, cid)
		return
	v["taktik"]["abwehr"] = str(v["stammabwehr"])
	v["taktik"]["angriff"] = str(v["stammangriff"])

## Taktik nach Gegnerstaerke und eigener Lage.
static func taktik_anpassen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var t: Dictionary = v["taktik"]
	var naechstes: Dictionary = Welt.naechstes_spiel(cid)
	var gegnerruf: float = float(v["ruf"])
	if not naechstes.is_empty():
		var gid: String = str(naechstes["gast"]) if str(naechstes["heim"]) == cid else str(naechstes["heim"])
		gegnerruf = float(d["vereine"][gid]["ruf"])
	var unterschied: float = float(v["ruf"]) - gegnerruf
	# Die Handschrift des Trainers verschiebt, was die Lage nahelegt.
	#
	# Ohne sie stellte jeder Verein bei gleichem Rufunterschied dasselbe ein,
	# und siebzehn Gegner spielten wie einer. Ein Tempomacher laeuft auch als
	# Aussenseiter an, ein Abwehrfanatiker mauert auch als Favorit.
	var hs_tempo: float = Gegnertrainer.achse(d, cid, "tempo")
	var hs_bollwerk: float = Gegnertrainer.achse(d, cid, "bollwerk")
	var hs_wagemut: float = Gegnertrainer.achse(d, cid, "wagemut")
	var hs_strenge: float = Gegnertrainer.achse(d, cid, "strenge")
	var hs_rotation: float = Gegnertrainer.achse(d, cid, "rotation")
	var tempo_versatz: int = int(round((hs_tempo - 0.5) * 34.0))
	if unterschied > 14.0:
		t["mentalitaet"] = "offensiv" if hs_bollwerk < 0.72 else "ausgeglichen"
		t["tempo"] = clampi(Namen.wuerfel(55, 78) + tempo_versatz, 20, 92)
	elif unterschied < -14.0:
		t["mentalitaet"] = "defensiv" if hs_wagemut < 0.7 else "ausgeglichen"
		t["tempo"] = clampi(Namen.wuerfel(28, 48) + tempo_versatz, 20, 92)
	else:
		t["mentalitaet"] = "ausgeglichen"
		t["tempo"] = clampi(Namen.wuerfel(42, 62) + tempo_versatz, 20, 92)
	# Die Formation wird hier ausdruecklich nicht angefasst.
	#
	# Vor der Vertrautheit war es folgerichtig, die Deckung vor jedem Spiel neu
	# zu wuerfeln — sie kostete ja nichts. Jetzt kostet sie: eine Mannschaft,
	# die woechentlich zwischen 6-0 und 3-2-1 springt, steht dauerhaft wie
	# frisch umgestellt da. Genau das soll der Spieler spueren, und genau
	# deshalb duerfen die Computertrainer es nicht tun. Die Formation ist die
	# Handschrift eines Vereins; sie faellt in der Saisonvorbereitung
	# (formation_festlegen) und gilt dann.
	formation_sichern(d, cid)
	# Haerte, Risiko und Rotation wandern zur Handschrift des Trainers hin,
	# statt um den bisherigen Wert zu zittern.
	t["haerte"] = clampi(int(round(float(t["haerte"]) * 0.7 + hs_strenge * 90.0 * 0.3))
		+ Namen.wuerfel(-5, 5), 20, 88)
	t["risiko"] = clampi(int(round(float(t["risiko"]) * 0.7 + hs_wagemut * 90.0 * 0.3))
		+ Namen.wuerfel(-6, 6), 15, 88)
	t["wechselspiel"] = clampi(int(round(float(t.get("wechselspiel", 55)) * 0.7 + hs_rotation * 90.0 * 0.3))
		+ Namen.wuerfel(-5, 5), 20, 92)
	# Der siebte Feldspieler ist in der Bundesliga kein Notnagel mehr, sondern
	# Alltag: gut fuenfmal je Partie geht ein Torwart vom Feld. Am haeufigsten
	# in Unterzahl, wo er aus dem 5-gegen-6 wieder ein 6-gegen-6 macht.
	var wahl: float = Namen.zufall()
	if wahl < 0.52:
		t["siebter_feldspieler"] = "unterzahl"
	elif wahl < 0.78:
		t["siebter_feldspieler"] = "schluss"
	elif wahl < 0.86:
		t["siebter_feldspieler"] = "rueckstand"
	else:
		t["siebter_feldspieler"] = "nie"
	# Auch die Computertrainer geben ihren Spielern Rollen — sonst waere die
	# Anweisungstafel ein Vorteil, den nur der Mensch hat.
	Anweisungen.automatisch(d, cid)

static func _bester_angriffsstil(d: Dictionary, cid: String) -> String:
	var v: Dictionary = d["vereine"][cid]
	var werte := {"kreisfokus": 0.0, "aussenfokus": 0.0, "rueckraumfokus": 0.0, "tempospiel": 0.0, "positionsangriff": 6.0}
	for sid in v["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		var g: float = Spielerfabrik.gesamt(sp)
		match str(sp["position"]):
			"KM":
				werte["kreisfokus"] += g * 0.6
			"LA", "RA":
				werte["aussenfokus"] += g * 0.35
			"RL", "RR":
				werte["rueckraumfokus"] += g * 0.4
			"RM":
				werte["rueckraumfokus"] += g * 0.2
		werte["tempospiel"] += float(sp["attr"]["tempo"]) * 0.6 + float(sp["attr"]["ausdauer"]) * 0.4
	werte["tempospiel"] *= 0.12
	var best := "positionsangriff"
	var bw := -1.0
	for k in werte.keys():
		if float(werte[k]) > bw:
			bw = float(werte[k])
			best = k
	return best

# --------------------------------------------------------------- Wochenlauf ---

static func wochenlogik(d: Dictionary) -> void:
	# Auf jeder fremden Bank sitzt jemand. Das steht hier und nicht in der
	# Welterzeugung, damit auch alte Spielstaende ihre Trainer bekommen.
	Gegnertrainer.sicherstellen(d)
	Gegnertrainer.entlassungen_pruefen(d)
	for cid in Weltgenerator.clubs(d):
		# Guenstig und sichert die Zusage, dass jede Nummer im Kader
		# eindeutig ist — unabhaengig davon, wie ein Spieler hereinkam.
		Trikot.kader_nummerieren(d, cid)
		# Die Fanszene lebt in jedem Verein, auch in denen der KI: sie
		# bestimmt Zuschauer, Merchandising und Hallenpuls.
		Fanszene.wochenwechsel(d, cid)
		if bool(d["vereine"][cid].get("ist_mensch", false)):
			Fanszene.meldungen_pruefen(d, cid)
			# Das Notnetz gehoert in den Wochenlauf, nicht nur an Spieltage
			# und den Saisonwechsel. Der Integritaetslauf hat gezeigt, warum:
			# eine gezogene Abloeseklausel raeumt mitten in der Saison ab, und
			# bis zum naechsten Pruefzeitpunkt kann viel passieren.
			_notkader_sichern(d, cid)
			continue
		verein_fuehren(d, cid)

## Eine Woche Vereinsführung, wie ein ordentlicher Manager sie erledigt.
##
## Steht als eigene Funktion da und nicht mehr im Schleifenrumpf, weil sie
## auch für den Verein des Menschen zu gebrauchen ist — die Langzeitsonde
## misst damit, was ein durchschnittlich kompetenter Manager über zehn
## Spielzeiten erreicht, und ein Urlaubsmodus hätte hier seinen Platz.
static func verein_fuehren(d: Dictionary, cid: String) -> void:
	if Namen.zufall() < 0.06:
		Ticketing.ki_preise(d, cid)
	if Namen.zufall() < 0.12:
		Darlehen.ki_pruefen(d, cid)
	_trainingsplan(d, cid)
	_videostudium(d, cid)
	_vertraege_pflegen(d, cid)
	kader_auffuellen(d, cid)
	if Namen.zufall() < 0.05:
		Mentoring.automatisch(d, cid)
	if Namen.zufall() < 0.08:
		_personal_pflegen(d, cid)
	if Namen.zufall() < 0.1:
		_infrastruktur(d, cid)

## Wie viel der Gegner vor dem Bildschirm sitzt.
##
## Entscheidend fuer das Videostudium ist, dass die KI es auch betreibt —
## sonst waere es ein Knopf, der immer nuetzt, und der Spieler gewaenne jede
## enge Partie durch Sitzfleisch. Wie viel ein Verein studiert, haengt an
## seinem Trainerteam und daran, wie gross der Gegner ist: gegen den
## Tabellenfuehrer schaut man laenger hin als gegen den Aufsteiger.
static func _videostudium(d: Dictionary, cid: String) -> void:
	var naechstes := Welt.naechstes_spiel(cid)
	if naechstes.is_empty():
		Videostudium.einheiten_setzen(d, cid, 0)
		return
	var gegner: String = str(naechstes["gast"]) if str(naechstes["heim"]) == cid else str(naechstes["heim"])
	if not d["vereine"].has(gegner):
		Videostudium.einheiten_setzen(d, cid, 0)
		return
	var guete: float = Training.trainerqualitaet(d, cid, "taktik") / 100.0
	var abstand: float = float(d["vereine"][gegner]["ruf"]) - float(d["vereine"][cid]["ruf"])
	var neigung: float = 0.35 + guete * 0.7 + clampf(abstand / 40.0, -0.25, 0.45)
	var anzahl := 0
	if neigung > 0.55:
		anzahl = 1
	if neigung > 0.85:
		anzahl = 2
	if neigung > 1.15:
		anzahl = 3
	Videostudium.einheiten_setzen(d, cid, anzahl)

static func _trainingsplan(d: Dictionary, cid: String) -> void:
	var p: Dictionary = Training.plan(d, cid)
	var lazarett := Medizin.lazarett(d, cid)
	if lazarett.size() >= 4:
		p["intensitaet"] = clampi(int(p["intensitaet"]) - 8, 25, 90)
		p["schwerpunkt"] = "regeneration"
	else:
		p["intensitaet"] = clampi(int(p["intensitaet"]) + Namen.wuerfel(-5, 6), 35, 85)
		if Namen.zufall() < 0.3:
			p["schwerpunkt"] = Namen.waehle(["ausgeglichen", "athletik", "wurf", "abwehr", "spielaufbau", "taktik"])
	# Regenerationsbudget auf die am staerksten belasteten Spieler verteilen
	var budget: int = Training.regenerationsbudget(d, cid)
	var kader: Array = (d["vereine"][cid]["kader"] as Array).duplicate()
	kader.sort_custom(func(a, b): return float(d["spieler"][a]["last"]) > float(d["spieler"][b]["last"]))
	var zuteilung := {}
	for i in range(mini(budget, kader.size())):
		if float(d["spieler"][kader[i]]["last"]) > 45.0:
			zuteilung[kader[i]] = 1
	p["regeneration_zuteilung"] = zuteilung
	_talente_foerdern(d, cid)

## Sonderprogramme fuer die eigenen Talente — auch bei der KI.
##
## Das Sonderprogramm ist der staerkste Hebel, den ein Trainer auf die
## Entwicklung hat (vierzig Prozent mehr Zuwachs). Ihn allein dem Menschen zu
## geben hiesse: wer sich kuemmert, entwickelt dreimal so schnell wie die
## ganze Liga, und nach fuenf Spielzeiten stellt ein Verein die Auswahl. Das
## waere kein Managerspiel mehr, sondern eine Abkuerzung.
##
## Also kuemmern sich die anderen auch — aber unterschiedlich gut. Wie
## zuverlaessig ein Verein seine Talente foerdert, haengt an seiner
## Jugendarbeit und an der Guete des Stabs. Ein Spitzenverein erwischt fast
## jeden, ein Aufsteiger jeden zweiten. Damit bleibt dem Menschen ein
## Vorsprung, wenn er es besser macht — aber kein geschenkter.
const FOERDERUNG_JE_POSITION := {
	"TW": "torwart", "LA": "athletik", "RA": "athletik", "KM": "athletik",
	"RL": "wurf", "RM": "spielaufbau", "RR": "wurf",
}

static func _talente_foerdern(d: Dictionary, cid: String) -> void:
	# Nicht jede Woche neu entscheiden: ein Programm, das alle sieben Tage
	# wechselt, ist keines.
	if Namen.zufall() > 0.12:
		return
	var v: Dictionary = d["vereine"][cid]
	var jugendarbeit: float = clampf(float((v.get("infrastruktur", {}) as Dictionary).get("jugendarbeit", 3.0)) / 9.0, 0.0, 1.0)
	var guete: float = Training.trainerqualitaet(d, cid) / 100.0
	# Und danach, ob dieser Trainer ueberhaupt etwas von Jugend haelt.
	var neigung: float = Gegnertrainer.achse(d, cid, "jugend")
	var treffsicherheit: float = clampf(0.20 + 0.25 * jugendarbeit + 0.30 * guete + 0.35 * neigung,
		0.15, 0.95)
	for sid in (v.get("kader", []) as Array):
		var sp: Dictionary = (d["spieler"] as Dictionary).get(str(sid), {})
		if sp.is_empty() or int(sp["alter"]) > 23:
			continue
		if Namen.zufall() > treffsicherheit:
			sp["trainingsfokus"] = ""
			continue
		sp["trainingsfokus"] = str(FOERDERUNG_JE_POSITION.get(str(sp["position"]), "athletik"))

## Ab welchem Abstand zur eigenen Stammsieben ein Spieler nicht mehr
## verlaengert wird.
##
## Fuenfzehn Punkte sind der Abstand vom Leistungstraeger zum
## Ergaenzungsspieler. Wer weiter zurueckliegt, spielt nicht mehr mit — und in
## einem echten Profikader steht er dann auch nicht.
const MITLAEUFER_ABSTAND := 15.0

## Verlaengert auslaufende Vertraege. Ein Verein laesst nur gehen, wen er wirklich
## nicht braucht — sonst wuerde die Liga binnen weniger Saisons ausbluten.
##
## Gemessen mit werkzeuge/Kadersonde.gd fuellten sich die Kader trotzdem mit
## Mitlaeufern: 2,3 je Verein in der erzeugten Welt, nach vier Spielzeiten
## 5,4 — ein Anteil von 12,5 auf 27,0 Prozent, bei wachsender Kadergroesse
## (18,2 auf 19,9) und stabiler Stammsieben (80,1 auf 79,5).
##
## Der Grund stand hier: gemessen wurde gegen den Kaderschnitt, und der sinkt
## mit jedem Mitlaeufer. Je mehr Ballast ein Verein mitschleppte, desto
## niedriger die Latte fuer den naechsten. Jetzt zaehlt die Stammsieben —
## also das Niveau, auf dem der Verein wirklich spielt. Das ist auch die
## Frage, die ein Sportlicher Leiter stellt: reicht er fuer unsere
## Mannschaft? Und nicht: ist er besser als unser dritter Torwart?
static func _vertraege_pflegen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var saison: int = Welt.saison_index()
	var stamm := _stammniveau(d, cid)
	for sid in (v["kader"] as Array).duplicate():
		var sp: Dictionary = d["spieler"][sid]
		var rest: int = int(sp["vertrag"].get("bis_saison", 9)) - saison
		if rest > 0:
			continue
		var staerke: float = Spielerfabrik.gesamt(sp)
		var wunsch: float = Finanzen.gehaltswunsch(d, cid, sp)
		var auslastung := Finanzen.gehaltsauslastung(d, cid)
		# Der Plan entscheidet mit, wie sehr ein Verein an seinen Leuten
		# haengt: im Sparjahr laesst er gehen, in der Titeljagd haelt er.
		var halten: float = Vereinsplan.haltefaktor(d, cid)
		var schwelle: float = 6.0 * halten
		# Ein junger Spieler, dessen Decke ueber dem Niveau der Mannschaft
		# liegt, wird an seiner Zukunft gemessen und nicht an seinem heutigen
		# Stand. Alle anderen an dem, was sie heute koennen.
		var zukunft: bool = int(sp["alter"]) <= 23 and float(sp.get("potenzial", 0.0)) > stamm - 4.0
		if not zukunft and staerke < stamm - MITLAEUFER_ABSTAND * halten:
			continue
		# Zu teuer und zu schwach: der Verein laesst ihn ziehen.
		if auslastung > 112.0 and staerke < stamm - schwelle:
			continue
		# Im Umbruch trennt man sich auch von Aelteren, die noch gut sind.
		var altersgrenze: int = 35 if halten >= 1.0 else 32
		if int(sp["alter"]) >= altersgrenze and staerke < stamm - 4.0 * halten:
			continue
		if (v["kader"] as Array).size() > 22 and staerke < stamm - 10.0 * halten:
			continue
		sp["vertrag"]["gehalt"] = wunsch * Namen.bereich(1.0, 1.12)
		sp["vertrag"]["bis_saison"] = saison + Namen.wuerfel(2, 4)

## Das Niveau, auf dem ein Verein wirklich spielt: seine besten sieben.
static func _stammniveau(d: Dictionary, cid: String) -> float:
	var werte: Array = []
	for sid in (d["vereine"][cid].get("kader", []) as Array):
		werte.append(Spielerfabrik.gesamt(d["spieler"][str(sid)]))
	werte.sort()
	werte.reverse()
	var summe := 0.0
	var k: int = mini(7, werte.size())
	for i in k:
		summe += float(werte[i])
	return summe / maxf(float(k), 1.0)

static func _kaderschnitt(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	var n := 0
	for sid in d["vereine"][cid]["kader"]:
		summe += Spielerfabrik.gesamt(d["spieler"][sid])
		n += 1
	return summe / maxf(float(n), 1.0)

## Fuellt Luecken im Kader mit vereinslosen Spielern.
## Ohne das wuerde der Markt sich mit Spielern fuellen, die niemand mehr holt.
## Ab hier greift der Vorstand auch im eigenen Verein ein.
##
## Unterhalb dieser Kadergroesse laesst sich keine Saison mehr bestreiten:
## sieben auf der Platte, ein paar auf der Bank, und jede Verletzung wird zur
## Krise. Ein echter Vorstand sieht dabei nicht zu.
const NOTKADER := 13

static func kader_auffuellen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	# Eine Nationalmannschaft nominiert, sie verpflichtet nicht: sonst wuerden
	# ihr vereinslose Spieler zugeschlagen, die danach keinem Verein mehr
	# gehoeren und aus dem Transfermarkt verschwinden.
	if bool(v.get("ist_nationalteam", false)):
		return
	if bool(v.get("ist_mensch", false)):
		# Der eigene Kader ist Sache des Trainers — bis er nicht mehr reicht.
		_notkader_sichern(d, cid)
		return
	for _versuch in range(8):
		var kader: Array = v["kader"]
		var luecke := _fehlende_position(d, cid)
		if luecke == "" and kader.size() >= 18:
			return
		var pos: String = luecke if luecke != "" else schwaechste_position(d, cid)
		# Eine Position ganz ohne Spieler ist immer eine Notlage — sonst stuende
		# ein Verein ohne Torwart da, weil gerade kein bezahlbarer frei ist.
		var notlage: bool = kader.size() < 15 or (luecke != "" and _anzahl_auf(d, cid, luecke) == 0)
		var kandidat := _bester_freier(d, cid, pos, notlage)
		if kandidat == "":
			if not notlage:
				if luecke == "":
					return
				continue
			# Notlage: der Verein verpflichtet, wen er kriegen kann.
			kandidat = _notverpflichtung(d, cid, pos)
			if kandidat == "":
				return
		var sp: Dictionary = d["spieler"][kandidat]
		var gehalt: float = Finanzen.gehaltswunsch(d, cid, sp)
		Transfermarkt.transfer_durchfuehren(d, kandidat, cid, 0.0, gehalt, Namen.wuerfel(1, 3), "rotation")

## Der Vorstand greift ein, wenn der eigene Kader nicht mehr spielfaehig ist.
##
## Bis hierher galt: der eigene Verein gehoert dem Trainer, die Automatik
## haelt sich heraus. Das ist richtig — solange ein Kader dasteht. Wer drei
## Saisons keine Vertraege verlaengert, steht am Ende mit acht Spielern da,
## und dieser Zustand ist nicht schwer, sondern kaputt: man kann nicht mehr
## aufstellen, und kein Knopf im Spiel fuehrt zurueck.
##
## Der Vorstand verpflichtet deshalb ablosefreie Spieler bis zur Notgrenze —
## nicht die besten, sondern die, die zu haben sind — und sagt es einem.
static func _notkader_sichern(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	var fehlt_torwart: bool = _anzahl_auf(d, cid, "TW") == 0
	if (v["kader"] as Array).size() >= NOTKADER and not fehlt_torwart:
		return
	var geholt: Array = []
	for _versuch in range(6):
		var kader: Array = v["kader"]
		var ohne_tw: bool = _anzahl_auf(d, cid, "TW") == 0
		if kader.size() >= NOTKADER and not ohne_tw:
			break
		var pos: String = "TW" if ohne_tw else _fehlende_position(d, cid)
		if pos == "":
			pos = schwaechste_position(d, cid)
		var kandidat := _bester_freier(d, cid, pos, true)
		if kandidat == "":
			kandidat = _notverpflichtung(d, cid, pos)
		if kandidat == "":
			break
		var sp: Dictionary = d["spieler"][kandidat]
		Transfermarkt.transfer_durchfuehren(d, kandidat, cid, 0.0,
			Finanzen.gehaltswunsch(d, cid, sp), 1, "ergaenzung")
		geholt.append(Spielerfabrik.voller_name(sp))
	if geholt.is_empty():
		return
	Welt.nachricht({
		"typ": "verein", "wichtig": true,
		"betreff": "Der Vorstand hat nachverpflichtet",
		"text": "Der Kader war nicht mehr spielfähig. Der Vorstand hat ohne Rücksprache %s verpflichtet — ablösefrei, Einjahresverträge.\n\nDas ist kein Ersatz für Kaderplanung: Verträge laufen aus, und wer sie nicht verlängert, bekommt am Ende, was übrig ist." % ", ".join(geholt),
	})

## Wie viele Spieler der Verein auf einer Position hat.
static func _anzahl_auf(d: Dictionary, cid: String, pos: String) -> int:
	var n := 0
	for sid in d["vereine"][cid]["kader"]:
		if str(d["spieler"][sid]["position"]) == pos:
			n += 1
	return n

## Position, auf der dem Verein ein einsatzfaehiger Spieler fehlt.
static func _fehlende_position(d: Dictionary, cid: String) -> String:
	var zaehler := {}
	for p in Spielerfabrik.POSITIONEN:
		zaehler[p] = 0
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		zaehler[str(sp["position"])] = int(zaehler[str(sp["position"])]) + 1
	for p in Spielerfabrik.POSITIONEN:
		var soll: int = 3 if p == "TW" else 2
		if int(zaehler[p]) < soll:
			return p
	return ""

static func schwaechste_position(d: Dictionary, cid: String) -> String:
	return Transfermarkt.schwaechste_position(d, cid)

## Bester vereinsloser Spieler auf einer Position, den der Verein bezahlen kann.
## Bei Notlage (zu kleiner Kader) wird die Gehaltsgrenze deutlich gelockert.
## Wen ein Verein sucht, haengt an seinem Plan: ein Verein im Umbruch schaut
## auf Zwanzigjaehrige, einer im Abstiegskampf auf Dreissigjaehrige, die
## sofort spielen koennen.
## Die vereinslosen Spieler je Position, einmal je Tag zusammengestellt.
##
## Hier lag die zweitgroesste Bremse des Montags. _bester_freier ging fuer
## jeden Verein und jeden Versuch die gesamte Spielerliste der Welt durch:
## einhundertsechsundfuenfzig Vereine mal bis zu acht Versuchen mal
## dreitausendsechshundert Spieler sind ueber vier Millionen Durchlaeufe in
## einem einzigen Wochenlauf. Gemessen mit werkzeuge/Tagesprofil.gd: 768
## Millisekunden, direkt hinter der Sicherung.
##
## Die Liste aendert sich innerhalb eines Tages nur dadurch, dass jemand
## verpflichtet wird — Vertraege laufen erst zum Saisonwechsel aus. Also wird
## sie einmal gebaut und bei jeder Verpflichtung um einen Namen gekuerzt.
static var _freie: Dictionary = {}
static var _freie_tag: int = -1

## Den ganzen Index verwerfen. Noetig nur, wenn jemand vereinslos *wird* —
## und das passiert zum Saisonwechsel, nicht mitten in der Woche.
static func freie_leeren() -> void:
	_freie.clear()
	_freie_tag = -1

## Einen Namen aus dem Index nehmen, weil er jetzt einen Verein hat.
##
## Nicht den ganzen Index: kader_auffuellen verpflichtet bis zu acht Spieler
## je Verein, und bei einhundertsechsundfuenfzig Vereinen waere ein
## Neuaufbau je Verpflichtung teurer als gar kein Index.
static func frei_streichen(sid: String) -> void:
	for pos in _freie.keys():
		(_freie[pos] as Array).erase(sid)

static func _freie_auf_position(d: Dictionary, pos: String) -> Array:
	var heute: int = int(d.get("tag", 0))
	if heute != _freie_tag:
		_freie.clear()
		_freie_tag = heute
	if _freie.has(pos):
		return _freie[pos]
	var liste: Array = []
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["verein"]) != "" or str(sp["position"]) != pos:
			continue
		# Ein gesichtetes Nachwuchstalent ist kein vereinsloser Profi: es
		# gehoert in eine Akademie und nicht in einen Profikader.
		if bool(sp.get("jugendspieler", false)):
			continue
		liste.append(sid)
	_freie[pos] = liste
	return liste

static func _bester_freier(d: Dictionary, cid: String, pos: String, notlage: bool = false) -> String:
	var v: Dictionary = d["vereine"][cid]
	var spielraum: float = float(v["gehaltsbudget"]) * 1.1 - Finanzen.spielergehaelter(d, cid) - Finanzen.personalgehaelter(d, cid)
	var grenze: float = float(v["gehaltsbudget"]) * (0.16 if notlage else 0.06)
	grenze = maxf(grenze, spielraum) * Vereinsplan.etatfaktor(d, cid)
	# Dieselbe Latte wie beim Verlaengern.
	#
	# Hier war das Leck. Ein Verein liess einen Spieler ziehen, weil er mehr
	# als fuenfzehn Punkte unter der eigenen Stammsieben lag — und holte sich
	# danach den, den ein anderer Verein aus demselben Grund gehen liess. Der
	# Markt der Vereinslosen besteht fast nur aus Mitlaeufern, und ohne
	# Untergrenze wanderten sie im Kreis. Wer nicht gut genug zum Bleiben war,
	# ist auch nicht gut genug zum Holen.
	var latte: float = -1.0
	if not notlage:
		latte = _stammniveau(d, cid) - MITLAEUFER_ABSTAND
	# Ruf und Lohnniveau einmal holen: die Schleife laeuft ueber alle Spieler
	# der Welt und wird oefter durchlaufen, als es auf den ersten Blick aussieht.
	var ruf: float = float(v["ruf"])
	var niveau: float = Finanzen.lohnniveau(d, cid)
	# Die Planwerte einmal holen und nicht je Spieler: die Schleife laeuft
	# ueber jeden Spieler der Welt.
	var plan_ziel: float = Vereinsplan.eigenschaft(d, cid, "alter_ziel")
	var plan_jugend: float = clampf(Vereinsplan.eigenschaft(d, cid, "jugend"), 0.4, 1.8)
	var best := ""
	var bw := -1.0
	for sid in _freie_auf_position(d, pos):
		var sp: Dictionary = d["spieler"].get(str(sid), {})
		if sp.is_empty() or str(sp["verein"]) != "":
			continue
		# Der Plan des Vereins gewichtet mit: derselbe Spieler ist fuer einen
		# Verein im Umbruch mehr wert als fuer einen im Abstiegskampf.
		var abstand: float = absf(float(sp["alter"]) - plan_ziel)
		var gewicht: float = clampf(1.25 - abstand * 0.07, 0.35, 1.25)
		if int(sp["alter"]) <= 22:
			gewicht *= plan_jugend
		var staerke: float = Spielerfabrik.gesamt(sp)
		# Ein junger Spieler wird an seiner Decke gemessen und nicht an
		# seinem heutigen Stand — genau wie beim Verlaengern. Sonst kaeme
		# kein Verein mehr an ein Talent, das noch nichts vorzuweisen hat.
		var messlatte: float = staerke
		if int(sp["alter"]) <= 22:
			messlatte = maxf(staerke, float(sp.get("potenzial", 0.0)) - 4.0)
		if latte > 0.0 and messlatte < latte:
			continue
		var w: float = staerke * gewicht
		if w <= bw:
			continue
		if Spielerfabrik.gehaltsvorstellung(sp, ruf, niveau) > grenze:
			continue
		bw = w
		best = sid
	return best

## Letzter Ausweg: ein Verein, dem sonst die Spieler ausgehen, holt einen
## Spieler aus dem Umfeld. Damit kann keine Mannschaft unbesetzt antreten.
static func _notverpflichtung(d: Dictionary, cid: String, pos: String) -> String:
	var v: Dictionary = d["vereine"][cid]
	var ziel: float = clampf(float(v["ruf"]) * 0.5 + Namen.bereich(-6.0, 6.0), 14.0, 55.0)
	var sid := Weltgenerator.neue_spieler_id(d)
	var sp := Spielerfabrik.erzeuge(sid, Namen.kultur_zufall(str(v["nation"]), 0.85),
		Namen.wuerfel(18, 30), ziel, pos, int(d["startjahr"]))
	sp["kenntnis"] = 45.0
	d["spieler"][sid] = sp
	Transfermarkt.transfer_durchfuehren(d, sid, cid, 0.0,
		Finanzen.gehaltswunsch(d, cid, sp), Namen.wuerfel(1, 2), "ergaenzung")
	return sid

static func _personal_pflegen(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	for pid in (v["personal"] as Array).duplicate():
		var mp: Dictionary = d["personal"].get(pid, {})
		if mp.is_empty():
			continue
		if int(mp["alter"]) > 66:
			(v["personal"] as Array).erase(pid)
			var neu := Weltgenerator.erzeuge_mitarbeiter(d, str(mp["rolle"]), float(v["ruf"]), str(v["nation"]))
			d["personal"][neu]["verein"] = cid
			(v["personal"] as Array).append(neu)

static func _infrastruktur(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	if not (v["halle"]["bauprojekt"] as Dictionary).is_empty():
		return
	var bereiche := ["trainingszentrum", "jugendarbeit", "medizin", "analyse", "regeneration", "halle"]
	var bereich: String = str(Namen.waehle(bereiche))
	var kosten: float = Finanzen.ausbaukosten(d, cid, bereich)
	if float(v["kasse"]) > kosten * 2.5:
		Finanzen.ausbau_starten(d, cid, bereich)

## Alle KI-Vereine verlaengern auslaufende Vertraege — muss VOR dem
## Vertragsablauf zum Saisonwechsel laufen.
static func vertragsrunde(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		if bool(d["vereine"][cid].get("ist_mensch", false)):
			continue
		_vertraege_pflegen(d, cid)

## Setzt fuer alle KI-Vereine eine sinnvolle Startaufstellung nach der Saisonpause.
static func saisonvorbereitung(d: Dictionary) -> void:
	for cid in Weltgenerator.clubs(d):
		kader_auffuellen(d, cid)
	for cid in Weltgenerator.clubs(d):
		Weltgenerator.setze_standardaufstellung(d, cid)
		if not bool(d["vereine"][cid].get("ist_mensch", false)):
			# Der eine Punkt im Jahr, an dem eine Deckung wirklich neu gewaehlt
			# wird — mit dem ganzen Sommer Zeit, sie einzuschleifen.
			formation_festlegen(d, cid)
			taktik_anpassen(d, cid)
			_nachwuchsminuten(d, cid)

## Wie viele Minuten die KI ihren Talenten fest zusagt.
##
## Gemessen ueber acht Spielzeiten, alle achtzehn Vereine von der KI gefuehrt:
##
##   Saison      0     2     4     6     8
##   u23 Ø    64,5  57,4  55,6  55,0  51,1
##   Talente    17    15     9    12     3     (u23 mit Gesamtwert ueber 70)
##
## Der Nachwuchs der Liga verdorrte, waehrend der Kaderschnitt bei 78 stehen
## blieb und das Durchschnittsalter von 26,6 auf 27,9 stieg. Die Ursache lag
## nicht am Sonderprogramm — das bekamen die Talente laengst — sondern an der
## Spielzeit: die Aufstellung nimmt immer die beste Sieben, gewechselt wird
## nur bei Kraftmangel, und dabei kommt wieder der Beste von der Bank. Ein
## Neunzehnjaehriger hinter einem Stammspieler kam damit nie aufs Feld, und
## in Training.zuwachs steht die Spielzeit mit dem Faktor 0,30 bis 1,35 — wer
## nicht spielt, entwickelt sich viereinhalbmal langsamer.
##
## Also planen die Computervereine ihre Minuten so, wie ein Mensch es kann:
## ueber Zielminuten. Wie viele und fuer wie viele haengt daran, wie viel
## dieser Verein von Jugend haelt — Jugendarbeit, Guete des Stabs, die
## Handschrift des Trainers und der Vereinsplan. Ein Umbruchverein zieht drei
## Talente hoch, ein Titeljaeger hoechstens eins.
const NACHWUCHS_MINUTEN_WENIG := 7.0
const NACHWUCHS_MINUTEN_VIEL := 22.0

static func _nachwuchsminuten(d: Dictionary, cid: String) -> void:
	var v: Dictionary = d["vereine"][cid]
	# Die Ziele der Vorsaison gelten nicht weiter: der Kader ist ein anderer.
	Einsatzzeit.loeschen(d, cid)
	var jugendarbeit: float = clampf(float((v.get("infrastruktur", {}) as Dictionary).get("jugendarbeit", 3.0)) / 9.0, 0.0, 1.0)
	var guete: float = Training.trainerqualitaet(d, cid) / 100.0
	var neigung: float = Gegnertrainer.achse(d, cid, "jugend")
	var planschub: float = clampf(Vereinsplan.eigenschaft(d, cid, "jugend") / 1.8, 0.0, 1.0)
	var mut: float = clampf(0.18 * jugendarbeit + 0.22 * guete + 0.32 * neigung + 0.28 * planschub,
		0.0, 1.0)
	# Wer schon zur besten Sieben gehoert, braucht keine Zusage.
	var stamm := {}
	var angriff: Dictionary = (v.get("aufstellung", {}) as Dictionary).get("angriff", {})
	for pos in angriff.keys():
		stamm[str(angriff[pos])] = true
	var jung: Array = []
	for sid in (v.get("kader", []) as Array):
		var sp: Dictionary = (d["spieler"] as Dictionary).get(str(sid), {})
		if sp.is_empty() or bool(sp["ist_torwart"]) or int(sp["alter"]) > 22:
			continue
		if stamm.has(str(sid)):
			continue
		jung.append({"sid": str(sid), "wert": float(sp.get("potenzial", 0.0))})
	if jung.is_empty():
		return
	jung.sort_custom(func(a, b): return float(a["wert"]) > float(b["wert"]))
	var wie_viele: int = mini(1 + int(round(2.0 * mut)), jung.size())
	var minuten: float = roundf(lerpf(NACHWUCHS_MINUTEN_WENIG, NACHWUCHS_MINUTEN_VIEL, mut) / 2.0) * 2.0
	for i in wie_viele:
		Einsatzzeit.setzen(d, cid, str((jung[i] as Dictionary)["sid"]), minuten)
