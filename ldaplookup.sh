#!/bin/sh
 
#######################################################################################
#
# Script to run different LDAP queries
#
# Lewis Treacy, 30 April 2016
#
#######################################################################################
 
#--------------------------------------------------------------------------------------
# Variables (change as required for each site)
#--------------------------------------------------------------------------------------
 
LDAP_BASEDN="dc=example,dc=com"
LDAP_SERVERS="ldap://dc01.example.com/,ldap://dc02.example.com/"
LDAP_OPTS_1="-N -LLL -Q -E pr=1000/noprompt"
LDAP_COMMAND="ldapsearch -H $LDAP_SERVERS -Y GSSAPI $LDAP_OPTS_1"
 
#--------------------------------------------------------------------------------------
# Usage text
#--------------------------------------------------------------------------------------
 
func_usage ()
{
echo "Usage: $(basename $0) [-acduw] [-s surname] [-U user_string]"
echo "                     -a = return everything"
echo "                     -c = compute report"
echo "                     -d = disabled or locked users"
echo "                     -s = search by surname"
echo "                     -u = users report"
echo "                     -U = user string search"
echo "                     -w = workspace report"
exit 3
}
 
if [[ $# = 0 ]]; then
   func_usage
fi
 
#--------------------------------------------------------------------------------------
# Process command-line options
#--------------------------------------------------------------------------------------
 
while getopts 'acds:uU:w' option
do
   case $option in
        'a') RETURN_EVERYTHING=Yes ;;
        'c') COMPUTER_REPORT=Yes ;;
        'd') DISABLED_ACCOUNTS=Yes ;;
        's') SURNAME="$OPTARG" ;;
        'u') USER_REPORT=Yes ;;
        'U') USER_SEARCH_STRING="$OPTARG" ;;
        'w') WORKSPACE_REPORT=Yes ;;
     \?|h|*) func_usage ;;
   esac
done
shift $(($OPTIND -1))
 
#--------------------------------------------------------------------------------------
# Return everything
#--------------------------------------------------------------------------------------
 
[[ $RETURN_EVERYTHING = "Yes" ]] && $LDAP_COMMAND -b "dc=example,dc=com" "objectClass=*"
 
#--------------------------------------------------------------------------------------
# Return basic info for a given surname
#--------------------------------------------------------------------------------------
 
[[ -n $SURNAME ]] && $LDAP_COMMAND -b "$LDAP_BASEDN" -s sub "sn=${SURNAME}" cn sn memberOf | grep -v refldap
 
#--------------------------------------------------------------------------------------
# Return info by a user search string
#--------------------------------------------------------------------------------------
 
[[ -n $USER_SEARCH_STRING ]] && $LDAP_COMMAND -b "$LDAP_BASEDN" "(|(cn=${USER_SEARCH_STRING}*)(sn=${USER_SEARCH_STRING}*))"
 
#--------------------------------------------------------------------------------------
# List deleted & locked accounts
#--------------------------------------------------------------------------------------
 
[[ -n $DISABLED_ACCOUNTS ]] && $LDAP_COMMAND -b "$LDAP_BASEDN" "(&(objectClass=User)(userAccountControl:1.2.840.113556.1.4.803:=2))" cn | grep ^cn
 
#--------------------------------------------------------------------------------------
# Report: workspaces
#--------------------------------------------------------------------------------------
 
