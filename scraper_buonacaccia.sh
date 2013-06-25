#!/bin/bash
#
# Scraper CSV BuonaCaccia
# URL: https://buonacaccia.net
# tested version 3.3
#


# Load BC_PASSWORD e BC_PASSWORD
source ~/.buonacaccia

CookieFileName="$tempdir/cookies.txt"
url="$urlbase/Account/Login.aspx?ReturnUrl=%2fUtenti%2f"
url_report="$urlbase/utenti/EventReports.aspx"

mkdir "$tempdir"

if [[ -z "$BC_PASSWORD" ]] || [[ -z "$BC_PASSWORD" ]]
then
  echo "You must set BC_USERNAME e BC_PASSWORD"
  exit 1
fi

curl --cookie $CookieFileName --cookie-jar $CookieFileName --write-out %{http_code} --output $tempdir/loginForm.html $url $debug > $tempdir/code.txt

status=$(cat $tempdir/code.txt)
if [ "200" != "$status" ]
then
		echo "RESPONSE KO LOGIN FORM - $status"
        exit 2
fi

eventValidation=$(cat $tempdir/loginForm.html | grep EVENTVALIDATION | awk -F"=" '{print $5;}' | awk -F'"' '{print $2;}')
viewState=$(cat $tempdir/loginForm.html | grep __VIEWSTATE | awk -F"=" '{print $5;}' | awk -F'"' '{print $2;}')

eventValidationEncoded=$(php -r "echo urlencode(\"$eventValidation\");")
viewStateEncoded=$(php -r "echo urlencode(\"$viewState\");")

curl -H "Origin: $urlbase" -H 'Host: buonacaccia.net' -H 'Content-Type: application/x-www-form-urlencoded' -H "Referer: $urlbase/Account/Login.aspx?ReturnUrl=%2fUtenti%2f" --data "__EVENTTARGET=&__EVENTARGUMENT=&__VIEWSTATE=$viewStateEncoded&__SCROLLPOSITIONX=0&__SCROLLPOSITIONY=0&__EVENTVALIDATION=$eventValidationEncoded&ctl00%24MainContent%24LoginUser%24UserName=$BC_USERNAME&ctl00%24MainContent%24LoginUser%24Password=$BC_PASSWORD&ctl00%24MainContent%24LoginUser%24RememberMe=on&ctl00%24MainContent%24LoginUser%24LoginButton=Accedi" --cookie $CookieFileName --cookie-jar $CookieFileName --write-out %{http_code} --output $tempdir/logged.html $url $debug > $tempdir/code.txt

status=$(cat $tempdir/code.txt)
if [ "302" != "$status" ]
then
		echo "RESPONSE KO CREATE SESSION - $status"
        exit 2
fi

curl  -H 'Host: buonacaccia.net' -H "Referer: $urlbase/utenti/" --cookie $CookieFileName --cookie-jar $CookieFileName --write-out %{http_code} --output $tempdir/elenco.html $url_report $debug > $tempdir/code.txt 

status=$(cat $tempdir/code.txt)
if [ "200" != "$status" ]
then
		echo "RESPONSE KO READ EVENT LIST - $status"
        exit 2
fi

cat $tempdir/elenco.html | grep option | grep "|" | awk -F"\"" '{print $2;}' > $tempdir/elenco.txt

eventValidation=$(cat $tempdir/elenco.html | grep EVENTVALIDATION | awk -F"=" '{print $5;}' | awk -F'"' '{print $2;}')
viewState=$(cat $tempdir/elenco.html | grep __VIEWSTATE | awk -F"=" '{print $5;}' | awk -F'"' '{print $2;}')

eventValidationEncoded=$(php -r "echo urlencode(\"$eventValidation\");")
viewStateEncoded=$(php -r "echo urlencode(\"$viewState\");")

