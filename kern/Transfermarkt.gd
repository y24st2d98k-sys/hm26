class_name Transfermarkt
extends RefCounted
## Transfermarkt: Suche, Verhandlung, Leihe, Vertragsgespraeche — und der KI-Markt.
##
## Ein Angebot laeuft in zwei Stufen: erst einigt man sich mit dem abgebenden Verein
## ueber die Abloese, danach mit dem Spieler ueber Gehalt, Rolle und Laufzeit. Beide
## Seiten koennen ablehnen, nachverhandeln oder abwarten — Zeitdruck entsteht durch
## das Transferfenster, das nur im Sommer und im Januar offen steht.

const SOMMER_VON := 0
const SOMMER_BIS := 61
const WINTER_VON := 184
const WINTER_BIS := 213

const ROLLEN := ["leistungstraeger", "stammspieler", "rotation", "ergaenzung", "talent"]
const ROLLEN_NAME := {
	"leistungstraeger": "Leistungsträger", "stammspieler": "Stammspieler",
	"rotation": "Rotationsspieler", "ergaenzung": "Ergänzungsspieler", "talent": "Talent",
}

static func fenster_offen(d: Dictionary) -> bool:
	if d.is_empty():
		return false
	var tis: int = Kalender.tag_in_saison(int(d.get("tag", 0)))
	return (tis >= SOMMER_VON and tis <= SOMMER_BIS) or (tis >= WINTER_VON and tis <= WINTER_BIS)

## Die letzten Tage eines Fensters. Was jetzt nicht passiert, passiert nicht
## mehr — und das aendert das Verhalten aller Beteiligten.
const DEADLINE_TAGE := 3

static func ist_deadline(d: Dictionary) -> bool:
	if not fenster_offen(d):
		return false
	var rest := tage_bis_fensterschluss(d)
	return rest >= 0 and rest < DEADLINE_TAGE

## Wie gross der Druck ist: 0 lange vor Schluss, 1 am letzten Tag.
##
## Das ist die eine Zahl, aus der die ganze Schlussphase folgt. Vorher war ein
## Transferfenster ueberall gleich warm — man konnte am ersten Tag dasselbe
## tun wie am letzten, und der Kalender war Kulisse. Ein Fenster ohne
## Zeitdruck ist aber kein Fenster, sondern eine Liste.
static func deadline_druck(d: Dictionary) -> float:
	if not fenster_offen(d):
		return 0.0
	var rest := tage_bis_fensterschluss(d)
	if rest < 0 or rest >= DEADLINE_TAGE:
		return 0.0
	return clampf(1.0 - float(rest) / float(DEADLINE_TAGE), 0.0, 1.0)

static func tage_bis_fensterschluss(d: Dictionary) -> int:
	if d.is_empty():
		return 0
	var tis: int = Kalender.tag_in_saison(int(d.get("tag", 0)))
	if tis <= SOMMER_BIS:
		return SOMMER_BIS - tis
	if tis < WINTER_VON:
		return -(WINTER_VON - tis)
	if tis <= WINTER_BIS:
		return WINTER_BIS - tis
	return -(365 - tis)

# ------------------------------------------------------------------ Suche ---

## Durchsucht alle Spieler nach Kriterien. filter kennt:
## position, max_alter, min_alter, max_ablöse, max_gehalt, min_gesamt, nur_transferliste,
## nur_vertragsende, nur_vereinslos, nation, text
static func suchen(d: Dictionary, filter: Dictionary, eigener_verein: String = "") -> Array:
	var treffer: Array = []
	if d.is_empty():
		return treffer
	var saison: int = Welt.saison_index()
	# Einmal kleinschreiben, nicht dreitausendmal.
	var suchtext: String = str(filter.get("text", "")).strip_edges().to_lower()
	for sid in d["spieler"].keys():
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp.get("jugendspieler", false)):
			continue
		if str(sp["verein"]) == eigener_verein and eigener_verein != "":
			continue
		if filter.has("position") and str(filter["position"]) != "" and str(sp["position"]) != str(filter["position"]):
			continue
		if filter.has("max_alter") and int(sp["alter"]) > int(filter["max_alter"]):
			continue
		if filter.has("min_alter") and int(sp["alter"]) < int(filter["min_alter"]):
			continue
		if bool(filter.get("nur_vereinslos", false)) and str(sp["verein"]) != "":
			continue
		if bool(filter.get("nur_transferliste", false)) and not bool(sp.get("auf_transferliste", false)) and not bool(sp.get("transferwunsch", false)):
			continue
		if bool(filter.get("nur_vertragsende", false)):
			if str(sp["verein"]) != "" and int(sp["vertrag"].get("bis_saison", 9)) > saison:
				continue
		if filter.has("min_gesamt") and Spielerfabrik.gesamt(sp) < float(filter["min_gesamt"]):
			continue
		if filter.has("max_gehalt") and Spielerfabrik.gehaltsvorstellung(sp, 60.0) > float(filter["max_gehalt"]):
			continue
		if filter.has("nation") and str(filter["nation"]) != "" and str(sp["nation"]) != str(filter["nation"]):
			continue
		if suchtext != "" and not Spielerfabrik.voller_name(sp).to_lower().contains(suchtext):
			continue
		# Zuletzt, weil es das Teuerste ist: die Abloesevorstellung fragt nach
		# dem Preisaufschlag und der nach den Mitbewerbern. Vor den billigen
		# Filtern gerechnet, kostete das den Transferbildschirm zehn Sekunden.
		if filter.has("max_ablöse") and str(sp["verein"]) != "" and ablösevorstellung(d, sid) > float(filter["max_ablöse"]):
			continue
		treffer.append(sid)
	treffer = Spielerfabrik.nach_staerke(d, treffer)
	return treffer.slice(0, int(filter.get("limit", 120)))

## Was der abgebende Verein mindestens sehen will.
static func ablösevorstellung(d: Dictionary, sid: String) -> float:
	var sp: Dictionary = d["spieler"][sid]
	if str(sp["verein"]) == "":
		return 0.0
	var wert: float = float(sp["wert"])
	var rest: int = maxi(int(sp["vertrag"].get("bis_saison", 0)) - Welt.saison_index(), 0)
	var faktor: float = 1.0 + 0.16 * float(rest)
	if bool(sp.get("auf_transferliste", false)):
		faktor *= 0.78
	if bool(sp.get("transferwunsch", false)):
		faktor *= 0.85
	var rolle: String = str(sp["vertrag"].get("rolle", "rotation"))
	if rolle == "leistungstraeger":
		faktor *= 1.35
	elif rolle == "stammspieler":
		faktor *= 1.15
	elif rolle == "ergaenzung":
		faktor *= 0.9
	if rest <= 0:
		faktor = 0.0
	# Wer begehrt ist, wird teurer. Das ist der ganze Unterschied
	# zwischen einer Preisliste und einem Markt.
	return (wert * faktor) * Konkurrenz.preisaufschlag(d, sid)

# --------------------------------------------------------------- Angebote ---

static func _neue_angebots_id(d: Dictionary) -> String:
	d["zaehler"]["auftrag"] = int(d["zaehler"]["auftrag"]) + 1
	return "a_%05d" % int(d["zaehler"]["auftrag"])

## Der Spieler gibt ein Angebot fuer einen fremden Spieler ab.
static func angebot_abgeben(d: Dictionary, sid: String, ablöse: float, gehalt: float, laufzeit: int,
		rolle: String, art: String = "kauf", praemie_tor: float = 0.0, praemie_sieg: float = 0.0) -> Dictionary:
	var cid: String = Welt.mein_verein_id
	if cid == "":
		return {"ok": false, "grund": "Sie haben derzeit keinen Verein."}
	if not fenster_offen(d) and art != "vorvertrag":
		return {"ok": false, "grund": "Das Transferfenster ist geschlossen."}
	var sp: Dictionary = d["spieler"][sid]
	var v: Dictionary = d["vereine"][cid]
	if art == "vorvertrag":
		var erlaubt := Vorvertrag.moeglich(d, sid)
		if not bool(erlaubt["ok"]):
			return erlaubt
		# Ein Vorvertrag ist immer abloesefrei: der abgebende Verein wird
		# nicht gefragt, weil er nichts zu vergeben hat.
		ablöse = 0.0
	if art == "kauf" and ablöse > float(v["transferbudget"]) + float(v["kasse"]):
		return {"ok": false, "grund": "Ablöse und Budget passen nicht zusammen."}
	if (v["kader"] as Array).size() >= 26:
		return {"ok": false, "grund": "Der Kader ist voll (max. 26 Spieler)."}
	var angebot := {
		"id": _neue_angebots_id(d),
		"art": art,
		"spieler": sid,
		"von": str(sp["verein"]),
		"nach": cid,
		"ablöse": ablöse,
		"gehalt": gehalt,
		"laufzeit": laufzeit,
		"rolle": rolle,
		"status": "offen",
		"richtung": "ausgehend",
		"frist_tag": int(d["tag"]) + Namen.wuerfel(1, 3),
		"antwort": "",
		"leihgebuehr_anteil": 0.5,
		"praemie_tor": Praemien.begrenzen(praemie_tor, praemie_sieg)["praemie_tor"],
		"praemie_sieg": Praemien.begrenzen(praemie_tor, praemie_sieg)["praemie_sieg"],
	}
	(d["transfermarkt"]["angebote"] as Array).append(angebot)
	return {"ok": true, "grund": "Angebot übermittelt. Eine Antwort wird in den nächsten Tagen erwartet."}

