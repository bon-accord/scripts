#!/bin/sh
 
#######################################################################################
#
# Script to run different LDAP queries
#
#######################################################################################
 
#Syntax
#------
#ldapsearch -b basedn -s scope [  optional_options ] "(attribute=filter)" [  optional_list_of_attributes ]
 
# Search filter examples
#-----------------------
#"(objectClass=*)"                                                              All objects.
#"(&(objectCategory=person)(objectClass=user)(!(cn=andy)))"                     All user objects but "andy".
#"(sn=sm*)"                                                                     All objects with a surname that starts with "sm".
#"(&(objectCategory=person)(objectClass=contact)(|(sn=Smith)(sn=Johnson)))"     All contacts with a surname equal to "Smith" or "Johnson".
# (&(givenName=John)(l=Dallas))                                                 Logical AND: find all entries with first name John and live in Dallas
 
#--------------------------------------------------------------------------------------
# Variables
#--------------------------------------------------------------------------------------
 
LDAP_BASEDN="dc=example,dc=com"
LDAP_SERVERS="ldap://dc01.example.com/,ldap://dc02.example.com/"
LDAP_OPTS_1="-N -LLL -Q"
LDAP_COMMAND="ldapsearch -H $LDAP_SERVERS -Y GSSAPI $LDAP_OPTS_1"
 
#--------------------------------------------------------------------------------------
# Usage text
#--------------------------------------------------------------------------------------
 
func_usage ()
{
echo "Usage: $(basename $0) [-a] [-s surname]"
echo "      -a,--all        = return everything"
echo "      -c,--computers  = compute report"
echo "      -s,--surname    = search by surname"
echo "      -u,--users      = user report"
exit 3
}
 
if [[ $# = 0 ]]; then
   func_usage
fi
 
#--------------------------------------------------------------------------------------
# Process command-line options
#--------------------------------------------------------------------------------------
 
while getopts 'acs:u' option
do
   case $option in
     'a'|"--everything" ) RETURN_EVERYTHING=Yes ;;
     'c'|"--computers"  ) COMPUTER_REPORT=Yes ;;
     's'|"--surname"    ) SURNAME="$OPTARG" ;;
     'u'|"--users"      ) USER_REPORT=Yes ;;
     \?|h|*             ) func_usage ;;
   esac
done
shift $(($OPTIND -1))
 
#--------------------------------------------------------------------------------------
# Return everything
#--------------------------------------------------------------------------------------
 
[[ $RETURN_EVERYTHING = "Yes" ]] && $LDAP_COMMAND -b "dc=example,dc=com" "objectClass=*"
 
#--------------------------------------------------------------------------------------
# Report: computers
#--------------------------------------------------------------------------------------
 
if [[ $COMPUTER_REPORT = "Yes" ]]; then
   BASE="cn=computers,dc=example,dc=com"
   ATTRIBUTE_LIST="cn name whenCreated whenChanged lastLogon logonCount operatingSystem dNSHostName lastLogonTimestamp"
   #echo "cn;name;dNSHostName;operatingSystem;whenCreated;whenChanged;logonCount;lastLogon;lastLogonTimestamp"
   echo "CommonName;FQDN;OS;WhenCreated;WhenChanged;LogonCount;LastLogon;LastLogonTimestamp"
   $LDAP_COMMAND -b "$BASE" $ATTRIBUTE_LIST |
    while read line
     do
       Attribute=$(echo $line | awk -F':' '{print $1}')
       if [[ -n $Attribute ]]; then
          [[ $Attribute = "cn" ]] &&                 cn_n=$(echo $line | awk -F':' '{print $2}')
          #[[ $Attribute = "name" ]] &&               name=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "dNSHostName" ]] &&        dnsh=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "operatingSystem" ]] &&    osty=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "whenCreated" ]] &&        whcr=$(echo $line | awk -F':' '{print substr($2,1,5)"-"substr($2,6,2)"-"substr($2,8,2)}')
          [[ $Attribute = "whenChanged" ]] &&        whch=$(echo $line | awk -F':' '{print substr($2,1,5)"-"substr($2,6,2)"-"substr($2,8,2)}')
          [[ $Attribute = "logonCount" ]] &&         logc=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "lastLogon" ]] &&          logl=$(echo $line | awk -F':' '{printf("%.0f", $2/10000000-11644473600)}') # no. 100-nanosec intervals since 01 Jan 1601
          [[ $Attribute = "lastLogonTimestamp" ]] && logt=$(echo $line | awk -F':' '{printf("%.0f", $2/10000000-11644473600)}') # no. 100-nanosec intervals since 01 Jan 1601
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
          [[ -n $logl ]] && echo -n "$(eval date -d \'1601-01-01 $logl sec GMT\')"";" || echo -n ";"  # try: echo -n date -d "1601-01-01 $logc sec GMT"
          [[ -n $logt ]] && echo -n "$(eval date -d \'1601-01-01 $logt sec GMT\')"";" || echo -n ";"
          echo ""
       # Unset all variables before processing a new record
          unset cn_n name dnsh osty whcr whch logc logl logt
       fi
     done
