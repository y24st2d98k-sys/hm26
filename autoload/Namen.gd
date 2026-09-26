extends Node
## Namen — prozedurale Namensgebung fuer die gesamte Spielwelt.
##
## Grundsatz: nichts wird aus einer kurzen Festliste gezogen. Personennamen entstehen
## aus getrennten Vor- und Nachnamenspools, Nachnamen zusaetzlich aus Stamm+Endung,
## Ortsnamen aus Praefix+Suffix, Firmen aus Praefix+Branche+Rechtsform. Dadurch
## liegen die Kombinationszahlen pro Kultur im vier- bis fuenfstelligen Bereich.

var rng := RandomNumberGenerator.new()

# Kulturen, aus denen Spieler stammen koennen. Gewicht = relative Haeufigkeit.
const KULTUREN := ["de", "dk", "fr", "es", "pl", "se", "no", "is", "hr", "hu", "rs", "pt",
	"eg", "br", "si", "at", "nl", "mk", "cz", "ch"]

const KULTUR_NAME := {
	"de": "Deutschland", "dk": "Dänemark", "fr": "Frankreich", "es": "Spanien",
	"pl": "Polen", "se": "Schweden", "no": "Norwegen", "is": "Island",
	"hr": "Kroatien", "hu": "Ungarn", "rs": "Serbien", "pt": "Portugal",
	"eg": "Ägypten", "br": "Brasilien", "si": "Slowenien", "mk": "Nordmazedonien",
	"at": "Österreich", "ch": "Schweiz", "nl": "Niederlande", "be": "Belgien",
	"it": "Italien", "fo": "Färöer", "ba": "Bosnien-Herzegowina", "me": "Montenegro",
	"lv": "Lettland", "by": "Belarus", "ro": "Rumänien", "cz": "Tschechien",
	"sk": "Slowakei", "ua": "Ukraine", "tn": "Tunesien", "qa": "Katar",
	"jp": "Japan", "kr": "Südkorea", "gr": "Griechenland", "fi": "Finnland",
	# Nur fuer benannte echte Spieler. Fuer diese Kulturen gibt es keinen
	# Namenspool, also wird auch niemand mit ihnen erzeugt — sie stehen in
	# KULTUR_NAME und in der Flaggentabelle, aber nicht in KULTUREN.
	"cu": "Kuba", "lt": "Litauen", "dz": "Algerien",
	"tr": "Türkei", "il": "Israel",
	"ru": "Russland",
	"ar": "Argentinien",
	"ge": "Georgien",
	"xk": "Kosovo",
	"ir": "Iran",
	"ma": "Marokko",
	"ng": "Nigeria",
	"co": "Kolumbien",
	"md": "Moldau",
	"cl": "Chile",
	"us": "USA",
	"ee": "Estland",
	"cv": "Kap Verde",
	"ao": "Angola",
	"sn": "Senegal",
	"kz": "Kasachstan",
	"bh": "Bahrain",
	"lu": "Luxemburg",
	"bg": "Bulgarien",
	"uy": "Uruguay",
	"ve": "Venezuela",
	"cm": "Kamerun",
	"ci": "Elfenbeinküste",
	"gn": "Guinea",
	"cd": "DR Kongo",
	"cg": "Kongo",
	"sa": "Saudi-Arabien",
	"kw": "Kuwait",
	"al": "Albanien",
	"am": "Armenien",
	"az": "Aserbaidschan",
	"cy": "Zypern",
	"mx": "Mexiko",
	"ca": "Kanada",
	"au": "Australien",
	"gb": "Großbritannien",
}

const KULTUR_KUERZEL := {
	"de": "GER", "dk": "DEN", "fr": "FRA", "es": "ESP", "pl": "POL", "se": "SWE",
	"no": "NOR", "is": "ISL", "hr": "CRO", "hu": "HUN", "rs": "SRB", "pt": "POR",
	"eg": "EGY", "br": "BRA", "si": "SLO", "mk": "MKD",
	"at": "AUT", "ch": "SUI", "nl": "NED", "be": "BEL", "it": "ITA", "fo": "FRO",
	"ba": "BIH", "me": "MNE", "lv": "LAT", "by": "BLR", "ro": "ROU", "cz": "CZE",
	"sk": "SVK", "ua": "UKR", "tn": "TUN", "qa": "QAT", "jp": "JPN", "kr": "KOR",
	"gr": "GRE", "fi": "FIN", "cu": "CUB", "lt": "LTU", "dz": "ALG",
	"tr": "TUR", "il": "ISR",
	"ru": "RUS",
	"ar": "ARG",
	"ge": "GEO",
	"xk": "KOS",
	"ir": "IRI",
	"ma": "MAR",
	"ng": "NGR",
	"co": "COL",
	"md": "MDA",
	"cl": "CHI",
	"us": "USA",
	"ee": "EST",
	"cv": "CPV",
	"ao": "ANG",
	"sn": "SEN",
	"kz": "KAZ",
	"bh": "BRN",
	"lu": "LUX",
	"bg": "BUL",
	"uy": "URU",
	"ve": "VEN",
	"cm": "CMR",
	"ci": "CIV",
	"gn": "GUI",
	"cd": "COD",
	"cg": "CGO",
	"sa": "KSA",
	"kw": "KUW",
	"al": "ALB",
	"am": "ARM",
	"az": "AZE",
	"cy": "CYP",
	"mx": "MEX",
	"ca": "CAN",
	"au": "AUS",
	"gb": "GBR",
}

