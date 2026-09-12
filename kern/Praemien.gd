class_name Praemien
extends RefCounted
## Erfolgsprämien in Spielerverträgen.
##
## Eine Tor- und eine Siegprämie senken die Gehaltsforderung eines Spielers,
## kosten den Verein aber nach jedem erfolgreichen Pflichtspiel bares Geld.
## Wer viel variabel bezahlt, hat in schwachen Wochen Luft — und zahlt in
## starken Wochen drauf. Prämien werden nur für Pflichtspiele ausgeschüttet.

const TOR_MAX := 2500.0
const SIEG_MAX := 6000.0
## Pflichtspiele je Woche über eine ganze Saison gemittelt.
const SPIELE_JE_WOCHE := 1.25

## Erwartete Tore je Pflichtspiel — Grundlage für die Bewertung einer Torprämie.
static func tor_erwartung(sp: Dictionary) -> float:
	if bool(sp.get("ist_torwart", false)):
		return 0.05
	var basis: float = {
		"RM": 4.4, "RL": 3.4, "RR": 3.4, "LA": 3.6, "RA": 3.6, "KM": 3.0,
	}.get(str(sp.get("position", "RM")), 3.4)
	var staerke: float = Spielerfabrik.gesamt(sp)
	return maxf(basis * clampf(0.45 + staerke / 110.0, 0.4, 1.35), 0.2)

## Was eine Prämienzusage den Verein im Schnitt je Woche kostet.
static func erwartete_wochenkosten(sp: Dictionary, praemie_tor: float, praemie_sieg: float,
		siegquote: float = 0.5) -> float:
	return (praemie_tor * tor_erwartung(sp) + praemie_sieg * siegquote) * SPIELE_JE_WOCHE

## Wie hoch der Spieler die Prämien gegenüber festem Gehalt bewertet.
## Ehrgeizige Profis trauen sich die Prämien zu, Zweifler wollen Sicherheit.
static func anrechnungsfaktor(sp: Dictionary) -> float:
	var ch: Dictionary = sp.get("charakter", {})
	var ehrgeiz: float = float(ch.get("ehrgeiz", 12.0)) / 20.0
	var profitum: float = float(ch.get("profitum", 12.0)) / 20.0
	return clampf(0.34 + ehrgeiz * 0.62 + profitum * 0.22, 0.3, 1.06)

## Erwartete Siegquote des Vereins, bei dem der Vertrag laufen soll.
static func siegquote(d: Dictionary, cid: String) -> float:
	if cid != "" and d.get("vereine", {}).has(cid):
		return clampf(float(d["vereine"][cid]["ruf"]) / 130.0, 0.25, 0.78)
	return 0.5

## Der Betrag, den die Prämien beim geforderten Wochengehalt ersetzen.
## `verein` ist der Klub, bei dem der Vertrag gelten soll — leer heißt: der aktuelle.
static func gehaltsersatz(d: Dictionary, sp: Dictionary, praemie_tor: float, praemie_sieg: float,
		verein: String = "") -> float:
	var cid: String = verein if verein != "" else str(sp.get("verein", ""))
	return erwartete_wochenkosten(sp, praemie_tor, praemie_sieg, siegquote(d, cid)) * anrechnungsfaktor(sp)

## Prämien auf gültige Spannen begrenzen.
static func begrenzen(praemie_tor: float, praemie_sieg: float) -> Dictionary:
	return {
		"praemie_tor": clampf(praemie_tor, 0.0, TOR_MAX),
		"praemie_sieg": clampf(praemie_sieg, 0.0, SIEG_MAX),
	}

## Nach dem Spiel: fällige Prämien beider Mannschaften auszahlen.
static func abrechnen(d: Dictionary, m: Dictionary) -> void:
	var art: String = str(m["art"])
	if art == "test" or art == "turnier":
		return
	var bericht: Dictionary = m.get("bericht", {})
	if bericht.is_empty():
		return
	var th: int = int(m["tore_heim"])
	var tg: int = int(m["tore_gast"])
	_seite(d, str(m["heim"]), bericht.get("heim", {}), th > tg)
	_seite(d, str(m["gast"]), bericht.get("gast", {}), tg > th)

static func _seite(d: Dictionary, cid: String, tb: Dictionary, gewonnen: bool) -> void:
	if cid == "" or not d["vereine"].has(cid) or tb.is_empty():
		return
	var summe := 0.0
	for sid in tb.get("spieler", {}).keys():
		if not d["spieler"].has(sid):
			continue
		var sp: Dictionary = d["spieler"][sid]
		var vertrag: Dictionary = sp.get("vertrag", {})
		var pt: float = float(vertrag.get("praemie_tor", 0.0))
		var ps: float = float(vertrag.get("praemie_sieg", 0.0))
		if pt <= 0.0 and ps <= 0.0:
			continue
		var z: Dictionary = tb["spieler"][sid]
		if float(z.get("sekunden", 0.0)) < 60.0:
			continue
		var betrag: float = pt * float(int(z.get("tore", 0)))
		if gewonnen:
			betrag += ps
		if betrag <= 0.0:
			continue
		summe += betrag
		# Ausgezahlte Prämien heben die Stimmung leicht.
		sp["moral"] = clampf(float(sp["moral"]) + minf(betrag / 4000.0, 1.6), 5.0, 100.0)
		var konto: Dictionary = sp["stats"]["saison"]
		konto["praemien"] = float(konto.get("praemien", 0.0)) + betrag
	if summe > 0.0:
		Finanzen.buchen(d, cid, -summe, "Erfolgsprämien", "praemie")

## Was der Verein in dieser Saison bereits an Prämien ausgeschüttet hat.
static func saisonsumme(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	for sid in d["vereine"][cid]["kader"]:
		summe += float((d["spieler"][sid]["stats"]["saison"] as Dictionary).get("praemien", 0.0))
	return summe

## Kurzer Klartext für die Oberfläche.
static func beschreibung(d: Dictionary, sp: Dictionary, praemie_tor: float, praemie_sieg: float,
		verein: String = "") -> String:
	if praemie_tor <= 0.0 and praemie_sieg <= 0.0:
		return "Keine Prämien vereinbart — volles Festgehalt."
	var cid: String = verein if verein != "" else str(sp.get("verein", ""))
	var ersatz: float = gehaltsersatz(d, sp, praemie_tor, praemie_sieg, cid)
	var kosten: float = erwartete_wochenkosten(sp, praemie_tor, praemie_sieg, siegquote(d, cid))
	return "Senkt die Gehaltsforderung um rund %s je Woche, kostet im Schnitt %s je Woche." % [
		Stil.geld(ersatz), Stil.geld(kosten)]