if [[ -n $WORKSPACE_REPORT ]]; then
   BASE="ou=Workspaces,dc=example,dc=com"
   ATTRIBUTE_LIST="cn gidNumber whenCreated whenChanged"
   echo "CommonName;GIDnumber;WhenCreated;WhenChanged"
   $LDAP_COMMAND -b $BASE "objectClass=*" $ATTRIBUTE_LIST |
    while read line
     do
       Attribute=$(echo $line | awk -F':' '{print $1}')
       if [[ -n $Attribute ]]; then
          [[ $Attribute = "cn" ]] &&                 cn_n=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "gidNumber" ]] &&          gidn=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "whenCreated" ]] &&        whcr=$(echo $line | awk -F':' '{print substr($2,1,5)"-"substr($2,6,2)"-"substr($2,8,2)}')
          [[ $Attribute = "whenChanged" ]] &&        whch=$(echo $line | awk -F':' '{print substr($2,1,5)"-"substr($2,6,2)"-"substr($2,8,2)}')
       elif [[ -z $Attribute ]]; then
          [[ -n $cn_n ]] && echo -n $cn_n";" || echo -n ";"
          [[ -n $gidn ]] && echo -n $gidn";" || echo -n ";"
          [[ -n $whcr ]] && echo -n $whcr";" || echo -n ";"
          [[ -n $whch ]] && echo -n $whch";" || echo -n ";"
       echo ""
       # Unset all variables before processing a new record
       unset cn_n gidn whcr whch
       fi
     done
fi
 
#--------------------------------------------------------------------------------------
# Report: computers
#--------------------------------------------------------------------------------------
 
if [[ $COMPUTER_REPORT = "Yes" ]]; then
   BASE="cn=computers,dc=example,dc=com"
   ATTRIBUTE_LIST="cn name whenCreated whenChanged lastLogon logonCount operatingSystem dNSHostName lastLogonTimestamp"
   echo "CommonName;FQDN;OS;WhenCreated;WhenChanged;LogonCount;LastLogon;LastLogonTimestamp"
   $LDAP_COMMAND -b "$BASE" $ATTRIBUTE_LIST |
    while read line
     do
       Attribute=$(echo $line | awk -F':' '{print $1}')
       if [[ -n $Attribute ]]; then
          [[ $Attribute = "cn" ]] &&                 cn_n=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "dNSHostName" ]] &&        dnsh=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "operatingSystem" ]] &&    osty=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "whenCreated" ]] &&        whcr=$(echo $line | awk -F':' '{print substr($2,1,5)"-"substr($2,6,2)"-"substr($2,8,2)}')
          [[ $Attribute = "whenChanged" ]] &&        whch=$(echo $line | awk -F':' '{print substr($2,1,5)"-"substr($2,6,2)"-"substr($2,8,2)}')
          [[ $Attribute = "logonCount" ]] &&         logc=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "lastLogon" ]] &&          logl=$(echo $line | awk -F':' '{print $2}')  # no. 100-nanosec intervals since 01 Jan 1601
          [[ $Attribute = "lastLogonTimestamp" ]] && logt=$(echo $line | awk -F':' '{print $2}')  # no. 100-nanosec intervals since 01 Jan 1601
       # If line is blank, assume end of record and print all data on one line
       elif [[ -z $Attribute ]]; then
          [[ -n $cn_n ]] && echo -n $cn_n";" || echo -n ";"
          #[[ -n $name ]] && echo -n $name";" || echo -n ";"
          [[ -n $dnsh ]] && echo -n $dnsh";" || echo -n ";"
          [[ -n $osty ]] && echo -n $osty";" || echo -n ";"
          [[ -n $whcr ]] && echo -n $whcr";" || echo -n ";"
          [[ -n $whch ]] && echo -n $whch";" || echo -n ";"
          [[ -n $logc ]] && echo -n $logc";" || echo -n ";"
#          [[ -n $logl ]] && echo -n $logl";" || echo -n ";"
#          [[ -n $logt ]] && echo -n $logt";" || echo -n ";"
          [[ -n $logl ]] && echo -n "$(eval date +'%Y%m%d-%H:%M' -d \'1970-01-01 $((($logl/10000000)-11644473600)) sec GMT\')"";" || echo -n ";"  # try: echo -n date -d "1601-01-01 $logc sec GMT"
          [[ -n $logt ]] && echo -n "$(eval date +'%Y%m%d-%H:%M' -d \'1970-01-01 $((($logt/10000000)-11644473600)) sec GMT\')"";" || echo -n ";"
          echo ""
       # Unset all variables before processing a new record
          unset cn_n name dnsh osty whcr whch logc logl logt
       fi
     done
fi | grep -v ^Computers # Filter out the record for the OU itself
 