## Taegliche Bearbeitung aller offenen Angebote.
static func tageswechsel(d: Dictionary) -> void:
	d["transfermarkt"]["fenster_offen"] = fenster_offen(d)
	var offen: Array = d["transfermarkt"]["angebote"]
	var behalten: Array = []
	for a in offen:
		if str(a["status"]) in ["abgeschlossen", "abgelehnt", "zurueckgezogen"]:
			if int(d["tag"]) - int(a["frist_tag"]) < 21:
				behalten.append(a)
			continue
		if int(d["tag"]) < int(a["frist_tag"]):
			behalten.append(a)
			continue
		_angebot_bearbeiten(d, a)
		behalten.append(a)
	d["transfermarkt"]["angebote"] = behalten
	if Kalender.wochentag(int(d["tag"])) == 1:
		_ki_transferrunde(d)
		# Wer beobachtet und nicht handelt, verliert den Spieler an einen, der
		# handelt. Das gilt nur fuer die Spieler, die der Mensch im Blick hat —
		# alles andere erledigt die gewoehnliche Transferrunde.
		Konkurrenz.wochenrunde(d)
		# Auslaufende Vertraege werden das ganze Jahr ueber gesichert, nicht
		# nur im offenen Fenster.
		Vorvertrag.ki_runde(d)
	if ist_deadline(d):
		# An den letzten Tagen handeln auch zwischendurch noch Vereine — in
		# kleinerem Umfang als in der regulaeren Wochenrunde.
		_ki_transferrunde(d, true)
		_deadline_bilanz(d)
	_deadline_hinweis(d)

static func _deadline_hinweis(d: Dictionary) -> void:
	var rest: int = tage_bis_fensterschluss(d)
	if Welt.mein_verein_id == "":
		return
	if rest in [7, 3, 1] and fenster_offen(d):
		Welt.nachricht({
			"typ": "transfer", "wichtig": rest <= 3,
			"betreff": "Transferfenster: noch %d Tage" % rest,
			"text": "Danach sind bis zum nächsten Fenster keine Verpflichtungen mehr möglich. Offene Verhandlungen sollten jetzt entschieden werden.",
		})

## Was heute im Markt passiert ist. Nur an Deadline-Tagen und nur, wenn es
## etwas zu berichten gibt — eine Meldung ueber null Transfers waere Laerm.
static func _deadline_bilanz(d: Dictionary) -> void:
	if Welt.mein_verein_id == "":
		return
	var heute: Array = []
	for e in d["transfermarkt"].get("verlauf", []):
		if int((e as Dictionary).get("tag", -1)) == int(d["tag"]):
			heute.append(e)
	if heute.is_empty():
		return
	heute.sort_custom(func(a, b): return float((a as Dictionary).get("ablöse", 0.0)) > float((b as Dictionary).get("ablöse", 0.0)))
	var zeilen: Array = []
	for e in heute.slice(0, 6):
		var eintrag: Dictionary = e
		var sp: Dictionary = d["spieler"].get(str(eintrag.get("spieler", "")), {})
		if sp.is_empty():
			continue
		var nach: String = str((d["vereine"].get(str(eintrag.get("nach", "")), {}) as Dictionary).get("name", "einem neuen Verein"))
		var von: String = str((d["vereine"].get(str(eintrag.get("von", "")), {}) as Dictionary).get("name", "vereinslos"))
		zeilen.append("· %s: %s → %s (%s)" % [Spielerfabrik.voller_name(sp), von, nach,
			Stil.geld(float(eintrag.get("ablöse", 0.0)))])
	if zeilen.is_empty():
		return
	var rest := tage_bis_fensterschluss(d)
	Welt.nachricht({
		"typ": "transfer", "wichtig": rest <= 0,
		"betreff": "Deadline Day: %d Wechsel heute" % heute.size(),
		"text": "%s\n\n%s" % [
			("Das Fenster schließt heute." if rest <= 0 else "Noch %d Tage." % rest),
			"\n".join(zeilen)],
	})

static func _angebot_bearbeiten(d: Dictionary, a: Dictionary) -> void:
	var sid: String = str(a["spieler"])
	if not d["spieler"].has(sid):
		a["status"] = "abgelehnt"
		return
	var status: String = str(a["status"])
	if status == "offen":
		# Beim Vorvertrag gibt es nichts mit dem abgebenden Verein zu
		# besprechen: der Spieler ist im Sommer ohnehin frei, eine Abloese
		# steht nicht zur Debatte. Es entscheidet allein der Spieler.
		if str(a["von"]) == "" or str(a.get("art", "")) == "vorvertrag":
			a["status"] = "verein_einig"
			_spielerverhandlung(d, a)
			return
		_vereinsverhandlung(d, a)
	elif status == "verein_einig":
		_spielerverhandlung(d, a)

static func _vereinsverhandlung(d: Dictionary, a: Dictionary) -> void:
	var sid: String = str(a["spieler"])
	var sp: Dictionary = d["spieler"][sid]
	var von: String = str(a["von"])
	var verkaeufer: Dictionary = d["vereine"][von]
	if unverkaeuflich(d, sid):
		a["status"] = "abgelehnt"
		a["antwort"] = "%s gibt %s nicht ab — der Kader gäbe es nicht her." % [
			str(verkaeufer["name"]), Spielerfabrik.kurz_name(sp)]
		_melde(d, a, "Verein lehnt ab", a["antwort"])
		return
	var geboten: float = float(a["ablöse"])
	var schwelle: float = verkaufsschwelle(d, sid)
	if geboten >= schwelle:
		a["status"] = "verein_einig"
		a["antwort"] = "%s stimmt einer Ablöse von %s zu. Jetzt entscheidet der Spieler." % [verkaeufer["name"], Stil.geld(geboten)]
		a["frist_tag"] = int(d["tag"]) + Namen.wuerfel(1, 3)
		_melde(d, a, "Einigung mit %s" % verkaeufer["name"], a["antwort"])
	elif geboten >= schwelle * 0.8:
		a["status"] = "gegenangebot"
		a["gegenforderung"] = schwelle * Namen.bereich(1.0, 1.08)
		a["antwort"] = "%s fordert %s." % [verkaeufer["name"], Stil.geld(float(a["gegenforderung"]))]
		a["frist_tag"] = int(d["tag"]) + 2
		_melde(d, a, "Gegenangebot von %s" % verkaeufer["name"], a["antwort"])
	else:
		a["status"] = "abgelehnt"
		a["antwort"] = "%s lehnt das Angebot deutlich ab." % verkaeufer["name"]
		_melde(d, a, "Angebot abgelehnt", a["antwort"])

## Was der abgebende Verein wirklich sehen will, bevor er zustimmt.
##
## ablösevorstellung() ist der Listenpreis; das hier ist der Preis. Der
## Unterschied kann erheblich sein: ein Verein ohne Ersatz auf der Position
## legt achtundzwanzig Prozent drauf, einer mit leerer Kasse geht deutlich
## runter, und in den letzten Tagen des Fensters wird jeder weicher.
##
## Steht als eigene Funktion da, weil die Anfrage denselben Wert nennen muss,
## den die Verhandlung anschliessend anlegt. Zwei Rechnungen fuer dieselbe
## Zahl waeren eine Einladung, dass sie auseinanderlaufen — und dann sagt die
## Anfrage etwas anderes als der Verein hinterher tut.
static func verkaufsschwelle(d: Dictionary, sid: String) -> float:
	var sp: Dictionary = d["spieler"][sid]
	var von: String = str(sp["verein"])
	if von == "" or not d["vereine"].has(von):
		return 0.0
	var verkaeufer: Dictionary = d["vereine"][von]
	var not_verkauf: bool = float(verkaeufer["kasse"]) < 0.0
	var schwelle: float = ablösevorstellung(d, sid) * (0.82 if not_verkauf else 0.97)
	if not _hat_ersatz(d, von, sid):
		schwelle *= 1.28
	if bool(sp.get("transferwunsch", false)):
		schwelle *= 0.86
	schwelle *= 1.0 - 0.16 * deadline_druck(d)
	return schwelle