# ------------------------------------------------------------- Vornamen ---
const VORNAMEN := {
	"de": ["Jonas", "Lennart", "Til", "Fabian", "Marvin", "Kai", "Tobias", "Sören", "Niklas", "Hendrik",
		"Moritz", "Julius", "Sebastian", "Florian", "Maximilian", "Ole", "Jannik", "Malte", "Philipp", "Rune",
		"Bastian", "Timo", "Lasse", "Carl", "Erik", "Marius", "Nico", "Simon", "Dennis", "Frederik",
		"Johann", "Benedikt", "Arne", "Hauke", "Silas", "Vincent", "Leopold", "Emil"],
	"dk": ["Mikkel", "Rasmus", "Lasse", "Niklas", "Magnus", "Anders", "Jesper", "Kasper", "Emil", "Søren",
		"Frederik", "Mathias", "Morten", "Nikolaj", "Simon", "Jeppe", "Oliver", "Villads", "Bjarke", "Thor",
		"Asger", "Esben", "Kristian", "Valdemar", "Holger", "Troels", "Gustav", "Sander"],
	"fr": ["Hugo", "Nicolas", "Théo", "Kentin", "Ludovic", "Valentin", "Romain", "Baptiste", "Rémi", "Yann",
		"Clément", "Maxime", "Antoine", "Adrien", "Guillaume", "Mathieu", "Loïc", "Cédric", "Julien", "Corentin",
		"Enzo", "Timothée", "Bastien", "Aurélien", "Sylvain", "Gaël", "Nolan", "Melvyn"],
	"es": ["Álvaro", "Iker", "Sergio", "Rubén", "Adrián", "Jorge", "Aleix", "Ferran", "Gonzalo", "Diego",
		"Ander", "Unai", "Iñaki", "Rodrigo", "Pablo", "Marc", "Joan", "Raúl", "Javier", "Aitor",
		"Nicolás", "Bruno", "Héctor", "Xabi", "Ismael", "Cristian", "Dani", "Eloy"],
	"pl": ["Kamil", "Michał", "Bartosz", "Przemysław", "Arkadiusz", "Piotr", "Jakub", "Mateusz", "Szymon", "Tomasz",
		"Damian", "Rafał", "Maciej", "Krzysztof", "Adrian", "Wojciech", "Łukasz", "Paweł", "Dawid", "Filip",
		"Grzegorz", "Marcin", "Sebastian", "Igor", "Oskar", "Norbert", "Kacper", "Radosław"],
	"se": ["Oscar", "Albin", "Hampus", "Jim", "Felix", "Linus", "Viktor", "Jonathan", "Anton", "Måns",
		"Elias", "Axel", "Melker", "Tobias", "Lukas", "Gustav", "Isak", "Alfred", "Sixten", "Valter",
		"Ludvig", "Rasmus", "Nils", "Hugo", "Simon", "Adam", "Emil", "Theodor"],
	"no": ["Sander", "Kristian", "Magnus", "Harald", "Eivind", "Torbjørn", "Sindre", "Kjetil", "Vetle", "Håkon",
		"Ole", "Even", "Jonas", "Andreas", "Sondre", "Bjørn", "Erlend", "Aksel", "Trygve", "Halvard",
		"Sigurd", "Tarjei", "Mads", "Jørgen", "Leif", "Ivar", "Audun", "Fredrik"],
	"is": ["Aron", "Björgvin", "Guðjón", "Ómar", "Sigurbergur", "Arnór", "Elvar", "Haukur", "Viggó", "Teitur",
		"Gísli", "Ólafur", "Stefán", "Kári", "Bjarki", "Einar", "Rúnar", "Sveinn", "Þórir", "Hlynur",
		"Jökull", "Baldur", "Dagur", "Hafþór", "Ísak", "Magnús", "Snorri", "Ragnar"],
	"hr": ["Ivan", "Domagoj", "Luka", "Marko", "Zlatko", "Manuel", "Igor", "Josip", "Filip", "Tin",
		"Mateo", "Ante", "Nikola", "Petar", "Bruno", "Stipe", "Vlado", "Karlo", "Dario", "Toni",
		"Mario", "Jakov", "Borna", "Šime", "Leon", "Dominik", "Andrija", "Roko"],
	"hu": ["Bence", "Zsolt", "Ádám", "Gábor", "Máté", "Richárd", "Attila", "Dávid", "Péter", "Balázs",
		"Roland", "Tamás", "Krisztián", "Levente", "Botond", "Áron", "Dénes", "Gergő", "Norbert", "Szabolcs",
		"Zoltán", "István", "Miklós", "Csaba", "Kristóf", "Bálint", "Ferenc", "Olivér"],
	"rs": ["Nemanja", "Vanja", "Dragan", "Petar", "Stefan", "Miloš", "Bogdan", "Lazar", "Uroš", "Aleksa",
		"Nikola", "Dušan", "Ognjen", "Vukašin", "Mihajlo", "Strahinja", "Đorđe", "Filip", "Marko", "Relja",
		"Andrija", "Ilija", "Zoran", "Vladan", "Nenad", "Slobodan", "Branko", "Veljko"],
	"pt": ["Rui", "Tiago", "Diogo", "Gonçalo", "Pedro", "Miguel", "André", "Fábio", "Nuno", "Luís",
		"Ricardo", "Vasco", "Salvador", "Duarte", "Bernardo", "Hugo", "Martim", "Afonso", "Rodrigo", "Tomás",
		"Simão", "Eduardo", "Filipe", "Gustavo", "Dinis", "Leandro", "Marco", "Ivo"],
	"eg": ["Ahmed", "Mohamed", "Yehia", "Karim", "Omar", "Hassan", "Mostafa", "Seif", "Ali", "Ibrahim",
		"Youssef", "Khaled", "Tarek", "Mahmoud", "Amr", "Hussein", "Sherif", "Zeyad", "Marwan", "Adham",
		"Nour", "Fares", "Bassem", "Hazem", "Rami", "Salah", "Wael", "Ziad"],
	"si": ["Jure", "Blaž", "Domen", "Nejc", "Matic", "Miha", "Aleks", "Dean", "Borut", "Gašper",
		"Klemen", "Luka", "Rok", "Tilen", "Žiga", "Jan", "Aleš", "Primož", "Sebastjan", "Vid",
		"Anže", "Urban", "Nik", "Tim", "Marko", "Dejan", "Grega", "Matevž"],
	"at": ["Nikola", "Lukas", "Robert", "Sebastian", "Thomas", "Boris", "Tobias", "Fabian",
		"Constantin", "Ivan", "Maximilian", "Alexander", "Vincent", "Jakob", "Moritz", "Julian",
		"Bernhard", "Josef", "Georg", "Markus", "Christoph", "Daniel", "Sandro", "Nico",
		"Felix", "Elias", "Raul", "Lorenz"],
	"nl": ["Kay", "Luc", "Dani", "Ivo", "Bobby", "Jasper", "Rutger", "Samir", "Robin", "Bart",
		"Jorn", "Sven", "Thijs", "Ruben", "Niels", "Daan", "Lars", "Stijn", "Jeroen", "Wouter",
		"Tim", "Koen", "Bram", "Joris", "Sem", "Teun", "Guus", "Mees"],
	"mk": ["Dejan", "Filip", "Stojanče", "Kiril", "Martin", "Nikola", "Borko", "Marko", "Igor",
		"Vlatko", "Zlatko", "Aleksandar", "Goce", "Vančo", "Dragan", "Petar", "Damjan", "Stefan",
		"Ilija", "Bojan", "Trajče", "Naumče", "Risto", "Blagoja", "Mile", "Vasil", "Gjorgji", "Simeon"],
	"cz": ["Ondřej", "Tomáš", "Jan", "Lukáš", "Martin", "Stanislav", "Roman", "Vojtěch", "Matěj",
		"Jakub", "Petr", "Michal", "Filip", "David", "Daniel", "Adam", "Marek", "Pavel", "Radek",
		"Zdeněk", "Jiří", "Václav", "Milan", "Karel", "Josef", "Dominik", "Šimon", "Vít"],
	"ch": ["Nikola", "Andy", "Manuel", "Lenny", "Samuel", "Lucas", "Cédric", "Luca", "Noam",
		"Jonas", "Dimitrij", "Nicolas", "Yves", "Marvin", "Fabian", "Joel", "Simon", "Livio",
		"Aurel", "Roman", "Silvan", "Nino", "Timo", "Elia", "Sven", "Lars", "Janis", "Robin"],
	"br": ["Thiago", "Rogério", "Haniel", "Leonardo", "Gustavo", "Felipe", "Rangel", "Vinícius", "Matheus", "José",
		"Lucas", "Rafael", "Bruno", "Caio", "Everton", "Murilo", "Diego", "Igor", "Wesley", "Danilo",
		"Alan", "Pedro", "Otávio", "Yuri", "Kaique", "Vitor", "Renan", "Douglas"],
}

