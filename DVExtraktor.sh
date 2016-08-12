#!/bin/bash


##  Script liest eine DV Datensicherung von RDX ein und
##  entpackt die enthaltenen Daten.
##
##  Die entpackten Daten ersetzen die aktuellen Home
##  Verzeichnisse, wobei eine Sicherheitskopie erstellt wird.
##
##  Als root ausfuehren!
##
##  SPnG (FW), Stand August 2016


#####################################################################
## Bitte anpassen:

## Devicebezeichnung des RDX Mediums:
RDX="/dev/sdb"

## Ende der Anpassungen
#####################################################################




















function_exit()
{
	echo ""
    	echo "ABBRUCH! Fehler in Schritt $FAIL )-:"
	echo "Kein Medium oder Fehler beim Entpacken."
    	echo ""
	echo ""
	exit 1
}


if [ ! "`id -u`" = "0" ]; then
   echo ""
   echo " ABBRUCH, Rootrechte erforderlich!"
   echo ""
   exit 1
fi


FAIL=""
INFO="/root/00_Speedpoint_00"
mkdir -m 777 $INFO


clear
echo ""
echo "*********************************************************"
echo "Script extrahiert eine DV Datensicherung von $RDX"
echo "und stellt DV Daten im Ordner pat_nr zur Konvertierung"
echo "bereit. Dabei werden bestehende Home Verzeichnisse inkl."
echo "david verschoben."
echo ""
echo "Eventuelle Inhalte aus /home/00_Archiv werden GELOESCHT!!"
echo ""
echo "Bitte in der VM das RDX Laufwerk einhaengen!"
echo ""
echo "Bitte sicherstellen, dass ausreichend Plattenplatz"
echo "vorhanden ist!"
echo ""
echo "Bitte vorsichtshalber den Schreibschutz am RDX Medium"
echo "aktivieren!"
echo "*********************************************************"
echo ""
echo -n "Weiter mit ENTER Taste oder Abbruch mit STRG-C "
read dummy
echo ""


## Festplattenbelegung ermitteln:
WERT=`df -h /home | fgrep /dev | awk '{print $5}' | sed 's/.$//'`
if [ $WERT -gt 75 ]; then
	echo "Achtung! Die Home Partition ist zu $WERT Prozent belegt."
	echo ""
	echo "Um dennoch fortzufahren, ENTER druecken, ansonsten"
	echo "Abbruch mit STRG-C... "
#	echo ""
	read dummy
fi


echo "Schritt 1: RDX auslesen:"
if [ `ls -a /install/migration | wc -l` -gt 2 ]; then
	echo "ABBRUCH: Das Verzeichnis /install/migration ist nicht leer."
	echo "         Bitte die dort befindlichen Daten aus Platzgruenden"
	echo "         entfernen, bevor dieses Script nochmals gestartet"
	echo "         wird."
	echo ""
	exit 1
fi
echo "Bitte warten, bis das Medium ausgeworfen wurde... "
FAIL=1
cd /install/migration
tar xvf $RDX 2>/dev/null || function_exit
echo ""
eject $RDX
echo ""


echo "Schritt 2: Daten entschluesseln:"
FAIL=2
cd mnt/snapshots
echo david >/tmp/mcfile
echo "mcrypt laeuft... "
mcrypt -d -f /tmp/mcfile daily.0.tar.nc || function_exit
echo "OK."
echo ""
rm -f daily.0.tar.nc


echo "Schritt 3: Daten entpacken:"
echo "tar laeuft... "
FAIL=3
tar xvf daily.0.tar >/dev/null 2>&1 || function_exit
echo "OK."
echo ""


echo "Schritt 4: Grosse Dateien finden:"
echo "Suche laeuft..."
cd mnt/snapshots/daily.0/localhost 
find . -type f -exec ls -s {} \; | sort -n -r | head -20 >$INFO/Dateiliste.txt
echo "Liste erstellt, bitte anschliessend pruefen!"
echo ""


echo "Schritt 5: Home Verzeichnisse austauschen:"
service isamd stop
[  -d /home/00_Archiv ] && rm -rf /home/00_Archiv 
mkdir -m 777 /home/00_Archiv
mv /home/david /home/00_Archiv && echo "Archivieren der vorhandenen Home Verzeichnisse..."
mv /home/platz* /home/00_Archiv && echo "...erledigt."
cp -rpf home/david /home && echo "david Home wurde einkopiert."		#################### ToDo: rsync
cp -rpf home/platz* /home && echo "User Homes wurden einkopiert."	#################### ToDo: rsync
echo ""


echo "Schritt 6: Informationen sammeln:"
cp etc/cups/printers.conf $INFO/Printer.txt && echo "Druckerinfo gesichert."
cp etc/hosts $INFO/Hosts.txt && echo "Hosts Datei gesichert."
#cd /install/migration rm -rf *
echo ""


echo "Schritt 7: DV Datenbanken und Texte bereitlegen:"
cp -pf /home/david/david?.isa /home/david/trpword/pat_nr && echo "DBs wurden kopiert."
cp -pf /home/david/*.txd /home/david/trpword/pat_nr && echo "Texte wurden kopiert."
cp -pf /home/david/*.con /home/david/trpword/pat_nr && echo "con Datei(en) wurde(n) kopiert."
service isamd start
echo ""


echo "Schritt 8: Verstreute Dokumente ausserhalb david suchen:"
find /home -type l -name Word -delete
find /home -type l -name 'Praxisd*' -delete >/dev/null 2>&1
AUSGABE="$INFO/Dokumentenliste.txt"
echo „Ausserhalb /home/david gefundene Dokumente:“ >$AUSGABE
echo "Suche laeuft..."
> $AUSGABE
maxcount=`ls /home | fgrep platz | sed 's/platz//g' | sort | tail -n1`
for ((i=1; i<=maxcount;i++)); do
    x=$i
    # Platznamen unter 10 mit einer 0 ergaenzen (5 wird 05)
    [ $i -lt 10 ] && x="0$x"
    # alle mit platz beginnenden Homeverzeichnisse ohne versteckte Ordner oder Dateien durchsuchen
    find /home/platz$x -type f -name "*" | grep -v "/\." | egrep '\.(doc|pdf|odt|swx|xls|odx|tif|jpeg|jpg|gif|txt)$' >>$AUSGABE
done
echo "Liste versteuter Dokumente wurde erstellt."
echo ""


echo "Ende."
rm -f daily.0.tar
mv $INFO /home/david/trpword
chmod -R 777 /home/david/trpword/00_Speedpoint_00
chown -R david:david /home/david/trpword/00_Speedpoint_00
echo ""
echo "#########################################################################"
echo ""
echo "Bitte noch"
echo "  - nicht benoetigte grosse Dateien (-> s. Liste) loeschen!"
echo "  - die Homeverzeichnisse manuell nach Texten, etc. durchsuchen!"
echo ""
echo "-------------------------------------------------------------------------"
echo ""
echo "Bitte das Verzeichnis /install/migration leeren, sobald diese Daten nicht"
echo "mehr benoetigt werden!"
echo ""
echo "#########################################################################"
echo ""
echo "Bitte weitere Informationen in trpword/00_Speedpoint_00 beachten!"

exit 0