## Spieler, die ein Verein nicht abgeben kann, ohne handlungsunfaehig zu
## werden: der letzte Torwart und jeder, der den Kader unter die Notgrenze
## druecken wuerde.
##
## Das ist keine Feinheit, sondern eine Regel, die jeder Verein kennt: den
## einzigen Torhueter verkauft man nicht, egal was geboten wird. Der
## Integritaetslauf ueber 1.100 Tage hat den Fall gefunden — ein
## Zweitligist stand nach einem Transfer ohne Torwart da.
static func unverkaeuflich(d: Dictionary, sid: String) -> bool:
	var sp: Dictionary = d["spieler"].get(sid, {})
	var cid: String = str(sp.get("verein", ""))
	if cid == "" or not d["vereine"].has(cid):
		return false
	var kader: Array = d["vereine"][cid]["kader"]
	if kader.size() <= KI.NOTKADER:
		return true
	if not bool(sp.get("ist_torwart", false)):
		return false
	var torhueter := 0
	for anderer in kader:
		if bool(d["spieler"][anderer].get("ist_torwart", false)):
			torhueter += 1
	return torhueter <= 1

# --------------------------------------------------------------- Anfrage ---
#
# Vor dem Angebot steht das Gespraech. Bisher gab es das nicht: wer wissen
# wollte, ob ein Verein einen Spieler ueberhaupt abgibt, musste ein foermliches
# Angebot abgeben und drei Tage auf die Antwort warten — und hatte dann unter
# Umstaenden nur gelernt, dass der Mann unverkaeuflich ist. Im Kaderbildschirm
# stand zwar eine geschaetzte Ablose, aber die kannte weder die Kaderlage des
# Gegenuebers noch dessen Kassenstand und lag deshalb regelmaessig daneben.
#
# Die Anfrage kostet nichts ausser Zeit und liefert dieselbe Zahl, die die
# Verhandlung anschliessend anlegt. Sie ist keine Zusage: der Verein kann sich
# bis zum Angebot anders entscheiden, und was der Spieler sagt, steht auf einem
# anderen Blatt.

## Wie lange dieselbe Anfrage nicht wiederholt werden kann. Ohne diese Sperre
## waere die Anfrage ein Orakel, das man taeglich befragt, bis die Zahl passt.
const ANFRAGE_SPERRE := 10

static func _anfragen(d: Dictionary) -> Dictionary:
	var markt: Dictionary = d["transfermarkt"]
	if not markt.has("anfragen"):
		markt["anfragen"] = {}
	return markt["anfragen"]

static func anfrage_moeglich(d: Dictionary, sid: String) -> int:
	var wann: int = int(_anfragen(d).get(sid, -9999))
	return maxi(ANFRAGE_SPERRE - (int(d["tag"]) - wann), 0)

## Fragt beim abgebenden Verein an, ohne ein Angebot abzugeben.
static func anfrage(d: Dictionary, sid: String, kaeufer: String) -> Dictionary:
	if not d["spieler"].has(sid):
		return {"ok": false, "text": "Diesen Spieler gibt es nicht."}
	var sp: Dictionary = d["spieler"][sid]
	var von: String = str(sp["verein"])
	if von == "":
		return {"ok": true, "haltung": "vereinslos", "forderung": 0.0,
			"text": "%s ist vereinslos. Es braucht keine Ablöse, nur einen Vertrag." % Spielerfabrik.kurz_name(sp)}
	if von == kaeufer:
		return {"ok": false, "text": "Er spielt bereits bei Ihnen."}
	var rest: int = anfrage_moeglich(d, sid)
	if rest > 0:
		return {"ok": false, "text": "Sie haben gerade erst angefragt. In %d Tagen wieder." % rest}
	_anfragen(d)[sid] = int(d["tag"])
	var verkaeufer: Dictionary = d["vereine"][von]
	var name: String = Spielerfabrik.kurz_name(sp)

	if unverkaeuflich(d, sid):
		return {"ok": true, "haltung": "unverkaeuflich", "forderung": 0.0,
			"text": "%s winkt sofort ab: %s ist nicht zu haben, der Kader gäbe es nicht her." % [
				str(verkaeufer["name"]), name]}

	var schwelle: float = verkaufsschwelle(d, sid)
	var listenpreis: float = ablösevorstellung(d, sid)
	var haltung := "gespraechsbereit"
	var ton := "%s ist gesprächsbereit." % str(verkaeufer["name"])
	if schwelle > listenpreis * 1.15:
		haltung = "schmerzgrenze"
		ton = "%s will %s eigentlich behalten — auf der Position steht sonst niemand." % [
			str(verkaeufer["name"]), name]
	elif float(verkaeufer["kasse"]) < 0.0:
		haltung = "verkaufsdruck"
		ton = "%s steckt in Zahlungsschwierigkeiten und hört sich Angebote an." % str(verkaeufer["name"])
	elif bool(sp.get("transferwunsch", false)) or bool(sp.get("auf_transferliste", false)):
		haltung = "abgabebereit"
		ton = "%s würde %s abgeben." % [str(verkaeufer["name"]), name]

	# Was der Spieler selbst dazu sagt. Ein Verein kann zustimmen, so viel er
	# will — kommen muss der Mann.
	var gehalt: float = Spielerfabrik.gehaltsvorstellung(sp, float(d["vereine"][kaeufer].get("ruf", 50.0)))
	var spielertext := ""
	if Wechselbereitschaft.hat_abfuhr(d, sid, kaeufer):
		spielertext = "Er hat Ihnen kürzlich abgesagt."
	elif Wechselbereitschaft.rivalitaetsabschlag(d, sid, kaeufer) > 0.20:
		spielertext = "Zu Ihnen käme er ohnehin nicht — dafür sitzt die Rivalität zu tief."
	elif Wechselbereitschaft.ansprechbar(d, sid, kaeufer, "stammspieler", gehalt * 1.15):
		spielertext = "Er wäre ansprechbar."
	else:
		spielertext = Wechselbereitschaft.absage_grund(d, sid, kaeufer)

	return {"ok": true, "haltung": haltung, "forderung": schwelle,
		"text": "%s Unter %s braucht Ihnen niemand zu kommen. %s" % [
			ton, Stil.geld(schwelle), spielertext]}

static func _hat_ersatz(d: Dictionary, cid: String, sid: String) -> bool:
	var sp: Dictionary = d["spieler"][sid]
	var pos: String = str(sp["position"])
	var anzahl := 0
	for anderer in d["vereine"][cid]["kader"]:
		if anderer == sid:
			continue
		var asp: Dictionary = d["spieler"][anderer]
		if str(asp["position"]) == pos or Spielerfabrik.eignung(asp, pos) > 0.8:
			anzahl += 1
	return anzahl >= (1 if pos == "TW" else 2)

static func _spielerverhandlung(d: Dictionary, a: Dictionary) -> void:
	var sid: String = str(a["spieler"])
	var sp: Dictionary = d["spieler"][sid]
	var nach: String = str(a["nach"])
	var kaeufer: Dictionary = d["vereine"][nach]
	var wunsch: float = Finanzen.gehaltswunsch(d, nach, sp)
	var geboten: float = float(a["gehalt"])
	var attraktivitaet := _attraktivitaet(d, sp, nach, str(a["rolle"]), geboten)
	var schwelle: float = wunsch * clampf(1.12 - attraktivitaet * 0.28, 0.78, 1.25)
	# Zugesagte Erfolgsprämien ersetzen einen Teil des Festgehalts.
	schwelle -= Praemien.gehaltsersatz(d, sp, float(a.get("praemie_tor", 0.0)), float(a.get("praemie_sieg", 0.0)), nach)
	schwelle = maxf(schwelle, wunsch * 0.5)
	if geboten >= schwelle:
		_transfer_vollziehen(d, a)
	elif geboten >= schwelle * 0.85:
		a["status"] = "spieler_gegenangebot"
		a["gehaltsforderung"] = schwelle * Namen.bereich(1.0, 1.06)
		a["antwort"] = "%s verlangt %s pro Woche." % [Spielerfabrik.voller_name(sp), Stil.geld(float(a["gehaltsforderung"]))]
		a["frist_tag"] = int(d["tag"]) + 2
		_melde(d, a, "Gehaltsforderung von %s" % Spielerfabrik.voller_name(sp), a["antwort"])
	else:
		a["status"] = "abgelehnt"
		a["antwort"] = Wechselbereitschaft.absage_grund(d, sid, nach)
		Wechselbereitschaft.abfuhr_merken(d, sid, nach)
		_melde(d, a, "Spieler lehnt ab", a["antwort"])