# ---------------------------------- Nachnamen: Vollformen + Stamm/Endung ---
const NACH_VOLL := {
	"de": ["Wiencek", "Reichmann", "Gensheimer", "Kastening", "Pekeler", "Steinhauser", "Golla", "Drux",
		"Zerbe", "Heymann", "Semper", "Uscins", "Knorr", "Späth", "Michalczik", "Kohlbacher", "Hanne",
		"Kühn", "Obermaier", "Bergwald", "Linnemann", "Rathje", "Petersen", "Schöneberg"],
	"dk": ["Hansen", "Mensah", "Landin", "Gidsel", "Hald", "Toft", "Saugstrup", "Kirkeløkke", "Holm",
		"Møllgaard", "Lauge", "Green", "Overby", "Kjær", "Skovgaard", "Rahbek", "Bjerre", "Damgaard"],
	"fr": ["Karabatic", "Dipanda", "Fabregas", "Descat", "Nahi", "Remili", "Porte", "Tournat", "Lenne",
		"Gérard", "Briet", "Mahé", "Sorhaindo", "Bouquet", "Lagarde", "Rivoal", "Vaillant", "Dumoulin"],
	"es": ["Entrerríos", "Aguinagalde", "Solé", "Cañellas", "Ariño", "Maqueda", "Figueras", "Dujshebaev",
		"Serdio", "Balaguer", "Gurbindo", "Rivera", "Casado", "Guardiola", "Ferrer", "Molina", "Olalla"],
	"pl": ["Jachlewski", "Lijewski", "Bielecki", "Krajewski", "Daszek", "Syprzak", "Gębala", "Chrapkowski",
		"Kornecki", "Moryto", "Olejniczak", "Rutkowski", "Ziemniak", "Wiśniewski", "Szmal", "Paczkowski"],
	"se": ["Ekberg", "Gottfridsson", "Wanne", "Pellas", "Karlsson", "Nilsson", "Andersson", "Lindberg",
		"Palicka", "Sandell", "Stenbäcken", "Möller", "Tollbring", "Zachrisson", "Bergendahl", "Hallgren"],
	"no": ["Sagosen", "Gullerud", "Bergerud", "Tønnesen", "Barthold", "Reinkind", "Overby", "Myrhol",
		"Hagen", "Johannessen", "Solberg", "Kristiansen", "Aardahl", "Bjørnsen", "Haugseng", "Lislevand"],
	"is": ["Pálmarsson", "Gunnarsson", "Sigurðsson", "Guðmundsson", "Þórisson", "Magnússon", "Ólafsson",
		"Jóhannesson", "Sveinsson", "Einarsson", "Björnsson", "Hallgrímsson", "Arnarsson", "Hreiðarsson"],
	"hr": ["Duvnjak", "Karačić", "Musa", "Cindrić", "Mamić", "Šušnja", "Horvat", "Kovačević", "Marić",
		"Jelinić", "Glavaš", "Šarac", "Vuković", "Božić", "Klarica", "Novak", "Perić"],
	"hu": ["Nagy", "Lékai", "Bánhidi", "Szita", "Balogh", "Máthé", "Bodó", "Sipos", "Fazekas", "Tóth",
		"Ancsin", "Rosta", "Szabó", "Kovács", "Hornyák", "Gulyás", "Varga", "Pásztor"],
	"rs": ["Vujin", "Marjanac", "Radivojević", "Ilić", "Stanić", "Nenadić", "Kandić", "Milić", "Pešić",
		"Đukić", "Jovanović", "Petrović", "Marković", "Savić", "Todorović", "Nikolić"],
	"pt": ["Magalhães", "Costa", "Monteiro", "Areia", "Pereira", "Oliveira", "Salina", "Portela", "Ferreira",
		"Sousa", "Gomes", "Almeida", "Carvalho", "Fonseca", "Cardoso", "Moreira"],
	"eg": ["Elahmar", "Sanad", "Hesham", "Kadry", "Mamdouh", "Elderaa", "Abdallah", "Nasr", "Fouad",
		"Shebib", "Zein", "Bakr", "Rashad", "Gamal", "Mansour", "Hamdy"],
	"si": ["Dolenec", "Zarabec", "Bombač", "Janc", "Cehte", "Blagotinšek", "Makuc", "Verdinek",
		"Ferlin", "Mačkovšek", "Kodrin", "Marguč", "Novak", "Horvat", "Kovačič", "Zorman"],
	"at": ["Bilyk", "Wagner", "Weber", "Zeiner", "Hermann", "Frimmel", "Bauer", "Gruber",
		"Huber", "Steinberger", "Pichler", "Leitner", "Wolf", "Fuchs", "Mayer", "Berger"],
	"nl": ["Steins", "Smits", "Baijens", "Sluijters", "Versteijnen", "Jansen", "Bakker", "Visser",
		"de Vries", "Meijer", "Mulder", "Kuipers", "Hendriks", "van Dijk", "de Boer", "Willems"],
	"mk": ["Manaskov", "Lazarov", "Georgievski", "Kuzmanovski", "Mitrevski", "Markoski",
		"Dimitrioski", "Stoilov", "Angelov", "Petrovski", "Trajkovski", "Nikolovski",
		"Jovanovski", "Ristovski", "Spasov", "Talevski"],
	"cz": ["Kasal", "Zdráhala", "Šulc", "Solák", "Franc", "Mašek", "Novák", "Svoboda",
		"Dvořák", "Černý", "Procházka", "Kučera", "Veselý", "Horák", "Němec", "Beneš"],
	"ch": ["Portner", "Schmid", "Küng", "Tominec", "Zehnder", "Röthlisberger", "Delhees", "Jud",
		"Herburger", "Bär", "Wick", "Brunner", "Meier", "Keller", "Frei", "Ammann"],
	"br": ["Petrus", "Nascimento", "Silva", "Toledo", "Fonseca", "Chiuffa", "Pereira", "Gomes", "Santos",
		"Almeida", "Oliveira", "Barbosa", "Carvalho", "Moraes", "Ribeiro", "Teixeira"],
}