fi | grep -v ^Computers # Filter out the record for the OU itself
 
#--------------------------------------------------------------------------------------
# Return info by surname
#--------------------------------------------------------------------------------------
 
[[ -n $SURNAME ]] && $LDAP_COMMAND -b "$LDAP_BASEDN" -s sub "sn=${SURNAME}" cn sn memberOf | grep -v refldap
 
#--------------------------------------------------------------------------------------
# Report: users
#--------------------------------------------------------------------------------------
 
if [[ $USER_REPORT = "Yes" ]]; then
   BASE="dc=example,dc=com"
   #ATTRIBUTE_LIST="cn name whenCreated whenChanged lastLogon logonCount operatingSystem dNSHostName lastLogonTimestamp"
   ATTRIBUTE_LIST="dn cn sn givenName whenCreated whenChanged memberOf badPwdCount badPasswordTime lastLogon pwdLastSet accountExpires logonCount"
   echo "DistingName;CommonName;Surname;GivenName;WhenCreated;WhenChanged;badPwdCount;badPasswordTime;lastLogon;pwdLastSet;accountExpires;logonCount;MemberOf"
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
          [[ $Attribute = "badPasswordTime" ]] &&    bpwt=$(echo $line | awk -F':' '{printf("%.0f", $2/10000000-11644473600)}')
          [[ $Attribute = "lastLogon" ]] &&          lasl=$(echo $line | awk -F':' '{printf("%.0f", $2/10000000-11644473600)}')
          [[ $Attribute = "pwdLastSet" ]] &&         pwdl=$(echo $line | awk -F':' '{printf("%.0f", $2/10000000-11644473600)}')
          [[ $Attribute = "accountExpires" ]] &&     acce=$(echo $line | awk -F':' '{print $2}')
          [[ $Attribute = "logonCount" ]] &&         logc=$(echo $line | awk -F':' '{print $2}')
       # If line is blank, assume end of record and print all data on one line
       elif [[ -z $Attribute ]]; then
          [[ -n $dn_n ]] && echo -n $dn_n";" || echo -n ";"
          [[ -n $cn_n ]] && echo -n $cn_n";" || echo -n ";"
          [[ -n $sn_n ]] && echo -n $sn_n";" || echo -n ";"
          [[ -n $givN ]] && echo -n $givN";" || echo -n ";"
          [[ -n $whcr ]] && echo -n $whcr";" || echo -n ";"
          [[ -n $whch ]] && echo -n $whch";" || echo -n ";"
          [[ -n $bpwc ]] && echo -n $bpwc";" || echo -n ";"
          [[ -n $bpwt ]] && echo -n "$(eval date -d \'1601-01-01 $bpwt sec GMT\' | awk '{print $1, $2, $3, $4}')"";" || echo -n ";"
          #[[ -n $bpwt ]] && echo -n $bpwt";" || echo -n ";"
          [[ -n $lasl ]] && echo -n "$(eval date -d \'1601-01-01 $lasl sec GMT\' | awk '{print $1, $2, $3, $4}')"";" || echo -n ";"
          #[[ -n $lasl ]] && echo -n $lasl";" || echo -n ";"
          [[ -n $pwdl ]] && echo -n "$(eval date -d \'1601-01-01 $pwdl sec GMT\' | awk '{print $1, $2, $3, $4}')"";" || echo -n ";"
          [[ -n $acce ]] && echo -n $acce";" | awk '{gsub("9223372036854775807","Never"); printf $0}' || echo -n ";"
          [[ -n $logc ]] && echo -n $logc";" || echo -n ";"
          [[ -n $memb ]] && echo -n $memb";" || echo -n ";"
          echo ""
       # Unset all variables before processing a new record
          unset dn_n cn_n sn_n givN whcr whch memb bpwc bpwt lasl pwdl acce logc
       fi
     done
fi
 
exit
 
# END
