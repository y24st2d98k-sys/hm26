class_name Beziehungen
extends RefCounted
## Die Kabine als soziales Netz.
##
## Bisher war eine Mannschaft ein Mittelwert: Moral, Teamgeist und
## Unzufriedenheit wurden über den Kader gemittelt, und daraus fiel eine Zahl.
## Die Gruppen in der Kabine leiteten sich aus Nationalität und Alter ab —
## also aus Etiketten, nicht aus Menschen. Zwei Spieler konnten sich nicht
## verstehen oder nicht ausstehen; es gab schlicht kein Zwischen-ihnen.
##
## Hier gibt es das. Jedes Paar hat einen Wert von −100 bis +100, und dieser
## Wert entsteht aus Dingen, die man selbst zu verantworten hat:
##
##  * **Positionsrivalität** — zwei Ehrgeizige auf derselben Position, von
##    denen nur einer spielt. Das ist der schärfste Konflikt im Handball und
##    entsteht direkt aus der Kaderplanung: wer zwei starke Rückraum-Linke
##    kauft, kauft sich eine Auseinandersetzung mit dazu.
##  * **Charakter** — zwei Hitzköpfe reiben sich, ein Leitwolf und ein Stiller
##    Schaffer ergänzen sich, ein Söldner findet in einem Vereinsherz keinen
##    Freund.
##  * **Herkunft und Alter** — dieselbe Sprache und derselbe Jahrgang machen
##    vieles leichter. Das ist nicht alles, aber es ist etwas.
##  * **Gemeinsame Zeit auf dem Feld** — wer zusammen spielt, wächst zusammen.
##  * **Patenschaften** — eine Mentorenbeziehung ist die stärkste positive
##    Bindung, die es gibt.
##
## Gepflegt wird das Netz nur für den eigenen Verein. Was in fremden Kabinen
## zwischen zwei Ersatztorhütern vorgeht, schaut niemand an, und 25.000 Zahlen
## dafür durch jeden Spielstand zu schleppen wäre reine Verschwendung. Der
## Graph entsteht beim ersten Zugriff aus stabilen Eigenschaften — wechselt
## man den Verein, baut er sich für den neuen ebenso auf.

## Ab hier gelten zwei Spieler als befreundet.
## Ab hier gelten zwei Spieler als befreundet — absolut, für die Beschriftung.
const FREUND := 50.0
## Wie weit eine Clique über dem Kaderschnitt liegen muss, und wo die
## Untergrenze sitzt. Siehe cliquen_schwelle().
const CLIQUE_UEBER_SCHNITT := 17.0
const CLIQUE_MINDESTWERT := 22.0
## Ab hier ist es ein offener Konflikt, der die Kabine belastet.
const KONFLIKT := -46.0
## Eine Clique braucht so viele Mitglieder, sonst sind es zwei Kumpel.
const CLIQUE_MINDEST := 3

# ------------------------------------------------------------- Speicher ---

## Der kanonische Schlüssel eines Paares. Sortiert, damit A|B und B|A
## dieselbe Zeile treffen — sonst stünden zwei Wahrheiten übereinander.
static func schluessel(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]

static func netz(d: Dictionary, cid: String) -> Dictionary:
	var v: Dictionary = d["vereine"][cid]
	if not v.has("beziehungen") or typeof(v["beziehungen"]) != TYPE_DICTIONARY:
		v["beziehungen"] = {}
	return v["beziehungen"]

## Der Wert zwischen zwei Spielern. Steht noch nichts im Netz, wird der
## Grundwert aus ihren Eigenschaften berechnet und eingetragen.
static func wert(d: Dictionary, cid: String, a: String, b: String) -> float:
	if a == b:
		return 0.0
	var n := netz(d, cid)
	var k := schluessel(a, b)
	if not n.has(k):
		n[k] = grundwert(d, a, b)
	return clampf(float(n[k]), -100.0, 100.0)

static func setzen(d: Dictionary, cid: String, a: String, b: String, neu: float) -> void:
	if a == b:
		return
	netz(d, cid)[schluessel(a, b)] = clampf(neu, -100.0, 100.0)

static func verschieben(d: Dictionary, cid: String, a: String, b: String, delta: float) -> void:
	setzen(d, cid, a, b, wert(d, cid, a, b) + delta)