const NACH_STAMM := {
	"de": ["Berg", "Wald", "Stein", "Eich", "Falk", "Hoch", "Neu", "Sand", "Dorn", "Hart", "Frei", "Wolf",
		"Lind", "Moos", "Rain", "Hell", "Grün", "Kessel", "Kirsch", "Wein", "Feld", "Reut", "Rohr", "Schier",
		"Hag", "Born", "Zeis", "Krug", "Wend", "Tann", "Bruch", "Schell"],
	"dk": ["Ander", "Niel", "Jacob", "Chris", "Peder", "Lar", "Mad", "Poul", "Jør", "Sø", "Kri", "Ras",
		"Hen", "Mik", "Bir", "Ole", "Vil", "Ing"],
	"fr": ["Bou", "Cha", "Mar", "Le", "Du", "Des", "Font", "Rous", "Mon", "Lam", "Gir", "Bar", "Cour",
		"Pel", "Vin", "Ber", "Cast", "Thi"],
	"es": ["Al", "Mar", "Fer", "Gon", "Her", "Nav", "Cas", "Sal", "Ver", "Ara", "Bel", "Cam", "Pel",
		"Ort", "Rom", "Ser", "Val", "Zab"],
	"pl": ["Kowal", "Nowak", "Wojcie", "Kamiń", "Lewan", "Zieliń", "Szymań", "Woźni", "Dąbrow", "Koz",
		"Jankow", "Mazur", "Krawczy", "Piotrow", "Grabow", "Pawłow", "Michal", "Adamcz"],
	"se": ["Berg", "Lund", "Ceder", "Söder", "Nord", "Alm", "Ek", "Sand", "Sjö", "Ström", "Hall", "Ryd",
		"Björk", "Lind", "Ax", "Gran", "Fors", "Ving"],
	"no": ["Berg", "Haug", "Dal", "Fjell", "Nord", "Sol", "Vik", "Lund", "Strand", "Aas", "Myr", "Hol",
		"Grøn", "Løv", "Skog", "Bakke", "Rand", "Elv"],
	"is": ["Guðmund", "Sigurð", "Jóhann", "Ólaf", "Magnús", "Björn", "Einar", "Þór", "Arn", "Hall",
		"Svein", "Krist", "Bald", "Ragnar", "Hauk", "Stef"],
	"hr": ["Kov", "Bab", "Mar", "Jur", "Vuk", "Rad", "Pav", "Mil", "Tom", "Bož", "Bar", "Kral",
		"Lov", "Šim", "Grg", "Ant"],
	"hu": ["Kis", "Fe", "Hor", "Bar", "Var", "Mol", "Nem", "Tak", "Far", "Ju", "Lak", "Sim",
		"Ora", "Ben", "Vör", "Szil"],
	"rs": ["Jovan", "Petr", "Nikol", "Mark", "Đor", "Stefan", "Lazar", "Milo", "Vuk", "Rad", "Tod",
		"Sav", "Ilj", "Kost", "Stan", "Boj"],
	"pt": ["Ma", "Cor", "Ri", "Bar", "Fon", "Pin", "Ca", "Ro", "Bra", "Men", "Vas", "Tei",
		"Lou", "Fer", "Serr", "Mat"],
	"eg": ["El-Aš", "Abd", "Sha", "Ham", "Far", "Sal", "Nag", "Bad", "Kam", "Raf", "Sad", "Gha",
		"Sob", "Zak", "Has", "Man"],
	"si": ["Kov", "Nov", "Hor", "Zup", "Pot", "Kral", "Vid", "Bev", "Rup", "Jer",
		"Kos", "Meh", "Žun", "Šti", "Pav", "Tur"],
	"at": ["Gru", "Hu", "Wag", "Bau", "Pich", "Leit", "Stein", "Moos", "Ass", "Ram",
		"Ober", "Unter", "Hoch", "Nieder", "Kai", "Zill"],
	"nl": ["Bak", "Vis", "Mei", "Mul", "Kui", "Hen", "Ver", "Sme", "Bos", "Dek",
		"Ros", "Bru", "Haa", "Kra", "Ste", "Wij"],
	"mk": ["Man", "Laz", "Georg", "Kuzman", "Mitr", "Mark", "Dimitri", "Stoil",
		"Angel", "Petr", "Trajk", "Nikol", "Jovan", "Rist", "Spas", "Tal"],
	"cz": ["Nov", "Svo", "Dvo", "Čern", "Proch", "Kuč", "Vesel", "Hor", "Něm",
		"Pos", "Krej", "Hrub", "Bene", "Fia", "Sed", "Mar"],
	"ch": ["Schm", "Mei", "Kel", "Bru", "Frei", "Zür", "Bär", "Amm", "Stu", "Wid",
		"Hug", "Sut", "Gys", "Räb", "Zim", "Blat"],
	"br": ["Ol", "Sou", "Fer", "Alm", "Car", "Rod", "Gonç", "Bar", "Mar", "Cost", "Rib", "Az",
		"Vas", "Cam", "Mel", "Ram"],
}

