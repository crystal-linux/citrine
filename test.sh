var=$(ls /usr/share/zoneinfo/ | sed 's/ /" "" "/g')
var=$(echo $var | sed 's/ /" "" "/g')
var=$(echo \"$var\")
loc1=$(dialog --title "Citrine" --menu "Please pick a time zone" 20 100 43 $var "" --stdout)
loc1=$(echo $loc1 | sed 's/"//g')
var1=$(ls /usr/share/zoneinfo/$loc1 | sed 's/ /" "" "/g')
var1=$(echo $var1 | sed 's/ /" "" "/g')
var1=$(echo \"$var1\")
loc2=$(dialog --title "Citrine" --menu "Please pick a time zone" 20 100 43 $var1 "" --stdout)
loc2=$(echo $loc2 | sed 's/"//g')
TZ="/usr/share/zoneinfo/$loc1/$loc2"
echo $TZ