## 0..1 — wie attraktiv ist ein Wechsel fuer den Spieler?
##
## Die Rechnung liegt in kern/Wechselbereitschaft.gd, weil sie nicht nur hier
## gebraucht wird: bevor ein Verein ueberhaupt anruft, muss er dieselbe Frage
## stellen koennen.
static func _attraktivitaet(d: Dictionary, sp: Dictionary, ziel: String, rolle: String,
		gehalt: float = -1.0) -> float:
	return Wechselbereitschaft.zielwert(d, str(sp["id"]), ziel, rolle, gehalt)

static func _kaderstaerke(d: Dictionary, cid: String) -> float:
	var summe := 0.0
	var n := 0
	for sid in d["vereine"][cid]["kader"]:
		summe += Spielerfabrik.gesamt(d["spieler"][sid])
		n += 1
	return summe / maxf(float(n), 1.0)

static func _melde(d: Dictionary, a: Dictionary, betreff: String, text: String) -> void:
	if str(a["nach"]) != Welt.mein_verein_id and str(a["von"]) != Welt.mein_verein_id:
		return
	Welt.nachricht({
		"typ": "transfer", "betreff": betreff, "text": text,
		"daten": {"angebot": str(a["id"]), "spieler": str(a["spieler"])},
	})

## Nachbessern eines laufenden Angebots.
static func nachbessern(d: Dictionary, angebots_id: String, ablöse: float, gehalt: float) -> Dictionary:
	for a in d["transfermarkt"]["angebote"]:
		if str(a["id"]) != angebots_id:
			continue
		if str(a["status"]) in ["abgeschlossen", "abgelehnt"]:
			return {"ok": false, "grund": "Diese Verhandlung ist beendet."}
		a["ablöse"] = ablöse
		a["gehalt"] = gehalt
		a["status"] = "offen" if str(a["status"]) == "gegenangebot" else "verein_einig"
		a["frist_tag"] = int(d["tag"]) + Namen.wuerfel(1, 2)
		return {"ok": true, "grund": "Nachgebessertes Angebot übermittelt."}
	return {"ok": false, "grund": "Angebot nicht gefunden."}

static func zurueckziehen(d: Dictionary, angebots_id: String) -> void:
	for a in d["transfermarkt"]["angebote"]:
		if str(a["id"]) == angebots_id:
			a["status"] = "zurueckgezogen"

# ------------------------------------------------------------- Vollziehen ---

static func _transfer_vollziehen(d: Dictionary, a: Dictionary) -> void:
	# Ein Vorvertrag wechselt niemanden: er hinterlegt eine Zusage, die erst
	# zum Saisonwechsel eingeloest wird.
	if str(a.get("art", "")) == "vorvertrag":
		var erlaubt := Vorvertrag.moeglich(d, str(a["spieler"]))
		if not bool(erlaubt["ok"]):
			a["status"] = "abgelehnt"
			a["antwort"] = str(erlaubt["grund"])
			return
		Vorvertrag.schliessen(d, str(a["spieler"]), str(a["nach"]),
			float(a["gehalt"]), int(a["laufzeit"]), str(a["rolle"]))
		a["status"] = "abgeschlossen"
		a["antwort"] = "Unterschrieben — er kommt zum Saisonwechsel."
		return
	var sid: String = str(a["spieler"])
	var nach: String = str(a["nach"])
	var ablöse: float = float(a["ablöse"])
	if str(a["art"]) == "leihe":
		leihe_vollziehen(d, sid, nach, int(a["laufzeit"]))
		a["status"] = "abgeschlossen"
		return
	transfer_durchfuehren(d, sid, nach, ablöse, float(a["gehalt"]), int(a["laufzeit"]), str(a["rolle"]),
		float(a.get("praemie_tor", 0.0)), float(a.get("praemie_sieg", 0.0)))
	a["status"] = "abgeschlossen"
	a["antwort"] = "Der Wechsel ist perfekt."
	_melde(d, a, "Transfer abgeschlossen", "%s wechselt für %s." % [Spielerfabrik.voller_name(d["spieler"][sid]), Stil.geld(ablöse)])

static func transfer_durchfuehren(d: Dictionary, sid: String, nach: String, ablöse: float,
		gehalt: float, laufzeit: int, rolle: String,
		praemie_tor: float = 0.0, praemie_sieg: float = 0.0) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var von: String = str(sp["verein"])
	# Der Index der Vereinslosen fuehrt diesen Namen nicht mehr. Wer zu einem
	# Verein geht, wird gestrichen; wer vereinslos wird, macht den ganzen
	# Index ungueltig — das ist der seltene Fall.
	if nach == "":
		KI.freie_leeren()
	else:
		KI.frei_streichen(sid)
	# Die Zusatzklauseln des alten Vertrags müssen abgerechnet werden, bevor
	# der neue Vertrag sie überschreibt.
	var alte_beteiligung: float = float(sp.get("vertrag", {}).get("weiterverkauf", 0.0))
	if von != "" and d["vereine"].has(von):
		# Bevor der Kader ihn vergisst: wer geht, bleibt als Ehemaliger stehen.
		Ehemalige.vermerken(d, von, sid, "transfer", nach, ablöse)
		# Nach einem Wechsel steht dieser Spieler bei einem anderen Verein.
		Konkurrenz.speicher_leeren(sid)
		Projekte.aufgeben(d, von, sid)
		(d["vereine"][von]["kader"] as Array).erase(sid)
		Finanzen.buchen(d, von, ablöse, "Transfererlös %s" % Spielerfabrik.voller_name(sp), "transfer")
		aufstellung_saeubern(d, von, sid)
		# Die Kurve merkt sich, wer verkauft wurde. Ein Ergänzungsspieler
		# interessiert niemanden, ein Leistungsträger schon.
		var rolle_alt: String = str((sp.get("vertrag", {}) as Dictionary).get("rolle", "rotation"))
		if rolle_alt in ["leistungstraeger", "stammspieler"]:
			var saison_alt: Dictionary = (d["vereine"][von] as Dictionary).get("saison", {})
			if not saison_alt.is_empty():
				saison_alt["verkaufte_stammspieler"] = int(saison_alt.get("verkaufte_stammspieler", 0)) + 1
	if nach != "" and d["vereine"].has(nach):
		(d["vereine"][nach]["kader"] as Array).append(sid)
		Trikot.vergeben(d, nach, sid)
		Finanzen.buchen(d, nach, -ablöse, "Ablöse %s" % Spielerfabrik.voller_name(sp), "transfer")
		d["vereine"][nach]["transferbudget"] = maxf(float(d["vereine"][nach]["transferbudget"]) - ablöse, 0.0)
	sp["verein"] = nach
	sp["kenntnis"] = 100.0 if nach == Welt.mein_verein_id else float(sp["kenntnis"])
	sp["vertrag"] = {
		"bis_saison": Welt.saison_index() + maxi(laufzeit, 1),
		"gehalt": gehalt,
		"rolle": rolle,
		"ablöseklausel": 0.0,
		"unterschrieben_saison": Welt.saison_index(),
		"praemie_tor": Praemien.begrenzen(praemie_tor, praemie_sieg)["praemie_tor"],
		"praemie_sieg": Praemien.begrenzen(praemie_tor, praemie_sieg)["praemie_sieg"],
	}
	sp["auf_transferliste"] = false
	sp["transferwunsch"] = false
	sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) - 40.0, 0.0, 100.0)
	sp["moral"] = clampf(float(sp["moral"]) + 12.0, 5.0, 100.0)
	_verlauf_eintragen(d, {
		"tag": int(d["tag"]), "spieler": sid, "von": von, "nach": nach, "ablöse": ablöse, "art": "kauf",
	})
	Laufbahn.wechsel(d, sid, von, nach, ablöse)
	Klauseln.verkauf_abrechnen(d, sid, von, ablöse, alte_beteiligung)
	Medien.transfer_meldung(d, sid, von, nach, ablöse)
	Chronik.transfer_pruefen(d, sid, ablöse)
	if nach != "":
		KI.aufstellung_pruefen(d, nach)