const NACH_ENDUNG := {
	"de": ["mann", "bach", "berg", "stein", "hoff", "meier", "schmidt", "hauser", "brand", "feldt", "koop", "wald"],
	"dk": ["sen", "gaard", "holm", "lund", "strup", "bæk", "skov", "toft", "vig", "berg"],
	"fr": ["rand", "tier", "vier", "gnon", "beau", "let", "mont", "din", "sac", "vet", "rel", "quet"],
	"es": ["varez", "tínez", "nández", "zález", "rrero", "rrete", "tillo", "cedo", "dejo", "guer", "bano", "mero"],
	"pl": ["ski", "czyk", "wicz", "ewski", "owski", "iński", "arek", "ecki"],
	"se": ["ström", "kvist", "berg", "lund", "gren", "dahl", "sson", "mark", "wall", "borg"],
	"no": ["stad", "nes", "vik", "heim", "rud", "sen", "berg", "haug", "eide", "moen"],
	"is": ["sson", "berg", "dal", "fjörð", "holt", "vík"],
	"hr": ["ić", "ović", "ević", "ac", "ak", "ar", "in"],
	"hu": ["s", "ss", "váth", "ács", "esi", "ári", "édi", "ényi"],
	"rs": ["ović", "ević", "ić", "in", "ski", "ac"],
	"pt": ["gães", "reia", "beiro", "veira", "cedo", "landa", "sela", "tinho"],
	"eg": ["mar", "rahim", "loul", "mady", "zeed", "bir", "seem", "waan"],
	"br": ["iveira", "za", "reira", "eida", "valho", "rigues", "alves", "bosa"],
	"si": ["ač", "ič", "nik", "šek", "ovc", "ar", "ej", "ovič"],
	"at": ["ber", "ner", "bauer", "mayr", "egger", "hofer", "gruber", "sperger"],
	"nl": ["sen", "ker", "straten", "mans", "veld", "huis", "dijk", "kamp"],
	"mk": ["ov", "ovski", "evski", "oski", "evi", "ievski", "eski", "ovi"],
	"cz": ["ák", "ada", "oda", "řák", "ný", "ázka", "era", "lý"],
	"ch": ["id", "er", "mann", "egger", "iker", "matter", "wyler", "hofer"],
}

