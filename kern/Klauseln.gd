class_name Klauseln
extends RefCounted
## Vertragsklauseln jenseits von Gehalt und Laufzeit.
##
## Bisher kannte ein Vertrag eine Ablöseklausel und zwei Erfolgsprämien. In der
## Wirklichkeit steht in einem Vertrag mehr, und jede dieser Zeilen ist eine
## Wette: Wer eine Weiterverkaufsbeteiligung abgibt, verkauft heute teurer und
## verdient morgen mit. Wer eine Ausstiegsklausel bei Abstieg zugesteht, spart
## Gehalt und steht im Sommer ohne Leistungsträger da.
##
## Gespeichert wird im Vertrag des Spielers:
##   `weiterverkauf`    Anteil (0..0.35) am nächsten Weiterverkauf
##   `abstiegsklausel`  bei Abstieg darf der Spieler ablösefrei gehen
##   `einsatzpraemie`   Betrag je Pflichtspiel mit mindestens 20 Minuten
##   `treuepraemie`     Einmalzahlung am Ende jeder erfüllten Vertragssaison

const WEITERVERKAUF_MAX := 0.35
const EINSATZ_MAX := 2500.0
const EINSATZ_MINUTEN := 20.0

## Ehemalige Vereine, die am nächsten Verkauf beteiligt sind.
static func beteiligte(sp: Dictionary) -> Array:
	return sp.get("verkaufsbeteiligung", [])

static func lesen(sp: Dictionary) -> Dictionary:
	var vertrag: Dictionary = sp.get("vertrag", {})
	return {
		"weiterverkauf": float(vertrag.get("weiterverkauf", 0.0)),
		"abstiegsklausel": bool(vertrag.get("abstiegsklausel", false)),
		"einsatzpraemie": float(vertrag.get("einsatzpraemie", 0.0)),
		"treuepraemie": float(vertrag.get("treuepraemie", 0.0)),
	}

static func schreiben(sp: Dictionary, werte: Dictionary) -> void:
	var vertrag: Dictionary = sp["vertrag"]
	vertrag["weiterverkauf"] = clampf(float(werte.get("weiterverkauf", 0.0)), 0.0, WEITERVERKAUF_MAX)
	vertrag["abstiegsklausel"] = bool(werte.get("abstiegsklausel", false))
	vertrag["einsatzpraemie"] = clampf(float(werte.get("einsatzpraemie", 0.0)), 0.0, EINSATZ_MAX)
	vertrag["treuepraemie"] = maxf(float(werte.get("treuepraemie", 0.0)), 0.0)

## Was die Zugeständnisse dem Spieler wert sind, ausgedrückt als Abschlag auf
## das Wochengehalt (0..1). Der Verein bezahlt sie also mit weniger Festgehalt.
static func gehaltsersatz(d: Dictionary, sp: Dictionary, werte: Dictionary) -> float:
	var rabatt := 0.0
	# Eine Ausstiegsklausel bei Abstieg ist Sicherheit — vor allem für gute
	# Spieler bei wackligen Vereinen.
	if bool(werte.get("abstiegsklausel", false)):
		var cid: String = str(sp["verein"])
		var gefahr := 0.5
		if cid != "" and d["vereine"].has(cid):
			gefahr = clampf(1.0 - Vorstand.staerkeindex(d, cid) / 90.0, 0.1, 0.9)
		rabatt += 0.05 + gefahr * 0.09
	# Am eigenen Weiterverkauf beteiligt zu sein interessiert ihn nicht — das
	# Geld bekommt der abgebende Verein. Er lässt es sich also nicht anrechnen.
	# Einsatz- und Treueprämie dagegen schon.
	var einsatz: float = float(werte.get("einsatzpraemie", 0.0))
	if einsatz > 0.0:
		var quote: float = _einsatzquote(sp)
		rabatt += clampf(einsatz * quote * 0.62 / maxf(Finanzen.gehaltswunsch(d, str(sp["verein"]), sp), 1.0), 0.0, 0.25)
	var treue: float = float(werte.get("treuepraemie", 0.0))
	if treue > 0.0:
		var loyal: float = float((sp["charakter"] as Dictionary).get("loyalitaet", 12.0)) / 20.0
		rabatt += clampf(treue / 52.0 * (0.4 + 0.6 * loyal) / maxf(Finanzen.gehaltswunsch(d, str(sp["verein"]), sp), 1.0), 0.0, 0.2)
	return clampf(rabatt, 0.0, 0.42)

## Anteil der Spiele, in denen er auf mindestens 20 Minuten kommt.
static func _einsatzquote(sp: Dictionary) -> float:
	var st: Dictionary = sp["stats"]["karriere"]
	var spiele: int = int(st.get("spiele", 0))
	if spiele < 5:
		return 0.6
	var minuten: float = float(st.get("minuten", 0.0))
	return clampf(minuten / float(spiele) / 45.0, 0.15, 1.0)

## Beschreibung fürs Verhandlungsfenster.
static func beschreibung(werte: Dictionary) -> String:
	var teile: Array = []
	if float(werte.get("weiterverkauf", 0.0)) > 0.0:
		teile.append("%d %% Weiterverkaufsbeteiligung" % int(float(werte["weiterverkauf"]) * 100.0))
	if bool(werte.get("abstiegsklausel", false)):
		teile.append("ablösefrei bei Abstieg")
	if float(werte.get("einsatzpraemie", 0.0)) > 0.0:
		teile.append("%s je Einsatz" % Stil.geld(float(werte["einsatzpraemie"])))
	if float(werte.get("treuepraemie", 0.0)) > 0.0:
		teile.append("%s Treueprämie" % Stil.geld(float(werte["treuepraemie"])))
	return ", ".join(teile) if not teile.is_empty() else "keine Zusatzklauseln"