## Räumt Paare heraus, von denen einer den Verein verlassen hat. Ohne das
## wüchse das Netz über die Jahre mit Karteileichen zu.
static func aufraeumen(d: Dictionary, cid: String) -> void:
	var kader: Dictionary = {}
	for sid in d["vereine"][cid]["kader"]:
		kader[str(sid)] = true
	for sid2 in d["vereine"][cid].get("jugend", []):
		kader[str(sid2)] = true
	var n := netz(d, cid)
	for k in n.keys():
		var teile: PackedStringArray = str(k).split("|")
		if teile.size() != 2 or not kader.has(teile[0]) or not kader.has(teile[1]):
			n.erase(k)

# ------------------------------------------------------------ Grundwert ---

## Wie zwei Spieler zueinander stehen, bevor irgendetwas passiert ist.
static func grundwert(d: Dictionary, a: String, b: String) -> float:
	var sa: Dictionary = d["spieler"].get(a, {})
	var sb: Dictionary = d["spieler"].get(b, {})
	if sa.is_empty() or sb.is_empty():
		return 0.0
	var w := 0.0
	w += _charakterpassung(sa, sb)
	w += _herkunft(sa, sb)
	w += _alter(sa, sb)
	w += _rivalitaet(sa, sb)
	# Eine Prise Zufall, abgeleitet aus den beiden IDs: dieselben zwei Spieler
	# bekommen immer denselben Wert, aber nicht jedes Paar mit gleichem Profil
	# denselben. Menschen sind nicht ihre Merkmale.
	# Menschen sind nicht ihre Merkmale. Der Streubereich ist bewusst so
	# breit wie die uebrigen Terme zusammen: sonst haetten zwei gleichaltrige
	# Landsleute immer denselben Wert, und die Kabine waere eine Tabelle.
	w += float(abs(hash(schluessel(a, b))) % 53) - 26.0
	return clampf(w, -85.0, 85.0)

## Zwei Hitzköpfe reiben sich, zwei Profis verstehen sich ohne Worte.
static func _charakterpassung(sa: Dictionary, sb: Dictionary) -> float:
	var ca: Dictionary = sa.get("charakter", {})
	var cb: Dictionary = sb.get("charakter", {})
	var w := 0.0
	var temp_a: float = float(ca.get("temperament", 10.0))
	var temp_b: float = float(cb.get("temperament", 10.0))
	# Zwei aufbrausende Typen sind eine Frage der Zeit.
	w -= maxf(temp_a - 12.0, 0.0) * maxf(temp_b - 12.0, 0.0) * 0.55
	# Professionalität verträgt sich mit Professionalität.
	w += (float(ca.get("profitum", 12.0)) - 11.0) * (float(cb.get("profitum", 12.0)) - 11.0) * 0.28
	# Ähnliche Loyalität heißt ähnliche Einstellung zum Verein.
	w += (5.0 - absf(float(ca.get("loyalitaet", 12.0)) - float(cb.get("loyalitaet", 12.0)))) * 0.9
	return w

static func _herkunft(sa: Dictionary, sb: Dictionary) -> float:
	return 12.0 if str(sa.get("nation", "")) == str(sb.get("nation", "")) else 0.0

static func _alter(sa: Dictionary, sb: Dictionary) -> float:
	var abstand: float = absf(float(sa.get("alter", 25)) - float(sb.get("alter", 25)))
	if abstand <= 2.0:
		return 8.0
	if abstand >= 11.0:
		return -6.0
	return 4.0 - abstand

## Der schärfste Konflikt im Kader: dieselbe Position, ähnliche Stärke, beide
## wollen spielen.
##
## Das ist die eigentliche Pointe des ganzen Systems. Wer zwei ehrgeizige
## Rückraum-Linke mit 84 und 83 verpflichtet, hat nicht Tiefe gekauft, sondern
## eine Auseinandersetzung — und muss sie führen.
static func _rivalitaet(sa: Dictionary, sb: Dictionary) -> float:
	if str(sa.get("position", "")) != str(sb.get("position", "")):
		return 0.0
	var abstand: float = absf(Spielerfabrik.gesamt(sa) - Spielerfabrik.gesamt(sb))
	if abstand > 14.0:
		# Wer dem anderen klar überlegen ist, hat mit ihm kein Problem.
		return 0.0
	var naehe: float = 1.0 - abstand / 14.0
	var ehrgeiz: float = (float(sa.get("charakter", {}).get("ehrgeiz", 12.0))
		+ float(sb.get("charakter", {}).get("ehrgeiz", 12.0))) / 2.0
	return -naehe * (6.0 + maxf(ehrgeiz - 9.0, 0.0) * 3.4)