# ------------------------------------------------------------- Ortsnamen ---
const ORT_PRE := {
	"de": ["Nord", "Süd", "Alten", "Neuen", "Ober", "Unter", "Wald", "Berg", "Rhein", "Sand", "Königs",
		"Bischofs", "Hohen", "Klein", "Groß", "Eichen", "Falken", "Rosen", "Mühl", "Eller", "Linden", "Weiden"],
	"dk": ["Aal", "Hors", "Ring", "Es", "Skan", "Vejle", "Kold", "Nykø", "Hjør", "Thi", "Fre", "Sil",
		"Holste", "Ran", "Vi", "Ny"],
	"fr": ["Ville", "Saint-", "Château", "Beau", "Mont", "Fontaine", "Roche", "Pont", "Bois", "Val",
		"Neuvy", "Clair", "Aigue", "Puy", "Cour", "Bourg"],
	"es": ["Villa", "San ", "Puerto", "Alto", "Castro", "Monte", "Torre", "Vega", "Peña", "Río",
		"Valle", "Fuente", "Alcal", "Cabo", "Nava", "Sierra"],
	"pl": ["Nowa ", "Stary ", "Biało", "Zielona ", "Jasno", "Wielko", "Ostro", "Sosno", "Wodzi", "Kamien",
		"Brzo", "Dąbro", "Grodz", "Rado", "Lubli", "Toru"],
}
const ORT_SUF := {
	"de": ["haven", "burg", "feld", "bach", "dorf", "stedt", "heim", "au", "brück", "tal", "see",
		"ried", "münde", "horst", "wangen", "rode", "hausen", "walde"],
	"dk": ["borg", "sens", "købing", "bjerg", "strup", "havn", "lund", "holm", "gård", "næs", "vig", "by"],
	"fr": ["neuve", "mont", "rieux", "sur-Loir", "lieu", "bourg", "ville", "sac", "gnac", "vrey", "court", "chard"],
	"es": ["nueva", "real", "mayor", "verde", "rrubio", "lada", "mar", "blanca", "sol", "cedo", "seca", "llana"],
	"pl": ["wice", "ków", "sław", "stok", "górze", "polska", "łęka", "wiec", "szyn", "mierz", "nica", "bork"],
}

# ------------------------------------------------------- Vereinsbausteine ---
const VEREIN_PRE := {
	"de": ["TSV", "TSG", "HSG", "SG", "HC", "HSV", "SV", "TV", "VfL", "MTV", "TuS", "SC", "HBC", "TSC", "SpVgg", "HF"],
	"dk": ["HK", "IK", "BK", "IF", "HF", "GF", "AK", "TMS", "KIF", "FH"],
	"fr": ["HBC", "US", "CA", "SC", "AS", "ES", "CSM", "SMV", "ASP", "OC"],
	"es": ["CB", "BM", "CD", "CH", "SD", "UD", "CBM", "AD", "CN", "RC"],
	"pl": ["KS", "MKS", "SPR", "GKS", "TS", "MMTS", "AZS", "OKS", "ZKS", "WKS"],
}

