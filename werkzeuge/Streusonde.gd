extends Node
## Woher kommt die Streuung einer einzelnen Partie?
##
## Die Realismussonde sagt nur, wie gross sie ist. Zum Schrauben braucht es
## die Herkunft: Wurfzufall, unterschiedlich viele Angriffe oder der
## Hallenpuls, der sich waehrend der Partie aufschaukelt. Dieselbe Paarung,
## viele Male, und danach die Rechnung.

const LAEUFE := 600

func _ready() -> void:
	Welt.daten = Weltgenerator.erzeuge(2026, 20260)
	Welt.mein_verein_id = ""
	var d := Welt.daten
	seed(20260)
	Spielplan.erzeuge_saison(d)
	var paarung := ""
	for mid in d["spiele"].keys():
		var m: Dictionary = d["spiele"][mid]
		if str(m["art"]) == "liga" and str(m.get("wettbewerb", "")) == "l_de1":
			paarung = str(mid)
			break
	var abst: Array = []
	var wurfdiff: Array = []
	var puls: Array = []
	var strafdiff: Array = []
	var tempodiff: Array = []
	var siebendiff: Array = []
	var wuerfe_ges := 0.0
	var tore_ges := 0.0
	for i in LAEUFE:
		for sid in d["spieler"].keys():
			(d["spieler"][sid] as Dictionary)["verletzung"] = {}
		var m2: Dictionary = (d["spiele"][paarung] as Dictionary).duplicate(true)
		var sim := Matchsim.new(d, m2, 700001 + i * 13)
		sim.vorbereiten()
		sim.schnell_simulieren()
		var hs: Dictionary = sim.heim["stats"]
		var gs: Dictionary = sim.gast["stats"]
		var nh: float = float(hs["wuerfe"]) + float(hs["siebenmeter"])
		var ng: float = float(gs["wuerfe"]) + float(gs["siebenmeter"])
		abst.append(float(int(sim.heim["tore"]) - int(sim.gast["tore"])))
		wurfdiff.append(nh - ng)
		puls.append(float(sim.hallenpuls))
		strafdiff.append(float(hs["zeitstrafen"]) - float(gs["zeitstrafen"]))
		tempodiff.append(float(hs["gegenstoss_wuerfe"]) - float(gs["gegenstoss_wuerfe"]))
		siebendiff.append(float(hs["siebenmeter"]) - float(gs["siebenmeter"]))
		wuerfe_ges += nh + ng
		tore_ges += float(int(sim.heim["tore"]) + int(sim.gast["tore"]))
	var p: float = tore_ges / wuerfe_ges
	var n: float = wuerfe_ges / float(LAEUFE) / 2.0
	printerr("")
	printerr("=== Streuung derselben Paarung, %d Laeufe ===" % LAEUFE)
	printerr("Wuerfe je Mannschaft %.1f, Trefferquote %.3f" % [n, p])
	printerr("Streuung Torabstand        %.2f" % _streuung(abst))
	printerr("   davon reiner Wurfzufall %.2f   (zwei Mannschaften, %.0f Wuerfe, p=%.2f)" % [
		sqrt(2.0 * n * p * (1.0 - p)), n, p])
	printerr("   Streuung Wurfdifferenz  %.2f   -> %.2f Tore" % [
		_streuung(wurfdiff), _streuung(wurfdiff) * p])
	printerr("   Streuung Hallenpuls     %.2f   (Mittel %.1f)" % [_streuung(puls), _mittel(puls)])
	printerr("   Zusammenhang Puls/Abstand r = %.2f" % _korrelation(puls, abst))
	printerr("   Zusammenhang Wurfdiff/Abstand r = %.2f" % _korrelation(wurfdiff, abst))
	# Was bleibt, wenn man die Wurfdifferenz herausrechnet? Der reine
	# Wurfzufall — und alles, was sonst noch am Ergebnis dreht. Liegt dieser
	# Rest deutlich ueber dem Wurfzufall, gibt es im Spiel eine Quelle von
	# Streuung, die nichts mit der Zahl der Wuerfe zu tun hat.
	printerr("   Rest ohne Wurfdifferenz %.2f   (Wurfzufall allein %.2f)" % [
		_reststreuung(wurfdiff, abst), sqrt(2.0 * n * p * (1.0 - p))])
	printerr("   Zeitstrafendifferenz    %.2f   r = %.2f" % [
		_streuung(strafdiff), _korrelation(strafdiff, abst)])
	printerr("   Siebenmeterdifferenz    %.2f   r = %.2f" % [
		_streuung(siebendiff), _korrelation(siebendiff, abst)])
	printerr("   Tempogegenstossdifferenz %.2f  r = %.2f" % [
		_streuung(tempodiff), _korrelation(tempodiff, abst)])
	get_tree().quit()

## Streuung des Ergebnisses, nachdem der lineare Einfluss von x entfernt ist.
func _reststreuung(x: Array, y: Array) -> float:
	var mx: float = _mittel(x)
	var my: float = _mittel(y)
	var kov := 0.0
	var varx := 0.0
	for i in x.size():
		kov += (float(x[i]) - mx) * (float(y[i]) - my)
		varx += (float(x[i]) - mx) * (float(x[i]) - mx)
	var steigung: float = kov / maxf(varx, 0.0001)
	var rest := 0.0
	for i in x.size():
		var d: float = float(y[i]) - (my + steigung * (float(x[i]) - mx))
		rest += d * d
	return sqrt(rest / float(x.size()))

func _mittel(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s / float(a.size())

func _streuung(a: Array) -> float:
	var m: float = _mittel(a)
	var q := 0.0
	for x in a:
		q += (float(x) - m) * (float(x) - m)
	return sqrt(q / float(a.size()))

func _korrelation(a: Array, b: Array) -> float:
	var ma: float = _mittel(a)
	var mb: float = _mittel(b)
	var kov := 0.0
	for i in a.size():
		kov += (float(a[i]) - ma) * (float(b[i]) - mb)
	kov /= float(a.size())
	return kov / maxf(_streuung(a) * _streuung(b), 0.0001)