## Transferverlauf mit Deckel — sonst waechst er ueber viele Jahre endlos.
static func _verlauf_eintragen(d: Dictionary, eintrag: Dictionary) -> void:
	var verlauf: Array = d["transfermarkt"]["verlauf"]
	verlauf.push_front(eintrag)
	if verlauf.size() > 300:
		verlauf.resize(300)

static func aufstellung_saeubern(d: Dictionary, cid: String, sid: String) -> void:
	var auf: Dictionary = d["vereine"][cid]["aufstellung"]
	for block in ["angriff", "abwehr"]:
		var b: Dictionary = auf.get(block, {})
		for pos in b.keys():
			if str(b[pos]) == sid:
				b[pos] = ""
	(auf["bank"] as Array).erase(sid)
	if str(auf.get("kapitaen", "")) == sid:
		auf["kapitaen"] = ""
	if str(auf.get("siebenmeter", "")) == sid:
		auf["siebenmeter"] = ""
	(auf.get("anweisungen", {}) as Dictionary).erase(sid)
	(auf.get("minuten", {}) as Dictionary).erase(sid)

static func leihe_vollziehen(d: Dictionary, sid: String, nach: String, saisons: int) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var von: String = str(sp["verein"])
	sp["leihe"] = {"stammverein": von, "bis_saison": Welt.saison_index() + maxi(saisons, 1)}
	if von != "" and d["vereine"].has(von):
		Ehemalige.vermerken(d, von, sid, "leihe", nach, 0.0)
		Konkurrenz.speicher_leeren(sid)
		(d["vereine"][von]["kader"] as Array).erase(sid)
		aufstellung_saeubern(d, von, sid)
	(d["vereine"][nach]["kader"] as Array).append(sid)
	Trikot.vergeben(d, nach, sid)
	sp["verein"] = nach
	_verlauf_eintragen(d, {
		"tag": int(d["tag"]), "spieler": sid, "von": von, "nach": nach, "ablöse": 0.0, "art": "leihe",
	})
	Laufbahn.leihe(d, sid, von, nach)
	Weltgenerator.setze_standardaufstellung(d, nach)

# ------------------------------------------------------- Ablöseklausel ---

## Eine Ablöseklausel ist ein Zugestaendnis: Der Spieler weiss, dass er den
## Verein zu einem festen Preis verlassen kann, und laesst sich das mit einem
## Abschlag beim Gehalt bezahlen. Je niedriger die Klausel, desto mehr ist sie
## ihm wert — und desto groesser das Risiko fuer den Verein.
const KLAUSEL_MINDESTFAKTOR := 0.8

## Was eine Klausel dem Spieler wert ist, ausgedrueckt als Rabatt aufs
## Wochengehalt (0..1 des Gehaltswunsches).
static func klausel_rabatt(d: Dictionary, sp: Dictionary, klausel: float) -> float:
	if klausel <= 0.0:
		return 0.0
	var wert: float = maxf(float(sp["wert"]), 1000.0)
	# Bei Klausel = Marktwert ist der Rabatt am groessten, bei sehr hohen
	# Klauseln laeuft er gegen null: eine Klausel, die nie greift, zaehlt nicht.
	var verhaeltnis: float = clampf(klausel / wert, KLAUSEL_MINDESTFAKTOR, 6.0)
	var ehrgeiz: float = float(sp["charakter"].get("ehrgeiz", 12.0)) / 20.0
	return clampf(0.20 / verhaeltnis * (0.6 + ehrgeiz * 0.8), 0.0, 0.22)

## Die niedrigste Klausel, die ein Spieler ueberhaupt akzeptiert bekommt —
## darunter wuerde der Verein sich selbst verkaufen.
static func klausel_untergrenze(sp: Dictionary) -> float:
	return maxf(float(sp["wert"]), 1000.0) * KLAUSEL_MINDESTFAKTOR

## Taeglich pruefen, ob ein fremder Verein eine Klausel zieht.
static func klauseln_pruefen(d: Dictionary) -> void:
	if not fenster_offen(d):
		return
	for cid in Weltgenerator.clubs(d):
		if cid == Welt.mein_verein_id:
			continue
		var kader: Array = (d["vereine"][cid]["kader"] as Array).duplicate()
		for sid in kader:
			var sp: Dictionary = d["spieler"][sid]
			var klausel: float = float(sp["vertrag"].get("ablöseklausel", 0.0))
			if klausel <= 0.0:
				continue
			_klausel_versuchen(d, sid, sp, klausel)
	# Auch die eigenen Spieler koennen weggekauft werden.
	if Welt.mein_verein_id == "" or not d["vereine"].has(Welt.mein_verein_id):
		return
	for sid2 in (d["vereine"][Welt.mein_verein_id]["kader"] as Array).duplicate():
		var sp2: Dictionary = d["spieler"][sid2]
		var k2: float = float(sp2["vertrag"].get("ablöseklausel", 0.0))
		if k2 > 0.0:
			_klausel_versuchen(d, sid2, sp2, k2)

static func _klausel_versuchen(d: Dictionary, sid: String, sp: Dictionary, klausel: float) -> void:
	# Nur selten, damit nicht jeder Klauselspieler sofort weg ist.
	if Namen.zufall() > 0.02:
		return
	var von: String = str(sp["verein"])
	# Auch eine Klausel raeumt keinen Kader leer. Sie ist eine harte Zusage,
	# aber ein Verein, der danach ohne Torwart oder ohne Mannschaft dastuende,
	# ist kein schwerer Spielstand, sondern ein kaputter — und keine Klausel
	# der Welt fuehrt aus ihm heraus.
	if unverkaeuflich(d, sid):
		return
	var staerke: float = Spielerfabrik.gesamt(sp)
	var interessenten: Array = []
	for cid in Weltgenerator.clubs(d):
		if cid == von:
			continue
		# Der eigene Verein kauft niemanden hinter dem Rücken des Trainers.
		# Eine Klausel zu ziehen ist eine Entscheidung, keine Automatik.
		if cid == Welt.mein_verein_id:
			continue
		var v: Dictionary = d["vereine"][cid]
		if float(v["transferbudget"]) < klausel or float(v["kasse"]) < klausel * 0.6:
			continue
		if _kaderstaerke(d, cid) + 2.0 > staerke:
			continue
		if (v["kader"] as Array).size() >= 26:
			continue
		interessenten.append(cid)
	if interessenten.is_empty():
		return
	var nach: String = str(Namen.waehle(interessenten))
	if _attraktivitaet(d, sp, nach, "stammspieler") < 0.45:
		return
	var gehalt: float = Finanzen.gehaltswunsch(d, nach, sp) * 1.1
	var name: String = Spielerfabrik.voller_name(sp)
	transfer_durchfuehren(d, sid, nach, klausel, gehalt, Namen.wuerfel(3, 5), "leistungstraeger")
	if von == Welt.mein_verein_id:
		Welt.nachricht({
			"typ": "transfer", "wichtig": true,
			"betreff": "Ablöseklausel gezogen: %s" % name,
			"text": "%s hat die Ablöseklausel von %s in Höhe von %s bezahlt. Der Wechsel war nicht zu verhindern — die Klausel stand so im Vertrag." % [
				str(d["vereine"][nach]["name"]), name, Stil.geld(klausel)],
			"daten": {"spieler": sid},
		})