# ---------------------------------------------------------- Fortschreiben ---

## Wochenlauf für den eigenen Verein.
static func wochenwechsel(d: Dictionary, cid: String) -> void:
	if cid == "" or not d["vereine"].has(cid):
		return
	aufraeumen(d, cid)
	var kader: Array = d["vereine"][cid]["kader"]
	for i in range(kader.size()):
		for j in range(i + 1, kader.size()):
			_paar_woche(d, cid, str(kader[i]), str(kader[j]))

static func _paar_woche(d: Dictionary, cid: String, a: String, b: String) -> void:
	var sa: Dictionary = d["spieler"][a]
	var sb: Dictionary = d["spieler"][b]
	var alt := wert(d, cid, a, b)
	var schub := 0.0
	# Gemeinsame Spielzeit verbindet. Wer Woche für Woche zusammen auf der
	# Platte stand, kennt die Wege des anderen.
	var min_a: float = float(sa["stats"]["saison"]["minuten"])
	var min_b: float = float(sb["stats"]["saison"]["minuten"])
	if min_a > 120.0 and min_b > 120.0:
		schub += 1.4
	# Positionsrivalität verschärft sich, wenn nur einer spielt.
	if str(sa["position"]) == str(sb["position"]):
		var spiele_a: int = int(sa["stats"]["saison"]["spiele"])
		var spiele_b: int = int(sb["stats"]["saison"]["spiele"])
		if spiele_a + spiele_b >= 6 and absi(spiele_a - spiele_b) >= 4:
			var benachteiligt: Dictionary = sa if spiele_a < spiele_b else sb
			var ehrgeiz: float = float(benachteiligt["charakter"].get("ehrgeiz", 12.0)) / 20.0
			schub -= 1.2 + ehrgeiz * 2.4
	# Patenschaften sind die stärkste Bindung im Kader.
	if Mentoring.sind_paar(d, a, b):
		schub += 2.6
	# Unzufriedenheit steckt an: wer hadert, zieht die Nächsten mit hinunter.
	var gift: float = (maxf(float(sa["unzufriedenheit"]) - 60.0, 0.0)
		+ maxf(float(sb["unzufriedenheit"]) - 60.0, 0.0)) / 40.0
	schub -= gift * 0.8
	# Ohne Ereignis zieht jeder Wert langsam zur Mitte. Weder Freundschaften
	# noch Feindschaften halten von allein ewig.
	var rueckkehr: float = -signf(alt) * minf(absf(alt), 100.0) * 0.010
	setzen(d, cid, a, b, alt + gesaettigt(alt, schub) + rueckkehr)

## Dämpft alles, was eine Beziehung weiter von der Mitte wegtreibt.
##
## Ohne das läuft das Netz davon: die erste Messung über eine ganze Saison
## ergab einen Median von 91 und 84 Prozent Freundschaften — eine Mannschaft,
## in der sich alle gleich gut verstehen, ist wieder ein Mittelwert, nur mit
## mehr Rechenaufwand. Die ersten Wochen einer Freundschaft tragen mehr als
## die fünfzigste; ein Zerwürfnis vertieft sich am Anfang schneller als am
## Ende. Nur die Bewegung nach außen wird gedämpft, die zur Mitte hin nicht —
## eine Versöhnung soll nicht schwerer sein, weil man vorher zerstritten war.
static func gesaettigt(alt: float, schub: float) -> float:
	if is_zero_approx(schub):
		return 0.0
	if signf(schub) != signf(alt) and not is_zero_approx(alt):
		return schub
	return schub * maxf(1.0 - absf(alt) / 105.0, 0.0)