#--------------------------------------------------------------------------------------
# Report: users
#--------------------------------------------------------------------------------------
 
if [[ $USER_REPORT = "Yes" ]]; then
   BASE="dc=example,dc=com"
   #ATTRIBUTE_LIST="cn name whenCreated whenChanged lastLogon logonCount operatingSystem dNSHostName lastLogonTimestamp"
   ATTRIBUTE_LIST="dn cn sn givenName whenCreated whenChanged memberOf badPwdCount badPasswordTime lastLogon pwdLastSet accountExpires logonCount"
   echo "CommonName;Surname;GivenName;DistingNameOU;WhenCreated;WhenChanged;badPwdCount;badPasswordTime;lastLogon;pwdLastSet;accountExpires;logonCount;MemberOf"
   #$LDAP_COMMAND -b "$BASE" $ATTRIBUTE_LIST |
   $LDAP_COMMAND -b "$BASE" "objectClass=user" $ATTRIBUTE_LIST |
    while read line
     do
       Attribute=$(echo $line | awk -F':' '{print $1}')
       if [[ -n $Attribute ]]; then
          [[ $Attribute = "dn" ]] &&                 dn_n=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "cn" ]] &&                 cn_n=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "sn" ]] &&                 sn_n=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "givenName" ]] &&          givN=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "whenCreated" ]] &&        whcr=$(echo $line | awk -F':' '{print substr($2,1,5)"-"substr($2,6,2)"-"substr($2,8,2)}')
          [[ $Attribute = "whenChanged" ]] &&        whch=$(echo $line | awk -F':' '{print substr($2,1,5)"-"substr($2,6,2)"-"substr($2,8,2)}')
          [[ $Attribute = "memberOf" ]] &&           memb=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "badPwdCount" ]] &&        bpwc=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "badPasswordTime" ]] &&    bpwt=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "lastLogon" ]] &&          lasl=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "pwdLastSet" ]] &&         pwdl=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "accountExpires" ]] &&     acce=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "logonCount" ]] &&         logc=$(echo $line | awk -F':' '{print $2}')
       # If line is blank, assume end of record and print all data on one line
       elif [[ -z $Attribute ]]; then
          [[ -n $cn_n ]] && echo -n $cn_n";" || echo -n ";"
          [[ -n $sn_n ]] && echo -n $sn_n";" || echo -n ";"
          [[ -n $givN ]] && echo -n $givN";" || echo -n ";"
          [[ -n $dn_n ]] && echo -n $(echo $dn_n | awk -F',' '{print $2}')";" || echo -n ";"
          [[ -n $whcr ]] && echo -n $whcr";" || echo -n ";"
          [[ -n $whch ]] && echo -n $whch";" || echo -n ";"
          [[ -n $bpwc ]] && echo -n $bpwc";" || echo -n ";"
          [[ -n $bpwt ]] && echo -n "$(eval date +'%Y%m%d-%H:%M' -d \'1970-01-01 $((($bpwt/10000000)-11644473600)) sec GMT\')"";" || echo -n ";"
          [[ -n $lasl ]] && echo -n "$(eval date +'%Y%m%d-%H:%M' -d \'1970-01-01 $((($lasl/10000000)-11644473600)) sec GMT\')"";" || echo -n ";"
          #[[ -n $lasl ]] && echo -n $lasl";" || echo -n ";"
          [[ -n $pwdl ]] && echo -n "$(eval date +'%Y%m%d-%H:%M' -d \'1970-01-01 $((($pwdl/10000000)-11644473600)) sec GMT\')"";" || echo -n ";"
          [[ -n $acce ]] && echo -n $acce";" | awk '{gsub("9223372036854775807","Never"); printf $0}' || echo -n ";"
          [[ -n $logc ]] && echo -n $logc";" || echo -n ";"
          [[ -n $memb ]] && echo -n $memb";" || echo -n ";"
          echo ""
       # Unset all variables before processing a new record
          unset cn_n sn_n givN dn_n whcr whch bpwc bpwt lasl pwdl acce logc memb
       fi
     done
fi
 
exit
 
# END