const VEREIN_BEINAME := ["Löwen", "Adler", "Wölfe", "Bären", "Falken", "Recken", "Hummeln", "Panther",
	"Eulen", "Störche", "Haie", "Drachen", "Nordlichter", "Eisvögel", "Bullen", "Kraniche", "Berserker",
	"Hanseaten", "Füchse", "Luchse", "Kormorane", "Wisente", "Möwen", "Dachse", "Auerhähne"]

# -------------------------------------------------------------- Sponsoren ---
const SPONSOR_PRE := ["Nord", "Vita", "Helio", "Kron", "Tera", "Aqua", "Ferro", "Lumin", "Orbis", "Novo",
	"Prima", "Ceres", "Delta", "Sila", "Arte", "Vento", "Kali", "Magna", "Solid", "Junct", "Rubin", "Zenit",
	"Aurel", "Basto", "Kobalt", "Elber", "Wester", "Osten"]
const SPONSOR_BRANCHE := ["bau", "tech", "log", "pharm", "bank", "energie", "assek", "medien", "werk",
	"stahl", "druck", "kraft", "netz", "form", "kost", "trans", "chem", "labor", "immo", "kredit", "reise", "wasser"]
const SPONSOR_FORM := ["AG", "GmbH", "SE", "& Co. KG", "Group", "Holding", "Werke", "Partner", "Systeme", "International"]

# ----------------------------------------------------------------- Medien ---
const MEDIUM_TYP := ["Kurier", "Anzeiger", "Rundschau", "Bote", "Post", "Depesche", "Blatt", "Report",
	"Tagblatt", "Zeitung", "Echo", "Wochenschau", "Spiegelbild", "Ticker", "Stimme", "Chronik"]
const MEDIUM_FACH := ["Hallenzeit", "Kreisläufer", "Siebenmeter", "Harzpott", "Tempogegenstoß", "Wurfarm",
	"Kabinenfunk", "Zeitspiel", "Sechs-Null", "Bankgeflüster", "Torhüterblick", "Anwurf", "Doppelpass",
	"Blockbau", "Hallenpuls", "Spielmacher"]

# -------------------------------------------------------- Social-Bausteine ---
const FAN_ADJ := ["ewiger", "treuer", "harter", "wilder", "stiller", "lauter", "grimmer", "goldener",
	"kalter", "roter", "blauer", "letzter", "erster", "echter", "freier", "zorniger", "nüchterner", "alter"]
const FAN_NOMEN := ["Block", "Fan", "Kurve", "Harz", "Anwurf", "Halle", "Bank", "Kreis", "Wurf", "Pfiff",
	"Tribüne", "Trommel", "Schal", "Kessel", "Gegenstoß", "Sitzplatz", "Nordkurve", "Zaunfahne"]

# ------------------------------------------------------- Persoenlichkeiten ---
const PERSOENLICHKEITEN := {
	"Ehrgeizig": {"ehrgeiz": 17, "loyalitaet": 9, "temperament": 11, "profitum": 13},
	"Loyal": {"ehrgeiz": 9, "loyalitaet": 18, "temperament": 8, "profitum": 13},
	"Leitwolf": {"ehrgeiz": 15, "loyalitaet": 14, "temperament": 13, "profitum": 16},
	"Mustergültig": {"ehrgeiz": 14, "loyalitaet": 14, "temperament": 6, "profitum": 19},
	"Hitzkopf": {"ehrgeiz": 13, "loyalitaet": 10, "temperament": 19, "profitum": 6},
	"Selbstzweifler": {"ehrgeiz": 8, "loyalitaet": 12, "temperament": 14, "profitum": 9},
	"Lockerer Typ": {"ehrgeiz": 8, "loyalitaet": 13, "temperament": 7, "profitum": 8},
	"Perfektionist": {"ehrgeiz": 16, "loyalitaet": 11, "temperament": 12, "profitum": 17},
	"Söldner": {"ehrgeiz": 16, "loyalitaet": 4, "temperament": 10, "profitum": 12},
	"Vereinsherz": {"ehrgeiz": 10, "loyalitaet": 19, "temperament": 9, "profitum": 14},
	"Rampensau": {"ehrgeiz": 15, "loyalitaet": 9, "temperament": 16, "profitum": 10},
	"Stiller Schaffer": {"ehrgeiz": 11, "loyalitaet": 15, "temperament": 5, "profitum": 16},
}

func _ready() -> void:
	rng.randomize()

func setze_saat(saat: int) -> void:
	rng.seed = saat

# ------------------------------------------------------------- Werkzeuge ---
func waehle(liste: Array) -> Variant:
	if liste.is_empty():
		return ""
	return liste[rng.randi_range(0, liste.size() - 1)]

func wuerfel(min_wert: int, max_wert: int) -> int:
	return rng.randi_range(min_wert, max_wert)

func zufall() -> float:
	return rng.randf()

func bereich(a: float, b: float) -> float:
	return rng.randf_range(a, b)

