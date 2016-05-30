#!/bin/sh

#-----------------------------------------------------------
# Variables
#-----------------------------------------------------------

#RHEV_LIST_DC1BAU="bothkvm01 bothkvm04 washkvm01 washkvm02 washkvm03 washkvm04 washkvm05 washkvm06"
RHEV_LIST_DC1BAU="
10.110.199.150
#10.110.201.20
#10.110.201.21
10.110.199.146
#10.110.199.241
#10.110.199.180
#10.110.199.181
#10.110.199.182
10.110.199.183
10.110.199.184
#10.110.199.185
#10.110.199.248
#10.110.199.249
"

BIN_DIR=/usr/users/treacyl/bin/rhev
OUT_DIR=/usr/users/treacyl/reports/rhev
MAIL_BODY=${OUT_DIR}/rhevh_check_body.html
VM_LIST=${OUT_DIR}/rhevh_vm_list.txt
ssh_opts="-qn -o StrictHostKeyChecking=no -o ConnectTimeout=5"
MailSubject="RHEV-H Status Monitoring (DC1ADMIN)"
DISTRO_LIST="lewis_treacy@slc.co.uk,veera_akula@slc.co.uk,ian_hall@slc.co.uk,bob_thompson@slc.co.uk"

#-----------------------------------------------------------
# Create mail header
#-----------------------------------------------------------

echo "" > $MAIL_BODY
#cat ${BIN_DIR}/rhevh_header_html.txt > $MAIL_BODY

func_create_html_table () 
{
        awk 'BEGIN {print "<table border=\"2\" cellpadding=\"6\" cellspacing=\"0\">"}
                   {print "<tr>";for(i=1;i<=NF;i++)print "<td style=font-size:11.0pt;color:#595959;line-height:115%;font-family:"Verdana","sans-serif";>" $i"</td>";print "</tr>"}
                   END {print "</table>"
                   }'
}

#-----------------------------------------------------------
# Get RHEV-H Host Stats 
#-----------------------------------------------------------

echo "<p>RHEV-H: Host System Activity </p> <br>" >> $MAIL_BODY

for rhevh_ip in $(echo "$RHEV_LIST_DC1BAU" | egrep -v '^#')
 do
   echo -n $(getent hosts $rhevh_ip | awk '{print $3}') " " 
   ### Host Stats -------------------------------------
   ssh $ssh_opts $rhevh_ip -qn vdsClient -s localhost getVdsStats | egrep 'cpuIdle|cpuLoad|memFree|swap|vmActive|vmCount|vmMigrating' | egrep -v ':' | awk '{print $3}' | 
     while read line
      do
        echo -n $line " " 
      done
   echo ""
 done | sort | awk 'BEGIN {print "HOST CPU_Idle CPU_Load Mem_Free Swap_Free Swap_Total vmActive vmCount vmMigrating"}
                           {print $0
                          }' | func_create_html_table >> $MAIL_BODY

echo "<br>" >> $MAIL_BODY

#-----------------------------------------------------------
# Preserve previous state/list of VMs per host 
#-----------------------------------------------------------

# Backup up previous VM list and look for changes
[[ -f $VM_LIST ]] && mv $VM_LIST ${VM_LIST}.previous

#-----------------------------------------------------------
# List VMs per RHEV-H Host
#-----------------------------------------------------------

for rhevh_ip in $(echo "$RHEV_LIST_DC1BAU" | egrep -v '^#')
 do
   ### VM List ----------------------------------------
   ssh $ssh_opts $rhevh_ip -qn vdsClient -s localhost list table | 
     while read line
      do
        echo -n "$(getent hosts $rhevh_ip | awk '{print $3}')" " " 
        echo $line | awk '{print $3, $4}' 
      done
 done | sort | awk 'BEGIN {print "HOST VM_Name State"}
                           {print $0
                          }' > $VM_LIST 

#-----------------------------------------------------------
# Detect any differences in the list of VMs per host 
#-----------------------------------------------------------

#echo "<p> VM RHEV-H Changes Detected: </p> <br>" >> $MAIL_BODY

echo "<td style=font-size:11.0pt;color:#595959;font-family:"Verdana","sans-serif";> <p> VM RHEV-H Changes Detected: </p> </td>" >> $MAIL_BODY

diff --side-by-side --suppress-common-lines ${VM_LIST}.previous $VM_LIST > ${VM_LIST}.diff

[[ -s ${VM_LIST}.diff ]] && MailSubject="RHEV VM Migrations Detected" 

if [[ -s ${VM_LIST}.diff ]]; then
   cat ${VM_LIST}.diff
else
   echo "None"
fi | func_create_html_table >> $MAIL_BODY 

echo "<p>RHEV-H: List of VMs </p> <br>"  >> $MAIL_BODY
 
cat $VM_LIST | func_create_html_table >> $MAIL_BODY

#-----------------------------------------------------------
# Send email report
#-----------------------------------------------------------

#cat ${BIN_DIR}/rhevh_footer_html.txt >> $MAIL_BODY

cat "$MAIL_BODY" |
 mail -s "$(echo -e "$MailSubject \nContent-Type: text/html")" $DISTRO_LIST -- -f DCV_Project@slc.co.uk -F "DCV Project"

exit