## Nach einer Partie: ein Sieg schweißt zusammen, eine Klatsche nicht.
static func nach_spiel(d: Dictionary, cid: String, gewonnen: bool, abstand: int) -> void:
	if cid == "" or cid != Welt.mein_verein_id or not d["vereine"].has(cid):
		return
	var kader: Array = d["vereine"][cid]["kader"]
	var schub: float = 0.0
	if gewonnen:
		schub = 0.35 + clampf(float(abstand) * 0.05, 0.0, 0.45)
	elif abstand <= -8:
		schub = -0.6
	if is_zero_approx(schub):
		return
	for i in range(kader.size()):
		for j in range(i + 1, kader.size()):
			var a: String = str(kader[i])
			var b: String = str(kader[j])
			verschieben(d, cid, a, b, gesaettigt(wert(d, cid, a, b), schub))

# ------------------------------------------------------------- Auswerten ---

## Alle Beziehungen eines Spielers, absteigend nach Wert.
static func fuer_spieler(d: Dictionary, cid: String, sid: String) -> Array:
	var liste: Array = []
	for anderer in d["vereine"][cid]["kader"]:
		if str(anderer) == sid:
			continue
		liste.append({"spieler": str(anderer), "wert": wert(d, cid, sid, str(anderer))})
	liste.sort_custom(func(a, b): return float(a["wert"]) > float(b["wert"]))
	return liste

## Die Cliquen: zusammenhängende Gruppen über positive Kanten.
##
## Das ersetzt die alte Einteilung nach Nation und Alter. Die war bequem, aber
## sie behauptete etwas, das nicht stimmte: dass drei Dänen im Kader eine
## Gruppe bilden, nur weil sie Dänen sind. Eine Clique entsteht aus
## tatsächlichen Bindungen — auch wenn die oft genug entlang der Sprache
## verlaufen.
static func cliquen(d: Dictionary, cid: String) -> Array:
	var kader: Array = d["vereine"][cid]["kader"]
	var frei: Array = []
	for sid in kader:
		frei.append(str(sid))
	var gruppen: Array = []
	var schwelle := cliquen_schwelle(d, cid)
	# Solange sich noch ein dichter Kern finden lässt, einen bilden.
	while frei.size() >= CLIQUE_MINDEST:
		var gruppe := _dichter_kern(d, cid, frei, schwelle)
		if gruppe.size() < CLIQUE_MINDEST:
			break
		gruppen.append({
			"mitglieder": gruppe,
			"anfuehrer": _anfuehrer(d, gruppe),
			"staerke": _gruppenstaerke(d, cid, gruppe),
		})
		for sid2 in gruppe:
			frei.erase(sid2)
	gruppen.sort_custom(func(a, b): return (a["mitglieder"] as Array).size() > (b["mitglieder"] as Array).size())
	return gruppen

## Sucht die dichteste Gruppe unter den noch freien Spielern.
##
## Nicht über Zusammenhangskomponenten: die kippen. Wenn A mit B befreundet
## ist, B mit C und C mit D, hängen alle vier zusammen, obwohl A und D
## einander kaum kennen — und in einem Kader, in dem die halbe Mannschaft
## dieselbe Sprache spricht, ist am Ende jeder mit jedem verbunden. Der erste
## Versuch lieferte genau das: eine Clique aus siebzehn von neunzehn Spielern,
## also die Mannschaft, umständlich beschrieben.
##
## Stattdessen wird von dem engsten Paar aus gewachsen, und aufgenommen wird
## nur, wer zur *ganzen* Gruppe passt, nicht bloß zu einem darin.
## Ab welchem Wert zwei Spieler in dieselbe Clique gehören.
##
## Bewusst relativ zum Kaderschnitt und nicht absolut. Eine feste Schwelle
## misst das Falsche: in einer frisch zusammengestellten Mannschaft, in der
## alle bei zehn stehen, gibt es keine Kreise, obwohl es sehr wohl engere und
## losere Verhältnisse gibt; in einer, die drei Jahre zusammenspielt und im
## Schnitt bei fünfzig steht, wäre plötzlich der ganze Kader eine Clique. Eine
## Clique ist, wer *deutlich enger* miteinander ist als der Rest — und das
## hängt davon ab, wie der Rest steht.
static func cliquen_schwelle(d: Dictionary, cid: String) -> float:
	var kader: Array = d["vereine"][cid]["kader"]
	if kader.size() < 2:
		return CLIQUE_MINDESTWERT
	var summe := 0.0
	var n := 0
	for i in range(kader.size()):
		for j in range(i + 1, kader.size()):
			summe += wert(d, cid, str(kader[i]), str(kader[j]))
			n += 1
	return maxf(summe / maxf(float(n), 1.0) + CLIQUE_UEBER_SCHNITT, CLIQUE_MINDESTWERT)