## Vertragsverlaengerung eines eigenen Spielers.
static func vertrag_verlaengern(d: Dictionary, sid: String, gehalt: float, laufzeit: int, rolle: String,
		praemie_tor: float = 0.0, praemie_sieg: float = 0.0, klausel: float = 0.0,
		zusatz: Dictionary = {}) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var cid: String = str(sp["verein"])
	var wunsch: float = Finanzen.gehaltswunsch(d, cid, sp)
	var rollen_bonus: float = {"leistungstraeger": 0.9, "stammspieler": 0.96, "rotation": 1.0, "ergaenzung": 1.08, "talent": 1.0}.get(rolle, 1.0)
	var schwelle: float = wunsch * rollen_bonus * clampf(1.0 + float(sp["unzufriedenheit"]) / 260.0, 1.0, 1.4)
	var grenzen := Praemien.begrenzen(praemie_tor, praemie_sieg)
	schwelle = maxf(schwelle - Praemien.gehaltsersatz(d, sp, grenzen["praemie_tor"], grenzen["praemie_sieg"]),
		wunsch * 0.5)
	# Eine Ablöseklausel senkt die Gehaltsforderung — sie ist dem Spieler etwas wert.
	var gueltige_klausel: float = 0.0
	if klausel > 0.0:
		gueltige_klausel = maxf(klausel, klausel_untergrenze(sp))
		schwelle *= 1.0 - klausel_rabatt(d, sp, gueltige_klausel)
	# Zusatzklauseln senken die Forderung ebenfalls.
	if not zusatz.is_empty():
		schwelle *= 1.0 - Klauseln.gehaltsersatz(d, sp, zusatz)
	if gehalt >= schwelle:
		if not zusatz.is_empty():
			Klauseln.schreiben(sp, zusatz)
		sp["vertrag"]["gehalt"] = gehalt
		sp["vertrag"]["bis_saison"] = Welt.saison_index() + maxi(laufzeit, 1)
		sp["vertrag"]["rolle"] = rolle
		sp["vertrag"]["praemie_tor"] = grenzen["praemie_tor"]
		sp["vertrag"]["praemie_sieg"] = grenzen["praemie_sieg"]
		sp["vertrag"]["ablöseklausel"] = gueltige_klausel
		sp["unzufriedenheit"] = clampf(float(sp["unzufriedenheit"]) - 25.0, 0.0, 100.0)
		sp["moral"] = clampf(float(sp["moral"]) + 8.0, 5.0, 100.0)
		return {"ok": true, "grund": "%s hat unterschrieben." % Spielerfabrik.voller_name(sp)}
	return {"ok": false, "grund": "%s erwartet mindestens %s pro Woche." % [Spielerfabrik.voller_name(sp), Stil.geld(schwelle)]}

static func auf_transferliste(d: Dictionary, sid: String, wert: bool) -> void:
	d["spieler"][sid]["auf_transferliste"] = wert

## Einen Spieler entlassen (Vertragsaufloesung gegen Abfindung).
## Einen Vertrag aufloesen.
##
## ohne_abfindung ist der Zahlungsverzug: ein Spieler, dessen Verein ihn nicht
## mehr bezahlt, kann ausserordentlich kuendigen und geht ohne einen Cent. Das
## ist kein Schlupfloch fuer den Trainer, sondern der letzte Ausweg eines
## Vereins, der am Ende ist — und der Weg, auf dem sich eine Gehaltslast wieder
## loest, wenn zum Verkaufen niemand da ist.
static func vertrag_aufloesen(d: Dictionary, sid: String, ohne_abfindung: bool = false) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var cid: String = str(sp["verein"])
	var rest: int = maxi(int(sp["vertrag"].get("bis_saison", 0)) - Welt.saison_index(), 0)
	var abfindung: float = 0.0 if ohne_abfindung else \
		float(sp["vertrag"].get("gehalt", 0.0)) * 52.0 * float(rest) * 0.45
	if float(d["vereine"][cid]["kasse"]) < abfindung:
		return {"ok": false, "grund": "Die Abfindung von %s ist nicht finanzierbar." % Stil.geld(abfindung)}
	if abfindung > 0.0:
		Finanzen.buchen(d, cid, -abfindung, "Abfindung %s" % Spielerfabrik.voller_name(sp), "transfer")
	Ehemalige.vermerken(d, cid, sid, "freistellung", "", 0.0)
	Konkurrenz.speicher_leeren(sid)
	Projekte.aufgeben(d, cid, sid)
	(d["vereine"][cid]["kader"] as Array).erase(sid)
	aufstellung_saeubern(d, cid, sid)
	sp["verein"] = ""
	sp["vertrag"] = {}
	KI.freie_leeren()  # er steht jetzt im Markt der Vereinslosen
	if ohne_abfindung:
		return {"ok": true, "grund": "%s hat seinen Vertrag wegen ausstehender Gehälter gekündigt." % Spielerfabrik.voller_name(sp)}
	return {"ok": true, "grund": "%s wurde freigestellt (Abfindung: %s)." % [Spielerfabrik.voller_name(sp), Stil.geld(abfindung)]}

# ------------------------------------------------------------- KI-Markt ---

static func _ki_transferrunde(d: Dictionary, dringlich: bool = false) -> void:
	if not fenster_offen(d):
		return
	var vereine: Array = Weltgenerator.clubs(d)
	vereine.shuffle()
	var geschaefte := 0
	# Ein Deadline-Tag ist keine zweite volle Transferwoche. Der erste Versuch
	# liess an jedem der drei Tage dieselbe Runde laufen wie montags — das
	# verdreifachte das Volumen und trieb die Zahl der Vereine mit negativer
	# Kasse ueber drei Saisons von 2 auf 15. Dringlichkeit heisst hier: ein
	# paar Vereine handeln noch, nicht alle noch einmal.
	var deckel: int = 5 if dringlich else 14
	var neigung: float = 0.14 if dringlich else 0.35
	var kandidaten := _rundenkandidaten(d)
	for cid in vereine:
		if cid == Welt.mein_verein_id:
			if not dringlich:
				_angebot_fuer_eigene_spieler(d, cid)
			continue
		if geschaefte > deckel:
			break
		if Namen.zufall() > neigung:
			continue
		if _ki_verstaerkung(d, cid, kandidaten):
			geschaefte += 1

## Die Kandidatenliste der Wochenrunde — einmal statt fuenfzigmal.
##
## Gemessen hat Transfermarkt.tageswechsel 36 von 65 Sekunden im Tageswechsel
## gekostet, und zwar hier: jeder der bis zu sechsundfuenfzig handelnden
## Vereine rief suchen() auf und durchlief dafuer alle 3624 Spieler der Welt,
## um sie danach nach Staerke zu sortieren. Gesucht wird aber jedes Mal
## dasselbe — die besten verfuegbaren Spieler je Position. Also wird die
## Liste einmal je Runde gebaut und herumgereicht.
##
## Achtzig je Position statt der sechzig von suchen(): in der
## gemeinsamen Liste stehen auch die eigenen Spieler des fragenden Vereins,
## und die soll er nicht von seinen Kandidaten abziehen muessen.
const KANDIDATEN_JE_POSITION := 80

static func _rundenkandidaten(d: Dictionary) -> Dictionary:
	var nach_pos := {}
	for sid in (d["spieler"] as Dictionary).keys():
		var sp: Dictionary = d["spieler"][sid]
		if bool(sp.get("jugendspieler", false)):
			continue
		var pos: String = str(sp["position"])
		if not nach_pos.has(pos):
			nach_pos[pos] = []
		(nach_pos[pos] as Array).append(str(sid))
	for pos2 in nach_pos.keys():
		nach_pos[pos2] = Spielerfabrik.nach_staerke(d, nach_pos[pos2]).slice(0, KANDIDATEN_JE_POSITION)
	return nach_pos

