# Netz gesperrt (Stand 2026-09-26)

Die Datenbeschaffung (echte Kader, Spielpläne, Statistiken, Logos 2026/27) konnte
nicht starten: Der Proxy dieser Cloud-Umgebung verweigert die Verbindung
(`CONNECT tunnel failed, response 403`, laut Proxy-Status „policy denial“).

| Host | Ergebnis |
|---|---|
| de.wikipedia.org | 403 (Proxy) |
| en.wikipedia.org | 403 (Proxy) |
| upload.wikimedia.org | 403 (Proxy) |
| www.handball-world.news | 403 (Proxy) |
| www.eurohandball.com | 403 (Proxy) |
| www.dhb.de | 403 (Proxy) |
| www.liquimoly-hbl.de | 403 (Proxy) |
| www.transfermarkt.de | 403 (Proxy) |
| pypi.org | 200 (erreichbar) |
| github.com | erreichbar |

Es wurden keine Daten erfunden; `daten/*.json` sind unverändert.

## Abhilfe
In den Einstellungen der Cloud-Umgebung (Umgebungsmenü in der Titelleiste der
Sitzung → Bearbeiten → Netzwerkzugriff) entweder eine breitere Zugriffsstufe
wählen oder die obigen Hosts zu den erlaubten Domains hinzufügen. Die Änderung
greift erst in einer **neuen** Sitzung (der Container übernimmt die Richtlinie
beim Start). Danach die Aufgabe erneut starten.