static func _dichter_kern(d: Dictionary, cid: String, frei: Array, schwelle: float) -> Array:
	var beste_a := ""
	var beste_b := ""
	var bester := schwelle
	for i in range(frei.size()):
		for j in range(i + 1, frei.size()):
			var w := wert(d, cid, str(frei[i]), str(frei[j]))
			if w > bester:
				bester = w
				beste_a = str(frei[i])
				beste_b = str(frei[j])
	if beste_a == "":
		return []
	var gruppe: Array = [beste_a, beste_b]
	while true:
		var kandidat := ""
		var bestwert := schwelle
		for sid in frei:
			var s: String = str(sid)
			if gruppe.has(s):
				continue
			var summe := 0.0
			for mitglied in gruppe:
				summe += wert(d, cid, s, str(mitglied))
			var schnitt: float = summe / float(gruppe.size())
			if schnitt > bestwert:
				bestwert = schnitt
				kandidat = s
		if kandidat == "":
			break
		gruppe.append(kandidat)
	return gruppe

static func _anfuehrer(d: Dictionary, gruppe: Array) -> String:
	var best := ""
	var bw := -1.0
	for sid in gruppe:
		var e: float = Kabine.einfluss(d, str(sid))
		if e > bw:
			bw = e
			best = str(sid)
	return best

static func _gruppenstaerke(d: Dictionary, cid: String, gruppe: Array) -> float:
	var summe := 0.0
	var n := 0
	for i in range(gruppe.size()):
		for j in range(i + 1, gruppe.size()):
			summe += wert(d, cid, str(gruppe[i]), str(gruppe[j]))
			n += 1
	return summe / maxf(float(n), 1.0)

## Offene Konflikte, schlimmster zuerst.
static func konflikte(d: Dictionary, cid: String) -> Array:
	var kader: Array = d["vereine"][cid]["kader"]
	var liste: Array = []
	for i in range(kader.size()):
		for j in range(i + 1, kader.size()):
			var w := wert(d, cid, str(kader[i]), str(kader[j]))
			if w <= KONFLIKT:
				liste.append({"a": str(kader[i]), "b": str(kader[j]), "wert": w,
					"grund": _grund(d, str(kader[i]), str(kader[j]))})
	liste.sort_custom(func(x, y): return float(x["wert"]) < float(y["wert"]))
	return liste

## Woran es zwischen den beiden liegt — für die Oberfläche.
static func _grund(d: Dictionary, a: String, b: String) -> String:
	var sa: Dictionary = d["spieler"][a]
	var sb: Dictionary = d["spieler"][b]
	if str(sa["position"]) == str(sb["position"]) and _rivalitaet(sa, sb) < -8.0:
		return "Beide wollen auf %s spielen." % Spielerfabrik.POSITION_NAME.get(str(sa["position"]), str(sa["position"]))
	var temp: float = minf(float(sa["charakter"].get("temperament", 10.0)),
		float(sb["charakter"].get("temperament", 10.0)))
	if temp >= 14.0:
		return "Zwei Temperamente, die aneinandergeraten."
	if float(sa["unzufriedenheit"]) > 60.0 or float(sb["unzufriedenheit"]) > 60.0:
		return "Die Unzufriedenheit des einen färbt ab."
	if absf(float(sa["alter"]) - float(sb["alter"])) >= 11.0:
		return "Zwei Generationen, die wenig verbindet."
	return "Sie kommen einfach nicht miteinander aus."