static func _ki_verstaerkung(d: Dictionary, cid: String, kandidaten: Dictionary = {}) -> bool:
	var v: Dictionary = d["vereine"][cid]
	var budget: float = float(v["transferbudget"])
	if budget < 25000.0:
		return false
	# Wer knapp bei Kasse ist, kauft nicht.
	#
	# Das Transferbudget ist eine Planungsgroesse und sagt nichts darueber,
	# ob morgen die Gehaelter gedeckt sind. Ohne diese Schranke kauften
	# Computervereine sich ueber Jahre in die Ueberschuldung — nicht durch die
	# Abloese, sondern durch die Gehaelter, die daran haengen. Sechs
	# Wochenloehne muessen in der Kasse bleiben.
	if float(v["kasse"]) < float(v.get("gehaltsbudget", 0.0)) * 6.0:
		return false
	var schwaeche := schwaechste_position(d, cid)
	if schwaeche == "":
		return false
	var liste: Array = kandidaten.get(schwaeche, []) if not kandidaten.is_empty() \
		else suchen(d, {"position": schwaeche, "limit": 60}, cid)
	var kaderstaerke := _kaderstaerke(d, cid)
	for sid in liste:
		var sp: Dictionary = d["spieler"][sid]
		if str(sp["verein"]) == cid:
			continue
		if Spielerfabrik.gesamt(sp) < kaderstaerke + 3.0:
			continue
		if unverkaeuflich(d, sid):
			continue
		var preis := ablösevorstellung(d, sid)
		if preis > budget:
			continue
		var gehalt := Finanzen.gehaltswunsch(d, cid, sp)
		if gehalt * 52.0 > float(v["gehaltsbudget"]) * 52.0 * 0.18:
			continue
		if str(sp["verein"]) == Welt.mein_verein_id:
			# Auch hier erst pruefen, ob der Spieler zusagen wuerde. Das ist
			# die zweite und groessere Quelle der Angebotsflut gewesen: jeder
			# Verein, der sich verstaerken wollte und dabei auf einen Spieler
			# des Menschen stiess, hat geboten — unabhaengig davon, ob der
			# jemals gewechselt waere.
			if _offene_eingehende(d) >= EINGEHEND_MAX:
				continue
			if Wechselbereitschaft.hat_abfuhr(d, sid, cid):
				continue
			var paket := _werbepaket(d, cid, sid, gehalt)
			if not Wechselbereitschaft.ansprechbar(d, sid, cid,
					str(paket["rolle"]), float(paket["gehalt"])):
				continue
			_angebot_an_spieler(d, cid, sid, preis, gehalt)
			return true
		if _attraktivitaet(d, sp, cid, "stammspieler", gehalt) < 0.42:
			continue
		transfer_durchfuehren(d, sid, cid, preis, gehalt, Namen.wuerfel(2, 4), "stammspieler")
		return true
	return false

static func schwaechste_position(d: Dictionary, cid: String) -> String:
	var beste := {}
	for pos in Spielerfabrik.POSITIONEN:
		beste[pos] = 0.0
	for sid in d["vereine"][cid]["kader"]:
		var sp: Dictionary = d["spieler"][sid]
		for pos in Spielerfabrik.POSITIONEN:
			var w: float = Spielerfabrik.angriff_auf(sp, pos) if pos != "TW" else (Spielerfabrik.gesamt(sp) if bool(sp["ist_torwart"]) else 0.0)
			if w > float(beste[pos]):
				beste[pos] = w
	var schwaechste := ""
	var minwert := 999.0
	for pos in beste.keys():
		if float(beste[pos]) < minwert:
			minwert = float(beste[pos])
			schwaechste = pos
	return schwaechste

## Ein KI-Verein bietet fuer einen Spieler des menschlichen Trainers.
## Was ein Verein bieten muss, um diesen Spieler zu bekommen.
##
## Bisher bot jeder dasselbe: Stammspieler zum Standardgehalt. Damit war ein
## Wechsel entweder von vornherein attraktiv oder von vornherein aussichtslos,
## und ein Verein hatte keine Möglichkeit, um jemanden zu werben. Wer einen
## Führungsspieler holen will, bietet ihm die Rolle des Führungsspielers und
## legt beim Gehalt drauf — und genau daran scheitert es dann auch, wenn er
## es sich nicht leisten kann.
static func _werbepaket(d: Dictionary, kaeufer: String, sid: String, grundgehalt: float) -> Dictionary:
	var sp: Dictionary = d["spieler"][sid]
	var v: Dictionary = d["vereine"][kaeufer]
	var eigen: float = Spielerfabrik.gesamt(sp)
	var kader := _kaderstaerke(d, kaeufer)
	# Wer deutlich besser ist als der Schnitt, bekommt die grosse Rolle.
	var rolle := "stammspieler"
	if eigen >= kader + 6.0:
		rolle = "leistungstraeger"
	elif eigen < kader - 4.0:
		rolle = "rotation"
	var gehalt := grundgehalt
	# So lange draufpacken, bis er zusagen wuerde — hoechstens die Haelfte
	# obendrauf, und nie ueber das, was der Verein tragen kann.
	var decke: float = float(v["gehaltsbudget"]) * 0.20
	for _stufe in range(5):
		if Wechselbereitschaft.ansprechbar(d, sid, kaeufer, rolle, gehalt):
			break
		var naechstes: float = gehalt * 1.12
		if naechstes > grundgehalt * 1.5 or naechstes > decke:
			break
		gehalt = naechstes
	return {"rolle": rolle, "gehalt": gehalt}

static func _angebot_an_spieler(d: Dictionary, kaeufer: String, sid: String, ablöse: float, gehalt: float) -> void:
	var sp: Dictionary = d["spieler"][sid]
	var paket := _werbepaket(d, kaeufer, sid, gehalt)
	var angebot := {
		"id": _neue_angebots_id(d),
		"art": "kauf",
		"spieler": sid,
		"von": str(sp["verein"]),
		"nach": kaeufer,
		"ablöse": ablöse * Namen.bereich(0.85, 1.15),
		"gehalt": float(paket["gehalt"]),
		"laufzeit": Namen.wuerfel(2, 4),
		"rolle": str(paket["rolle"]),
		"status": "eingegangen",
		"richtung": "eingehend",
		"frist_tag": int(d["tag"]) + Namen.wuerfel(3, 6),
		"antwort": "",
	}
	(d["transfermarkt"]["angebote"] as Array).append(angebot)
	Welt.nachricht({
		"typ": "transfer", "wichtig": true,
		"betreff": "Angebot für %s" % Spielerfabrik.voller_name(sp),
		"text": "%s bietet %s für %s. Die Frist läuft in %d Tagen ab." % [
			d["vereine"][kaeufer]["name"], Stil.geld(float(angebot["ablöse"])),
			Spielerfabrik.voller_name(sp), int(angebot["frist_tag"]) - int(d["tag"])],
		"daten": {"angebot": str(angebot["id"]), "spieler": sid},
	})

## Wie viele unbeantwortete Angebote gleichzeitig hoechstens hereinkommen.
##
## Ohne Deckel liegen bei einem Spitzenverein zweistellig viele gleichzeitig
## im Posteingang, und keines davon ist mehr eine Nachricht.
const EINGEHEND_MAX := 3

static func _offene_eingehende(d: Dictionary) -> int:
	var n := 0
	for a in d["transfermarkt"]["angebote"]:
		if str((a as Dictionary).get("richtung", "")) == "eingehend" \
				and str((a as Dictionary)["status"]) == "eingegangen":
			n += 1
	return n

static func _angebot_fuer_eigene_spieler(d: Dictionary, cid: String) -> void:
	if Namen.zufall() > 0.3:
		return
	if _offene_eingehende(d) >= EINGEHEND_MAX:
		return
	var kader: Array = d["vereine"][cid]["kader"]
	if kader.is_empty():
		return
	var sid: String = str(kader[Namen.wuerfel(0, kader.size() - 1)])
	var sp: Dictionary = d["spieler"][sid]
	if Spielerfabrik.gesamt(sp) < 55.0 and not bool(sp.get("auf_transferliste", false)):
		return
	if unverkaeuflich(d, sid):
		return
	var interessenten: Array = []
	for anderer in Weltgenerator.clubs(d):
		if anderer == cid:
			continue
		var av: Dictionary = d["vereine"][anderer]
		if float(av["ruf"]) < Spielerfabrik.gesamt(sp) - 18.0:
			continue
		if float(av["transferbudget"]) < float(sp["wert"]) * 0.8:
			continue
		# Die Frage, die vorher niemand stellte: wuerde er dort ueberhaupt
		# unterschreiben? Ohne sie gingen 210 Angebote in zwei Saisons ein,
		# von denen der Spieler 201 ablehnte — richtig abgelehnt, aber sinnlos
		# gestellt.
		if Wechselbereitschaft.hat_abfuhr(d, sid, str(anderer)):
			continue
		var paket := _werbepaket(d, str(anderer), sid, Finanzen.gehaltswunsch(d, str(anderer), sp))
		if not Wechselbereitschaft.ansprechbar(d, sid, str(anderer),
				str(paket["rolle"]), float(paket["gehalt"])):
			continue
		interessenten.append(anderer)
	if interessenten.is_empty():
		return
	var kaeufer: String = str(interessenten[Namen.wuerfel(0, interessenten.size() - 1)])
	_angebot_an_spieler(d, kaeufer, sid, ablösevorstellung(d, sid), Finanzen.gehaltswunsch(d, kaeufer, sp))