## Normalverteilter Wert, begrenzt auf [unten, oben].
func glocke(mitte: float, streuung: float, unten: float, oben: float) -> float:
	var w: float = mitte + rng.randfn(0.0, 1.0) * streuung
	return clampf(w, unten, oben)

# --------------------------------------------------------- Personennamen ---
func kultur_zufall(schwerpunkt: String = "", gewicht_schwerpunkt: float = 0.55) -> String:
	if schwerpunkt != "" and rng.randf() < gewicht_schwerpunkt:
		return schwerpunkt
	return waehle(KULTUREN)

func vorname(kultur: String) -> String:
	var pool: Array = VORNAMEN.get(kultur, VORNAMEN["de"])
	return str(waehle(pool))

func nachname(kultur: String) -> String:
	var k: String = kultur if NACH_VOLL.has(kultur) else "de"
	if rng.randf() < 0.42:
		return str(waehle(NACH_VOLL[k]))
	var stamm := str(waehle(NACH_STAMM[k]))
	var endung := str(waehle(NACH_ENDUNG[k]))
	return stamm + endung

func person(kultur: String) -> Dictionary:
	return {"vorname": vorname(kultur), "nachname": nachname(kultur), "nation": kultur}

# -------------------------------------------------------------- Ortsnamen ---
func ort(nation: String) -> String:
	var n: String = nation if ORT_PRE.has(nation) else "de"
	var a := str(waehle(ORT_PRE[n]))
	var b := str(waehle(ORT_SUF[n]))
	var ortsname := a + b
	# Bindestrich-Orte fuer zusaetzliche Vielfalt
	if rng.randf() < 0.12:
		ortsname += "-" + str(waehle(ORT_SUF[n])).capitalize()
	return ortsname

# ------------------------------------------------------------ Vereinsname ---
## Liefert {name, kurz, ort, beiname}
func verein(nation: String, vergeben: Dictionary) -> Dictionary:
	var n: String = nation if VEREIN_PRE.has(nation) else "de"
	for _versuch in range(60):
		var o := ort(n)
		var pre := str(waehle(VEREIN_PRE[n]))
		var voll := ""
		var beiname := ""
		var wurf := rng.randf()
		if wurf < 0.34:
			voll = "%s %s" % [pre, o]
		elif wurf < 0.52:
			voll = "%s %s %02d" % [pre, o, rng.randi_range(1, 99)]
		elif wurf < 0.70:
			beiname = str(waehle(VEREIN_BEINAME))
			voll = "%s %s" % [o, beiname]
		elif wurf < 0.86:
			beiname = str(waehle(VEREIN_BEINAME))
			voll = "%s %s %s" % [pre, o, beiname]
		else:
			voll = "%s %s-%s" % [pre, o, str(waehle(ORT_SUF[n])).capitalize()]
		if vergeben.has(voll):
			continue
		return {"name": voll, "kurz": kuerzel(voll), "ort": o, "beiname": beiname}
	return {"name": "HC %s %d" % [ort(n), rng.randi_range(100, 999)], "kurz": "HCX", "ort": ort(n), "beiname": ""}

## Drei-Buchstaben-Kuerzel aus einem Vereinsnamen.
func kuerzel(voll: String) -> String:
	var roh := voll.replace("-", " ")
	var teile := roh.split(" ", false)
	var buchstaben := ""
	for t in teile:
		var s := str(t)
		if s.length() == 0:
			continue
		if s.to_upper() == s and s.length() <= 4:
			buchstaben += s
		else:
			buchstaben += s.substr(0, 1).to_upper()
	buchstaben = buchstaben.replace(".", "")
	if buchstaben.length() >= 3:
		return buchstaben.substr(0, 3).to_upper()
	var rest := roh.replace(" ", "").to_upper()
	return (buchstaben + rest).substr(0, 3)

# -------------------------------------------------------------- Sponsoren ---
func sponsor() -> String:
	var firma := str(waehle(SPONSOR_PRE)) + str(waehle(SPONSOR_BRANCHE))
	if rng.randf() < 0.75:
		firma += " " + str(waehle(SPONSOR_FORM))
	return firma

# ----------------------------------------------------------------- Medien ---
func medium(nation: String) -> String:
	if rng.randf() < 0.42:
		return str(waehle(MEDIUM_FACH))
	return "%s %s" % [ort(nation), str(waehle(MEDIUM_TYP))]

func fan_handle() -> String:
	var stil := rng.randi_range(0, 2)
	match stil:
		0:
			return "@%s%s%d" % [str(waehle(FAN_ADJ)), str(waehle(FAN_NOMEN)).to_lower(), rng.randi_range(2, 99)]
		1:
			return "@%s_%s" % [str(waehle(FAN_NOMEN)).to_lower(), str(waehle(FAN_ADJ))]
		_:
			return "@%s%s" % [str(waehle(FAN_NOMEN)), rng.randi_range(1900, 2030)]

func medien_handle(name: String) -> String:
	return "@" + name.to_lower().replace(" ", "").replace(".", "").replace("ß", "ss").substr(0, 16)

func persoenlichkeit() -> String:
	var schluessel: Array = PERSOENLICHKEITEN.keys()
	return str(waehle(schluessel))