## Ein Zahlenwert 0..100, wie geschlossen die Mannschaft ist.
##
## Er geht in das Kabinenklima ein und damit in den Teamfaktor der Simulation.
## Eine zerfallene Kabine kostet, eine geschlossene trägt.
static func geschlossenheit(d: Dictionary, cid: String) -> float:
	var kader: Array = d["vereine"][cid]["kader"]
	if kader.size() < 2:
		return 50.0
	var summe := 0.0
	var n := 0
	var offene := 0
	for i in range(kader.size()):
		for j in range(i + 1, kader.size()):
			var w := wert(d, cid, str(kader[i]), str(kader[j]))
			summe += w
			n += 1
			if w <= KONFLIKT:
				offene += 1
	var schnitt: float = summe / maxf(float(n), 1.0)
	# Ein offener Konflikt wiegt schwerer als der Mittelwert es zeigt: eine
	# Mannschaft mit einem Zerwürfnis und sonst guter Stimmung ist keine
	# durchschnittliche Mannschaft, sie ist eine mit einem Problem.
	return clampf(50.0 + schnitt * 0.55 - float(offene) * 4.5, 0.0, 100.0)

static func stufe_text(w: float) -> String:
	if w >= 60.0:
		return "eng befreundet"
	elif w >= FREUND:
		return "verstehen sich gut"
	elif w >= 12.0:
		return "kommen klar"
	elif w > -12.0:
		return "neutral"
	elif w > KONFLIKT:
		return "gehen sich aus dem Weg"
	return "offener Konflikt"

# ------------------------------------------------------------- Aussprache ---

## Eine Aussprache zwischen zwei Zerstrittenen.
##
## Sie ist kein Knopf, der ein Problem löscht: der Ausgang hängt daran, wie
## sehr die beiden auf den Trainer hören, und ein missglückter Versuch macht
## es schlimmer. Genau das soll er — sonst wäre jeder Konflikt eine
## Formalität und das ganze Netz Dekoration.
static func aussprache(d: Dictionary, cid: String, a: String, b: String) -> Dictionary:
	var sa: Dictionary = d["spieler"][a]
	var sb: Dictionary = d["spieler"][b]
	var vertrauen: float = (float(sa.get("beziehung", 50.0)) + float(sb.get("beziehung", 50.0))) / 2.0
	var temperament: float = (float(sa["charakter"].get("temperament", 10.0))
		+ float(sb["charakter"].get("temperament", 10.0))) / 2.0
	var chance: float = clampf(0.28 + vertrauen / 190.0 + (12.0 - temperament) * 0.022, 0.10, 0.86)
	if Trainerkarriere.bonus_fuer(d, cid, "kumpeltyp"):
		chance += 0.10
	if Trainerkarriere.bonus_fuer(d, cid, "eiserne_hand"):
		chance += 0.05
	var gelungen: bool = Namen.zufall() < chance
	if gelungen:
		verschieben(d, cid, a, b, Namen.bereich(26.0, 46.0))
		for sp in [sa, sb]:
			sp["moral"] = clampf(float(sp["moral"]) + 3.0, 5.0, 100.0)
		return {"ok": true, "grund": "%s und %s haben sich ausgesprochen. Es ist nicht aus der Welt, aber es ist besprochen." % [
			Spielerfabrik.kurz_name(sa), Spielerfabrik.kurz_name(sb)]}
	verschieben(d, cid, a, b, -Namen.bereich(4.0, 12.0))
	for sp2 in [sa, sb]:
		sp2["beziehung"] = clampf(float(sp2.get("beziehung", 50.0)) - 3.0, 0.0, 100.0)
	return {"ok": false, "grund": "Die Aussprache ist entgleist. %s und %s stehen jetzt schlechter zueinander als vorher." % [
		Spielerfabrik.kurz_name(sa), Spielerfabrik.kurz_name(sb)]}

## Trennt zwei Zerstrittene im Training und in der Aufstellung — ein
## Eingeständnis, aber manchmal das Einzige, was hilft.
static func getrennt_halten(d: Dictionary, cid: String, a: String, b: String) -> Dictionary:
	verschieben(d, cid, a, b, 6.0)
	for sid in [a, b]:
		var sp: Dictionary = d["spieler"][sid]
		sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) + 3.0, 0.0, 100.0)
	return {"ok": true, "grund": "Die beiden trainieren vorerst getrennt. Das entschärft die Lage — und keiner der beiden findet es gut."}
