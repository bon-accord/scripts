#!/bin/sh

# Process a file produced from the rhevm-shell using list vms --show-all

echo "Name;Description;OS Type;Memory GB;Creation Date;Status;Display IP;Guest IPs"

cat $1 |
  while read line
   do
     Attribute=$(echo $line | awk '{print $1}')
     if [[ $Attribute != "type" ]]; then
       [[ $Attribute = "name" ]] &&                    	 name=$(echo $line | awk '{printf("%s%s", $3, ";")}')
       [[ $Attribute = "description" ]] && 		 desc=$(echo $line | awk '{printf("%s", substr($0, index($0,$3))";")}')
       [[ $Attribute = "os-type" ]] && 			 os_t=$(echo $line | awk '{printf("%s%s", $3, ";")}' )
       [[ $Attribute = "memory" ]] && 			 memo=$(echo $line | awk '{printf("%.2f%s", $3/(1024^3), ";")}')
       [[ $Attribute = "creation_time" ]] && 		 born=$(echo $line | awk '{printf("%s%s", $3, ";")}')
       [[ $Attribute = "status" ]] && 			 stat=$(echo $line | awk '{printf("%s%s", $3, ";")}')
       [[ $Attribute = "display-address" ]] && 		 ip_d=$(echo $line | awk '{printf("%s%s", $3, ";")}')
       [[ $Attribute = "guest_info-ips-ip-address" ]] && ip_g=$(echo $line | awk '{printf("%s%s", $3, ";")}')
     # If we are at the last attribute for each VM, then print all the data
     elif [[  $Attribute = "type" ]]; then
       [[ -n $name ]] && echo -n $name || echo -n ";"
       [[ -n $desc ]] && echo -n $desc || echo -n ";"
       [[ -n $os_t ]] && echo -n $os_t || echo -n ";"
       [[ -n $memo ]] && echo -n $memo || echo -n ";"
       [[ -n $born ]] && echo -n $born || echo -n ";"
       [[ -n $stat ]] && echo -n $stat || echo -n ";"
       [[ -n $ip_d ]] && echo -n $ip_d || echo -n ";"
       [[ -n $ip_g ]] && echo -n $ip_g || echo -n ";"
       echo "" 
     # Unset the variables for the last VM before moving on to the next one
       unset name desc os_t memo born stat ip_d ip_g
     fi
   done
