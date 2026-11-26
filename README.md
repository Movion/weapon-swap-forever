# Weapon Swap Forever

Addon für World of Warcraft: Forever 1.60.1 (Interface 16001). Es erkennt neu angelegte Waffen und pflegt auf Wunsch die WoW-Charaktermakros. Es nutzt Blizzard-Dialoge, das Makrofenster und die normale Aktionsleiste. Das Addon reagiert auf Ausrüstungsereignisse und kommt ohne Bibliotheken oder laufende Hintergrundabfragen aus.

## Installation

Entpacke `WeaponSwapForever-1.1.1.zip` in `World of Warcraft\_forever_\Interface\AddOns`. Danach muss dort `WeaponSwapForever\WeaponSwapForever.toc` liegen. Starte WoW neu und prüfe im AddOn-Menü, ob **Weapon Swap Forever** aktiv ist. Nach einem Update von 1.0.0 führe einmal außerhalb des Kampfes `/wsf sync` aus, um die vorhandenen Makros zu aktualisieren.

## Neue Ausrüstung übernehmen

Wenn du eine bisher ungespeicherte Waffe in der Haupthand anlegst, fragt ein Blizzard-Dialog, ob das Addon deine Makros dafür aktualisieren soll. Beim Schurken schlägt das Addon für einen Dolch die Dolchmakros vor und für andere Waffen die normale Hauptwaffe. Wenn du als Krieger eine neue Einhandwaffe mit angelegtem Schild ausrüstest, kannst du **Offense** oder **Defense** wählen. Bei **Defense** übernimmt das Addon den angelegten Schild mit. Einen neu angelegten Schild kannst du auch einzeln übernehmen.

Beim Wechsel zwischen gespeicherten Waffen erscheint keine Abfrage. Bei einem Wechsel im Kampf erscheint sie danach, wenn der neue Gegenstand noch angelegt ist. Mit **Abbrechen** behältst du deine bisherigen Makros. Die Chatbefehle bleiben für die manuelle Auswahl verfügbar.

## Waffe pro Fähigkeit einstellen

Öffne das Menü mit `/wsf` oder über **Menü** in der Ausrüstungsabfrage. Lege die gewünschte Waffe in der Haupthand an und klicke bei der Fähigkeit auf **Waffe setzen**. So kannst du etwa Hinterhalt und Meucheln unterschiedliche Dolche zuweisen. Änderungen an der gemeinsamen Standardwaffe greifen bei Makros, die den Standard verwenden. Mit **Standard** kehrst du zur gespeicherten Standardwaffe zurück.

Ziehe das Fenster mit der linken Maustaste an der Titelleiste. Die Scrollleiste erscheint, wenn die Liste länger als der sichtbare Bereich ist.

Für eine weitere erlernte aktive Fähigkeit gib unten ihren Namen oder ihre Zauber-ID ein und klicke mit angelegter Waffe auf **Hinzufügen**. **Makro** nimmt das jeweilige Makro an den Cursor, damit du es auf einen freien Platz der Aktionsleiste legen kannst. Du kannst es auch wie gewohnt aus `/macro` ziehen.

## Schurke

1. Lege deine normale Waffe (z. B. Hauklinge) in der Haupthand an und bestätige die Abfrage oder gib `/wsf main` ein.
2. Lege deinen Dolch in der Haupthand an und bestätige die Abfrage oder gib `/wsf dagger` ein.
3. Öffne `/macro` und ziehe **WSF Finster**, **WSF Hinterhalt**, **WSF Meucheln** und bei Bedarf **WSF Hauptwaffe** vom Tab mit den Charaktermakros in deine Aktionsleiste. Die Plätze und Tastenbelegungen wählst du selbst.

**WSF Finster** wechselt zur normalen Hauptwaffe und versucht erst Riposte, dann Finsterer Stoß. **WSF Hinterhalt** und **WSF Meucheln** legen den Dolch an und versuchen die jeweilige Fähigkeit. Hat der Wechsel die globale Abklingzeit ausgelöst, löse das Makro danach erneut aus. **WSF Hauptwaffe** rüstet die normale Hauptwaffe aus.

Ein neuer Dolch aktualisiert nach der Bestätigung beide Dolchmakros. Eine neue Hauptwaffe aktualisiert **WSF Finster** und **WSF Hauptwaffe**. Wenn du einen Dolch als normale Hauptwaffe verwenden willst, speichere ihn mit `/wsf main`.

## Krieger

1. Lege deine Offensivwaffe an und gib `/wsf offense` ein.
2. Lege deine Defensivwaffe samt Schild an und gib `/wsf defense` ein.
3. Ziehe **WSF Offense** und **WSF Defense** aus den Charaktermakros in die Aktionsleiste.

**WSF Offense** versucht Kampfhaltung und rüstet die Offensivwaffe in Slot 16 aus. Bei einem Einhänder kann der Schild angelegt bleiben. **WSF Defense** versucht Verteidigungshaltung und legt Defensivwaffe und Schild in Slot 16 und 17 an. Blockiert ein laufender Cooldown den Wechsel, drücke die Taste nach Ablauf erneut. Mit `/wsf shield` kannst du auch nur einen neuen Schild übernehmen.

## Makros verwalten

- Erfasse Ausrüstung außerhalb des Kampfes. `/wsf status` zeigt die gespeicherten Waffen deines Charakters und `/wsf sync` aktualisiert oder erstellt die Makros erneut.
- Lass die Namen der erzeugten Makros stehen, damit das Addon sie beim nächsten Waffenwechsel wiederfindet. Es erkennt sie am Kommentar `# WeaponSwapForever` und ersetzt beim Aktualisieren den Makrotext. Ist derselbe Name schon durch ein eigenes Charaktermakro belegt, benenne dieses Makro um und führe `/wsf sync` aus.
- Lass beide Waffen bei dir. Die Makros wählen per Gegenstands-ID und unterscheiden keine zwei Exemplare mit derselben ID.

## Weitere Möglichkeiten

- Mit getrennten Waffenwechsel- und Fähigkeitstasten kannst du den Wechsel vorziehen und siehst leichter, wann du die Fähigkeit auslösen kannst.
- Für den Krieger kommen auch der Blizzard-Ausrüstungsmanager und `/equipset` infrage, sofern der Ausrüstungsmanager im Client verfügbar ist. Speichere dafür Sets mit den Waffenslots und ignoriere die übrige Ausrüstung.
