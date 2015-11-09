#!/bin/sh

#############################################################
# Script:   hostreport.sh
# Project:  SLC Consolidation & Virtualisation
# Author:   Lewis Treacy, Oct. 2015
#############################################################

# Note: /bin/sh does not allow functions names with "-" (bash does) and causes 'not a valid identifier' error in the name but /bin/bash does.
#set -e                         # Exit immediately if a command exits with a non-zero status
set -u                         # Treat unset variables and parameters as an error when performing parameter expansion
#trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT    # send SIGTERM to whole process group, killing descendants

#-------------------------------------------------------------
# Process command-line options
#-------------------------------------------------------------

if [[ $# = 0 ]];then
   echo "Usage: $(basename $0) [-c] [-l]"
   echo "       -c = csv output for Excel"
   echo "       -l = long output"
   exit
fi

while getopts ':cl' option
 do
   case $option in
        'c')
            CSV_FORMAT=Yes; LNG_FORMAT=No ;;
        'l')
            LNG_FORMAT=Yes; CSV_FORMAT=No ;;
        \?|h|* )
            echo 'Usage: [-c] [-l]'
            exit 3
   esac
 done
shift $(($OPTIND -1))

#############################################################
# FUNCTIONS
#############################################################

func_for_loop ()               # Use for multi-line output (single column)
{
 let counter=0
 for i in $(func_list_${1})
  do
    let counter=${counter}+1
    Prefix=$(echo ${1} | tr "[:lower:]" "[:upper:]")
    if [[ $LNG_FORMAT = "Yes" ]]; then
       echo -n "${Prefix}="
       func_get_${1}
    elif [[ $CSV_FORMAT = "Yes" ]]; then
       func_get_${1}
    fi
  done | awk -v csv="$CSV_FORMAT" '{if(csv == "Yes"){printf $0} else print $0} END{if(csv == "Yes") {printf ";"}}'
}

func_whl_loop ()               # Use for multi-line output (complex, hard to quote)
{
 let counter=0
 func_list_${1} |
  while read line
   do
     let counter=${counter}+1
     Prefix=$(echo ${1} | tr "[:lower:]" "[:upper:]")
     if [[ $LNG_FORMAT = "Yes" ]]; then
        echo -n "${Prefix}="
        func_get_${1}
     elif [[ $CSV_FORMAT = "Yes" ]]; then
        func_get_${1}
     fi
   done | awk -v csv="$CSV_FORMAT" '{if(csv == "Yes"){printf $0} else print $0} END{if(csv == "Yes") {printf ";"}}'
}