## Antwort des Spielers auf ein eingehendes Angebot.
static func eingehendes_angebot_entscheiden(d: Dictionary, angebots_id: String, annehmen: bool) -> Dictionary:
	for a in d["transfermarkt"]["angebote"]:
		if str(a["id"]) != angebots_id:
			continue
		if annehmen:
			var sid: String = str(a["spieler"])
			var sp: Dictionary = d["spieler"][sid]
			if _attraktivitaet(d, sp, str(a["nach"]), str(a["rolle"]), float(a["gehalt"])) < 0.30 \
					and not bool(sp.get("transferwunsch", false)):
				a["status"] = "abgelehnt"
				Wechselbereitschaft.abfuhr_merken(d, sid, str(a["nach"]))
				return {"ok": false, "grund": Wechselbereitschaft.absage_grund(d, sid, str(a["nach"]))}
			transfer_durchfuehren(d, sid, str(a["nach"]), float(a["ablöse"]), float(a["gehalt"]), int(a["laufzeit"]), str(a["rolle"]))
			a["status"] = "abgeschlossen"
			return {"ok": true, "grund": "Der Transfer ist vollzogen."}
		a["status"] = "abgelehnt"
		return {"ok": true, "grund": "Sie haben das Angebot abgelehnt."}
	return {"ok": false, "grund": "Angebot nicht gefunden."}

# ------------------------------------------------------------- Geruechte ---

static func geruechtekueche(d: Dictionary) -> void:
	if Welt.mein_verein_id == "":
		return
	if Namen.zufall() > 0.6:
		return
	var alle: Array = d["spieler"].keys()
	if alle.is_empty():
		return
	for i in range(Namen.wuerfel(1, 3)):
		var sid: String = str(alle[Namen.wuerfel(0, alle.size() - 1)])
		var sp: Dictionary = d["spieler"][sid]
		if Spielerfabrik.gesamt(sp) < 58.0:
			continue
		var ziele: Array = Weltgenerator.clubs(d)
		var ziel: String = str(ziele[Namen.wuerfel(0, ziele.size() - 1)])
		if ziel == str(sp["verein"]):
			continue
		var texte := [
			"%s soll bei %s auf der Liste stehen." % [Spielerfabrik.voller_name(sp), d["vereine"][ziel]["name"]],
			"Berater von %s führen angeblich Gespräche mit %s." % [Spielerfabrik.voller_name(sp), d["vereine"][ziel]["name"]],
			"%s zeigt Interesse an %s — bestätigt ist nichts." % [d["vereine"][ziel]["name"], Spielerfabrik.voller_name(sp)],
		]
		var text: String = str(texte[Namen.wuerfel(0, texte.size() - 1)])
		(d["transfermarkt"]["gerüchte"] as Array).push_front({"tag": int(d["tag"]), "text": text, "spieler": sid, "verein": ziel})
		if (d["transfermarkt"]["gerüchte"] as Array).size() > 60:
			(d["transfermarkt"]["gerüchte"] as Array).resize(60)
		if Namen.zufall() < 0.35:
			Medien.geruecht(d, text)

# --------------------------------------- Verhandeln über ein Angebot ---
#
# Bisher war ein eingehendes Angebot ein Ja-Nein-Knopf. Das ist genau die
# Situation, in der ein Sportdirektor eigentlich zum Hörer greift: der Preis
# stimmt nicht, aber reden kann man. Wer nur ablehnen kann, verhandelt nicht,
# er verwaltet.

## Wie weit über der gebotenen Ablöse eine Nachforderung noch besprochen wird.
const NACHFORDERUNG_MAX := 2.2

## Fordert für ein eingehendes Angebot eine höhere Ablöse.
##
## Der Käufer entscheidet sofort: er zahlt, er kommt entgegen, oder er steigt
## aus. Wie weit er geht, hängt daran, wie sehr er den Spieler braucht und was
## er sich leisten kann — nicht am Zufall allein.
static func gegenforderung_stellen(d: Dictionary, angebots_id: String, forderung: float) -> Dictionary:
	for a in d["transfermarkt"]["angebote"]:
		if str(a["id"]) != angebots_id:
			continue
		if str(a["richtung"]) != "eingehend" or str(a["status"]) != "eingegangen":
			return {"ok": false, "grund": "Über dieses Angebot lässt sich nicht mehr verhandeln."}
		var sid: String = str(a["spieler"])
		var sp: Dictionary = d["spieler"][sid]
		var kaeufer: Dictionary = d["vereine"][str(a["nach"])]
		var geboten: float = float(a["ablöse"])
		if forderung <= geboten:
			return {"ok": false, "grund": "Das wäre keine Nachforderung."}
		if forderung > geboten * NACHFORDERUNG_MAX:
			a["status"] = "abgelehnt"
			a["antwort"] = "%s hält die Forderung für unseriös und zieht das Angebot zurück." % str(kaeufer["name"])
			Wechselbereitschaft.abfuhr_merken(d, sid, str(a["nach"]))
			return {"ok": false, "grund": a["antwort"]}
		# Was der Käufer höchstens zu zahlen bereit ist: sein Budget, gedeckelt
		# durch den Wert des Spielers für ihn.
		var eigen: float = Spielerfabrik.gesamt(sp)
		var luecke: float = maxf(eigen - _kaderstaerke(d, str(a["nach"])), 0.0)
		var schmerzgrenze: float = minf(
			float(kaeufer["transferbudget"]),
			ablösevorstellung(d, sid) * (1.15 + clampf(luecke / 20.0, 0.0, 0.55)))
		if forderung <= schmerzgrenze:
			a["ablöse"] = forderung
			a["antwort"] = "%s geht mit: %s." % [str(kaeufer["name"]), Stil.geld(forderung)]
			return {"ok": true, "grund": "%s\n\nDas Angebot liegt jetzt bei %s — Sie können es annehmen." % [
				a["antwort"], Stil.geld(forderung)]}
		if schmerzgrenze > geboten * 1.04:
			# Teilweises Entgegenkommen: der Käufer legt nach, aber nicht bis
			# zur Forderung. Jetzt liegt der Ball wieder beim Verkäufer.
			a["ablöse"] = schmerzgrenze
			a["antwort"] = "%s bietet nach: %s. Mehr geht nicht." % [
				str(kaeufer["name"]), Stil.geld(schmerzgrenze)]
			return {"ok": true, "grund": "%s\n\nAnnehmen oder ablehnen." % a["antwort"]}
		a["status"] = "abgelehnt"
		a["antwort"] = "%s kann nicht nachlegen und zieht das Angebot zurück." % str(kaeufer["name"])
		Wechselbereitschaft.abfuhr_merken(d, sid, str(a["nach"]))
		return {"ok": false, "grund": a["antwort"]}
	return {"ok": false, "grund": "Angebot nicht gefunden."}

## Was der Käufer voraussichtlich noch zahlen würde — als Orientierung für die
## Oberfläche, damit man nicht ins Blaue fordert.
static func schmerzgrenze_schaetzen(d: Dictionary, angebots_id: String) -> float:
	for a in d["transfermarkt"]["angebote"]:
		if str(a["id"]) != angebots_id:
			continue
		var sid: String = str(a["spieler"])
		var eigen: float = Spielerfabrik.gesamt(d["spieler"][sid])
		var luecke: float = maxf(eigen - _kaderstaerke(d, str(a["nach"])), 0.0)
		return minf(float(d["vereine"][str(a["nach"])]["transferbudget"]),
			ablösevorstellung(d, sid) * (1.15 + clampf(luecke / 20.0, 0.0, 0.55)))
	return 0.0

## Die drei Nachforderungen, die zu einem Angebot passen.
##
## Benannte Stufen statt eines Schiebereglers: eine Forderung ist eine
## Entscheidung mit einer Zahl, kein Suchlauf. Was darüber liegt, nimmt der
## Käufer ohnehin nicht ernst — deshalb steht die Obergrenze fest.
static func forderungsstufen(d: Dictionary, a: Dictionary) -> Array:
	var geboten: float = float(a["ablöse"])
	var vorstellung: float = ablösevorstellung(d, str(a["spieler"]))
	var stufen: Array = [
		{"name": "+15 %", "betrag": geboten * 1.15},
		{"name": "+35 %", "betrag": geboten * 1.35},
	]
	# Die eigene Bewertung nur anbieten, wenn sie überhaupt darüber liegt und
	# noch im verhandelbaren Bereich ist.
	if vorstellung > geboten * 1.4 and vorstellung <= geboten * NACHFORDERUNG_MAX:
		stufen.append({"name": "Unsere Bewertung", "betrag": vorstellung})
	return stufen
