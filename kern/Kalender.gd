class_name Kalender
extends RefCounted
## Kalenderrechnung. Hallenherz benutzt ein vereinfachtes Jahr mit 365 Tagen
## (keine Schaltjahre) — dadurch ist jeder Tagindex eindeutig umrechenbar und
## Spielplaene bleiben ueber beliebig viele Saisons stabil.
##
## Tagindex 0 = 1. Juli des Startjahres. Eine Saison laeuft vom 1. Juli bis 30. Juni.

const MONATSTAGE := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONATSNAMEN := ["Januar", "Februar", "März", "April", "Mai", "Juni",
	"Juli", "August", "September", "Oktober", "November", "Dezember"]
const MONAT_KURZ := ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
const WOCHENTAGE := ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
const WOCHENTAG_KURZ := ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

const TAGE_IM_JAHR := 365
const JULI_ERSTER := 181  # Tag-im-Jahr-Index (0-basiert) des 1. Juli
const WOCHENTAG_VERSATZ := 2  # Tagindex 0 ist ein Mittwoch

## Wandelt einen absoluten Tagindex in ein Datum um.
static func datum(tag_abs: int, startjahr: int) -> Dictionary:
	var gesamt: int = JULI_ERSTER + tag_abs
	var jahr: int = startjahr + int(floor(float(gesamt) / float(TAGE_IM_JAHR)))
	var doy: int = posmod(gesamt, TAGE_IM_JAHR)
	var monat := 0
	var rest := doy
	while rest >= MONATSTAGE[monat]:
		rest -= MONATSTAGE[monat]
		monat += 1
	return {
		"jahr": jahr,
		"monat": monat + 1,
		"tag": rest + 1,
		"wochentag": posmod(tag_abs + WOCHENTAG_VERSATZ, 7),
	}

static func text(tag_abs: int, startjahr: int, lang: bool = false) -> String:
	var d := datum(tag_abs, startjahr)
	if lang:
		return "%s, %d. %s %d" % [WOCHENTAGE[d["wochentag"]], d["tag"], MONATSNAMEN[d["monat"] - 1], d["jahr"]]
	return "%s %02d.%s %d" % [WOCHENTAG_KURZ[d["wochentag"]], d["tag"], MONAT_KURZ[d["monat"] - 1], d["jahr"]]

static func kurz(tag_abs: int, startjahr: int) -> String:
	var d := datum(tag_abs, startjahr)
	return "%02d.%02d." % [d["tag"], d["monat"]]

## Saisonnummer eines Tagindex (0 = erste Saison).
static func saison_index(tag_abs: int) -> int:
	return int(floor(float(tag_abs) / float(TAGE_IM_JAHR)))

static func tag_in_saison(tag_abs: int) -> int:
	return posmod(tag_abs, TAGE_IM_JAHR)

## Beschriftung "2026/27" fuer eine Saison.
static func saison_text(startjahr: int, saison_idx: int) -> String:
	var a: int = startjahr + saison_idx
	return "%d/%02d" % [a, (a + 1) % 100]

static func ist_wochenende(tag_abs: int) -> bool:
	var wt: int = posmod(tag_abs + WOCHENTAG_VERSATZ, 7)
	return wt >= 5

static func wochentag(tag_abs: int) -> int:
	return posmod(tag_abs + WOCHENTAG_VERSATZ, 7)

## Naechster Tagindex innerhalb der Saison, der auf den gewuenschten Wochentag faellt.
static func naechster_wochentag(ab_tag: int, wunsch: int) -> int:
	var t := ab_tag
	while wochentag(t) != wunsch:
		t += 1
	return t