func_std_comm ()               # Use for single commands with single-line output
{
 Prefix=$(echo ${1} | tr "[:lower:]" "[:upper:]")
 if [[ $LNG_FORMAT = "Yes" ]]; then
    echo -n "${Prefix}="
    func_get_${1}
 elif [[ $CSV_FORMAT = "Yes" ]]; then
    func_get_${1} | awk '{printf $0} END{printf ";"}'
 fi
}
#------------------------------------------------------------
# Formatting functions
#------------------------------------------------------------
func_trim_whtspace () { awk '{gsub(/^ +| +$/,"")} {print $0}' ; }
HEADER="HOSTNAME;FQDN;RHEL VER;KERNEL;vCPU COUNT;DISK TOTAL ALLOC, GB (df in 1000k blocks);DISK ACTUAL USAGE (df);DISK FREE SPACE, GB;PRODUCT;SERIAL;BIOS;ENC NAME;ENC MODEL;ENC SERIAL;SERVER BAY;BAYS FILLED;DISK USAGE;IPs;MACs;ROUTE;MEM TOTAL;CPUs;CORE COUNTs;BLK DEVs;LVM VGs (Size, Free);LVM LVs (Path, Size);MEM PEAK;MEM AVG;SWAP AVG;CPU AVG"
[[ $CSV_FORMAT = "Yes" ]] && echo "$HEADER"
#------------------------------------------------------------
# Manage exclusions
#------------------------------------------------------------
[[ -f /var/lock/lvm/* ]] && EXCLUDE="Yes" || EXCLUDE="No"                                     # Detect presence of LVM locks
[[ $(hostname) == ebs* || $(hostname) == ccow* || $(hostname) == imgow* ]] &&  EXCLUDE="Yes"  # Detect hosts with blkid hangs
[[ -n $(uname -r | egrep "2.4.21|2.6.9") ]] && RH4="Yes" || RH4="No"                          # Detect RHEL 3/4
[[ -z $(which sar 2>/dev/null) ]] && SAR_EXIST="No" || SAR_EXIST="Yes"
#------------------------------------------------------------
# SUMMARY
#------------------------------------------------------------
func_get_hostname ()  { hostname ; }  # a func on one line must end in a semi-colon with spaces inside the braces
func_get_fqdn ()      { hostname --short ; }
func_get_rhrel ()     { cat /etc/redhat-release ; }
func_get_kernel ()    { uname -r ; }
func_get_vcpucount () { cat /proc/cpuinfo | egrep 'processor' | wc -l ; }
# Disk usage
func_get_disk_total_alloc () {
                              df --block-size=1000 -P | grep -v Filesystem |
                               awk '{print $2}' |
                                awk '{Total+=$1} END {printf("%-4.1f%2s\n", Total/1000000, "GB")}'
                             }
func_get_disk_actual_use () {
                             for Disk in "$(df --block-size=1000 -P | grep -v Filesystem)"
                              do
                                echo "$Disk" | awk '{printf("%8.0f\n", $2-$4)}'
                              done | awk '{Total+=$1} END {printf("%-2.1f%2s\n", Total/1000000, "GB")}'
                            }
func_get_disk_actual_free () {
                              for Disk in "$(df --block-size=1000 -P | grep -v Filesystem)"
                               do
                                 echo "$Disk" | awk '{printf("%8.0f\n", $4)}'
                               done | awk '{Total+=$1} END {printf("%-2.1f%2s\n", Total/1000000, "GB")}'
                             }
#Hardware
func_get_product ()   { [[ ${RH4} == No ]] && dmidecode -s system-product-name || dmidecode | grep -i 'product name' | awk -F':' '{print $2}' | func_trim_whtspace ; }
func_get_serial ()    { [[ ${RH4} == No ]] && dmidecode -s system-serial-number || dmidecode | grep -iA2 'product name' | tail -n1 | awk -F':' '{print $2}' | func_trim_whtspace ; }
func_get_bios ()      { dmidecode | egrep 'SMBIOS|Release Date'  | awk '/SMBIOS/{printf "SMBIOS=" $2 "\n"} /Release/{printf "REL_DATE=" $3 "\n"}'; }
func_get_enc_name ()  { dmidecode | grep 'Enclosure Name' | awk -F':' '{print $2}' | func_trim_whtspace ; }
func_get_enc_model () { dmidecode | grep 'Enclosure Model' | awk -F':' '{print $2}' | func_trim_whtspace ; }
func_get_enc_serial () { dmidecode | grep 'Enclosure Serial' | awk -F':' '{print $2}' | func_trim_whtspace ; }
func_get_enc_server_bay () { dmidecode | grep 'Rack Name' | awk -F':' '{print $2}' | func_trim_whtspace ; }
func_get_enc_bays_filled () { dmidecode | grep 'Bays Filled' | awk -F':' '{print $2}' | func_trim_whtspace ; }
#------------------------------------------------------------
# DISK
#------------------------------------------------------------
func_list_disk () { echo ""$(df -HP | grep -v Filesystem | awk '{print $NF}')"" ; }
func_get_disk () { df -HP $i | grep -v Filesystem ; }
#------------------------------------------------------------
# NETWORK
#------------------------------------------------------------
func_list_ip () { echo "$(ip -o -s -f inet addr | grep -v 127.0.0.1)" ;}
func_get_ip () { echo "\"$line\"" | awk '{print $2 "-" $4}' ;}
func_list_mac () { echo "$(ip -o -s -f link addr | grep -v LOOPBACK)" ;}
func_get_mac () { echo "\"$line\"" | awk '{print $2 "-" $13}' ;}
#------------------------------------------------------------
# ROUTING
#------------------------------------------------------------
func_list_route () { echo "$(ip route)" ; }
func_get_route () { echo "\"$line\"" ; }
#------------------------------------------------------------
# MEMORY
#------------------------------------------------------------
func_get_memtotal () { echo "$(cat /proc/meminfo | grep ^MemTotal | awk '{print $2 $3}')" ; }
#------------------------------------------------------------
# CPU
#------------------------------------------------------------
func_list_cpu () { dmidecode | egrep 'Socket Designation' | grep 'Proc ' ; }
func_get_cpu () { cat /proc/cpuinfo | egrep -i 'model name' | head -1 | awk -F ':' '{print "\"" $2 "\""}' ; }

func_list_corecount () { dmidecode | egrep 'Socket Designation' | grep 'Proc ' ; }
func_get_corecount () { [[ -z ${RH4} ]] && dmidecode -t 4 | grep 'Core Count' | head -1 | awk '{print $3}' || echo "UNKNOWN" ; }
#------------------------------------------------------------
# DISKS
#------------------------------------------------------------

# Block devices
func_list_blkdev () { [[ $EXCLUDE != "Yes" ]] && blkid ; }
func_get_blkdev () { echo "\"$line\"" ; }

# df output
func_list_df () { df -HP | grep -v Filesystem ; }
func_get_df () { echo "$line" | awk '{print $1 "," $2 "," $3 "," $4 "," $5 "," $6}' ; }

# Volume groups
func_list_lvmvg () {
                    if [[ $EXCLUDE != "Yes" ]]; then
                       vgs --noheadings -o vg_name,vg_size,vg_free 2>/dev/null
                    else
                       echo "LVM_query_aborted_due_to_risk_of_locking"
                    fi
                   }
func_get_lvmvg () {  echo "\"$line\"" ; }

# Logical volumes
func_list_lvmlv () {
                    if [[ ! -f /var/lock/lvm/* ]] && [[ $(hostname) != ebs* && $(hostname) != ccow* &&  $(hostname) != imgow* ]]; then
                       [[ ${RH4} = "No" ]] && lvs --noheadings -o lv_name,lv_path,lv_size 2>/dev/null
                       [[ ${RH4} = "Yes" ]] && lvs --noheadings -o lv_name,lv_size 2>/dev/null
                    else
                       echo "LVM_query_aborted_due_to_risk_of_locking"
                    fi
                   }
func_get_lvmlv () { echo "\"$line\"" ; }

#------------------------------------------------------------
# UTILISATION
#------------------------------------------------------------

if [[ $SAR_EXIST = Yes ]]; then

func_get_util_mem_peak () { for i in /var/log/sa/sa[0-9]*
                            do
                              sar -r -f $i | grep Average | awk '{print $4}'
                            done | awk 'BEGIN {max = 0} {if ($1>max) max=$1} END {printf("%-1.0f%-1s\n", max, "%")}'
                         }

func_get_util_mem_avge () { for i in /var/log/sa/sa[0-9]*
                            do
                              sar -r -f $i | grep Average | awk '{print $4}'
                            done | awk 'BEGIN {sum = 0} {sum+=$1} END {printf("%-1.0f%-1s\n", sum/=NR, "%")}'
                         }

func_get_util_swap_avge () {
                            if [[ -n $(uname -r | grep "2.6.32") ]]; then
                               SAR_COMM="$(for i in /var/log/sa/sa[0-9]*; do   sar -S -f $i | grep Average | awk '{print $4}'; done | sort -n)"
                            else
                               SAR_COMM="$(for i in /var/log/sa/sa[0-9]*; do   sar -r -f $i | grep Average | awk '{print $9}'; done | sort -n)"
                            fi

                            echo "$SAR_COMM" | awk 'BEGIN {sum = 0} {sum+=$1} END {printf("%-1.2f%-1s\n", sum/=NR, "%")}'
                           }

func_get_util_cpuidle_avge () { for i in /var/log/sa/sa[0-9]*
                             do
                               sar -u -f $i | grep Average | awk '{print $8}'
                             done | awk 'BEGIN {sum = 0} {sum+=$1} END {printf("%-1.0f%-1s\n", sum/=NR, "%")}'
                              }
fi

#------------------------------------------------------------
# Queries to consider adding
#------------------------------------------------------------

# rpm -qa --queryformat '%-50{NAME} %{VENDOR}\n' | sort -d -f | egrep -iv 'red hat'
# cat /etc/fstab
# fdisk -l
# cat /etc/exports
# rpm -qa | grep multipath; chkconfig --list multipathd; /sbin/multipath -v2 -d -ll; grep -vE '^#|^ *$' /etc/multipath.conf; cat /var/lib/multipath/bindings
# lvs -o +devices
# netstat -tlpn  (listening TCP ports); netstat -ulpn (UDP ports)
# cat /etc/hosts; cat /etc/resolv.conf; cat /etc/nsswitch.conf
# grep -vE '^#|^ *$' /etc/ssh/sshd_config (sshd config)
# ps -ef | egrep -i 'X|Xorg|vnc' (check for X)
# ls -1d /usr/local/bin /usr/local/sbin /opt
# smbstatus; testparm
# cat /var/cpq/Component.log
# inittab
# chkconfig --list
# cat /var/spool/cron/*
# cat /proc/scsi/scsi

#------------------------------------------------------------
# * MAIN *
#------------------------------------------------------------

# Summary
func_std_comm hostname
func_std_comm fqdn
func_std_comm rhrel
func_std_comm kernel
func_std_comm vcpucount
func_std_comm disk_total_alloc
func_std_comm disk_actual_use
func_std_comm disk_actual_free
# Hardware
func_std_comm product
func_std_comm serial
func_std_comm bios
func_std_comm enc_name
func_std_comm enc_model
func_std_comm enc_serial
func_std_comm enc_server_bay
func_std_comm enc_bays_filled
# Detail
#func_for_loop nic
func_for_loop disk
func_whl_loop ip
func_whl_loop mac
func_whl_loop route
func_std_comm memtotal
func_whl_loop cpu
func_whl_loop corecount
func_whl_loop blkdev
func_whl_loop lvmvg
func_whl_loop lvmlv
# Utilisation
if [[ $SAR_EXIST = Yes ]]; then
   func_std_comm util_mem_peak
   func_std_comm util_mem_avge
   func_std_comm util_swap_avge
   func_std_comm util_cpuidle_avge
fi

exit
# End