ELENCO="$(cat $tempdir/elenco.txt)";
for i in $ELENCO
do

	if [ ! -f data$i.csv ]; then
    
		data="'ctl00%24MainContent%24ddlReport=7&ctl00%24MainContent%24ddlEvent=$i&ctl00%24MainContent%24btGenerate=Genera&ctl00%24MainContent%24theReportViewer%24ctl03%24ctl00=&ctl00%24MainContent%24theReportViewer%24ctl03%24ctl01=&ctl00%24MainContent%24theReportViewer%24ctl10=ltr&ctl00%24MainContent%24theReportViewer%24ctl11=standards&ctl00%24MainContent%24theReportViewer%24AsyncWait%24HiddenCancelField=False&ctl00%24MainContent%24theReportViewer%24ToggleParam%24store=&ctl00%24MainContent%24theReportViewer%24ToggleParam%24collapse=false&ctl00%24MainContent%24theReportViewer%24ctl05%24ctl00%24CurrentPage=1&ctl00%24MainContent%24theReportViewer%24ctl05%24ctl03%24ctl00=&ctl00%24MainContent%24theReportViewer%24ctl08%24ClientClickedId=&ctl00%24MainContent%24theReportViewer%24ctl07%24store=&ctl00%24MainContent%24theReportViewer%24ctl07%24collapse=false&ctl00%24MainContent%24theReportViewer%24ctl09%24VisibilityState%24ctl00=ReportPage&ctl00%24MainContent%24theReportViewer%24ctl09%24ScrollPosition=&ctl00%24MainContent%24theReportViewer%24ctl09%24ReportControl%24ctl02=&ctl00%24MainContent%24theReportViewer%24ctl09%24ReportControl%24ctl03=&ctl00%24MainContent%24theReportViewer%24ctl09%24ReportControl%24ctl04=100"
		data2="$data&__EVENTTARGET=&__EVENTARGUMENT=&__SCROLLPOSITIONX=0&__SCROLLPOSITIONY=0"
		data3="$data2&__VIEWSTATE=$viewStateEncoded&__EVENTVALIDATION=$eventValidationEncoded"
		
		curl -H "Origin: $urlbase" -H 'Host: buonacaccia.net' -H 'Content-Type: application/x-www-form-urlencoded' -H "Referer: $urlbase/utenti/EventReports.aspx" --data "$data3" --cookie $CookieFileName --cookie-jar $CookieFileName --write-out %{http_code} --output /dev/null $url_report $debug > $tempdir/code.txt   

		status=$(cat $tempdir/code.txt)
		if [ "302" != "$status" ]
		then
				echo "RESPONSE KO READ DATA FASE 1 - $status"
		        exit 2
		fi

		url_evento="$urlbase/utenti/ExportCSV.ashx?t=EVT&e=$i"

		curl -H 'Host: buonacaccia.net' -H "Referer: $urlbase/utenti/EventReports.aspx" --cookie $CookieFileName --cookie-jar $CookieFileName --write-out %{http_code} --output $tempdir/dati$i.csv $url_evento $debug > $tempdir/code.txt
		status=$(cat $tempdir/code.txt)
		if [ "200" != "$status" ]
		then
				echo "RESPONSE KO READ DATA FASE 2 - $status"
		        exit 2
		fi

		cat $tempdir/dati$i.csv | dos2unix > data$i.csv

		sleep 3

	fi

done

curl -H "Origin: $urlbase" -H 'Host: buonacaccia.net' -H 'Content-Type: application/x-www-form-urlencoded' -H "Referer: $urlbase/utenti/EventReports.aspx" --data "__EVENTTARGET=ctl00%24HeadLoginView%24HeadLoginStatus%24ctl00&__EVENTARGUMENT=&__VIEWSTATE=$viewStateEncoded&__SCROLLPOSITIONX=0&__SCROLLPOSITIONY=0&__EVENTVALIDATION=$eventValidationEncoded&ctl00%24MainContent%24ddlReport=0&ctl00%24MainContent%24ddlEvent=0" --cookie $CookieFileName --cookie-jar $CookieFileName --write-out %{http_code} --output /dev/null $url_report $debug > $tempdir/code.txt 
status=$(cat $tempdir/code.txt)
if [ "200" != "$status" ]
then
		echo "RESPONSE KO LOGOUT - $status"
        exit 2
fi

rm -rf "$tempdir"