# --------------------------------------------------------- Auszahlungen ---

## Einsatzprämien nach einer Partie. Wird aus Praemien.abrechnen gerufen.
static func einsatzpraemien(d: Dictionary, m: Dictionary) -> void:
	var bericht: Dictionary = m.get("bericht", {})
	if bericht.is_empty():
		return
	for seite in ["heim", "gast"]:
		var tb: Dictionary = bericht.get(seite, {})
		var cid: String = str(tb.get("cid", ""))
		if cid == "" or not d["vereine"].has(cid):
			continue
		var summe := 0.0
		for sid in (tb.get("spieler", {}) as Dictionary).keys():
			if not d["spieler"].has(sid):
				continue
			var sp: Dictionary = d["spieler"][sid]
			var betrag: float = float(sp["vertrag"].get("einsatzpraemie", 0.0))
			if betrag <= 0.0:
				continue
			if float((tb["spieler"][sid] as Dictionary).get("sekunden", 0.0)) < EINSATZ_MINUTEN * 60.0:
				continue
			summe += betrag
			var st: Dictionary = sp["stats"]["saison"]
			st["praemien"] = float(st.get("praemien", 0.0)) + betrag
		if summe > 0.0:
			Finanzen.buchen(d, cid, -summe, "Einsatzprämien", "praemie")

## Treueprämien zum Saisonende an alle, deren Vertrag weiterläuft.
static func treuepraemien(d: Dictionary) -> void:
	var saison: int = Welt.saison_index()
	for cid in Weltgenerator.clubs(d):
		var summe := 0.0
		for sid in d["vereine"][cid]["kader"]:
			var sp: Dictionary = d["spieler"][sid]
			var betrag: float = float(sp["vertrag"].get("treuepraemie", 0.0))
			if betrag <= 0.0 or int(sp["vertrag"].get("bis_saison", 0)) <= saison:
				continue
			summe += betrag
			sp["moral"] = clampf(float(sp["moral"]) + 3.0, 5.0, 100.0)
		if summe <= 0.0:
			continue
		Finanzen.buchen(d, cid, -summe, "Treueprämien", "praemie")
		if cid == Welt.mein_verein_id:
			Welt.nachricht({
				"typ": "finanzen",
				"betreff": "Treueprämien ausgezahlt",
				"text": "Für das Erfüllen ihrer Verträge haben Ihre Spieler zusammen %s erhalten." % Stil.geld(summe),
			})

## Beim Verkauf: der abgebende Verein zahlt frühere Vereine aus, und legt
## selbst eine Beteiligung fest, wenn sie im Vertrag stand.
static func verkauf_abrechnen(d: Dictionary, sid: String, von: String, ablöse: float,
		beteiligung_neu: float = -1.0) -> void:
	var sp: Dictionary = d["spieler"][sid]
	if ablöse <= 0.0:
		return
	var offen: Array = beteiligte(sp)
	for i in range(offen.size() - 1, -1, -1):
		var e: Dictionary = offen[i]
		var verein: String = str(e["verein"])
		if verein == von or not d["vereine"].has(verein):
			offen.remove_at(i)
			continue
		var anteil: float = clampf(float(e["anteil"]), 0.0, WEITERVERKAUF_MAX)
		var betrag: float = ablöse * anteil
		if betrag < 100.0:
			offen.remove_at(i)
			continue
		Finanzen.buchen(d, verein, betrag, "Weiterverkaufsbeteiligung %s" % Spielerfabrik.voller_name(sp), "transfer")
		if von != "" and d["vereine"].has(von):
			Finanzen.buchen(d, von, -betrag, "Beteiligung an %s" % str(d["vereine"][verein]["name"]), "transfer")
		if verein == Welt.mein_verein_id:
			Welt.nachricht({
				"typ": "finanzen", "wichtig": true,
				"betreff": "Weiterverkaufsbeteiligung: %s" % Stil.geld(betrag),
				"text": "%s ist weiterverkauft worden — Ihr Anteil von %d %% ist eingegangen." % [
					Spielerfabrik.voller_name(sp), int(anteil * 100.0)],
			})
		offen.remove_at(i)
	# Die Beteiligung aus dem alten Vertrag gilt für den nächsten Verkauf.
	var anteil_neu: float = beteiligung_neu if beteiligung_neu >= 0.0 \
		else float(sp["vertrag"].get("weiterverkauf", 0.0))
	if anteil_neu > 0.0 and von != "" and d["vereine"].has(von):
		offen.append({"verein": von, "anteil": anteil_neu})
	sp["verkaufsbeteiligung"] = offen

## Beim Abstieg: wer eine Ausstiegsklausel hat, darf ablösefrei gehen.
static func abstieg_pruefen(d: Dictionary, cid: String) -> void:
	var betroffene: Array = []
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		if not bool(sp["vertrag"].get("abstiegsklausel", false)):
			continue
		sp["vertrag"]["ablöseklausel"] = 1.0
		sp["auf_transferliste"] = true
		betroffene.append(Spielerfabrik.kurz_name(sp))
	if betroffene.is_empty() or cid != Welt.mein_verein_id:
		return
	Welt.nachricht({
		"typ": "transfer", "wichtig": true,
		"betreff": "%d Ausstiegsklauseln greifen" % betroffene.size(),
		"text": "Durch den Abstieg dürfen %s den Verein ablösefrei verlassen." % ", ".join(betroffene),
	})
