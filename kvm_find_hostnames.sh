#!/bin/bash

# Script to list all KVM hostnames, IPs, mac addresses and interfaces 
# Also possible to use virsh net-dhcp-leases --network <network_name> 
# Gets hostnames from virsh list --all, mac addresses from virsh dumpxml 
# and IPs from arp -e

#-------------------------------------------
# Ensure writable /tmp & execution by root 
#-------------------------------------------

if [[ $(id -u) != 0 ]]; then
   echo "Error: script must be run as root user."
   exit 2
fi

if [[ -w /tmp ]]; then 
   ARP_DATA=/tmp/arp.out
else
   echo "/tmp not writable!"
   exit 3
fi

if [[ $# != 0 ]]; then
   if [[ $1 = 4 || $1 = ip4 || $1 = ipv4 ]]; then
      IPv4=TRUE
   elif [[ $1 = 6 || $1 = ip6 || $1 = ipv6 ]]; then
      IPv6=TRUE
   else
      echo "Valid arguments are [4|6] or [ip4|ip6] or [ipv4|ipv6]"
      exit 4
   fi
else
   echo "Error: Please specify IPv4 or IPv6 records"
   echo "Usage: $(basename $0) [4|6] [ip4|ip6] [ipv4|ipv6]"
   exit 5
fi

#-------------------------------------------
# Collect and store arp cache data
# Faster & better to use "ip neigh" instead of "arp -e"
#-------------------------------------------

#arp -e | sort -n | egrep -v 'Address|router' | awk 'NF==3 {print $1, $2, $3}; NF==5 {print $1, $3, $5}' > $ARP_DATA 

[[ -n $IPv4 ]] && ip neigh | sort -n | grep -v ^f | awk 'NF==6 {print $1, $5, $3}' > $ARP_DATA
[[ -n $IPv6 ]] && ip neigh | sort -n | grep ^f    | awk 'NF==6 {print $1, $5, $3}' > $ARP_DATA

#-------------------------------------------
# Loop over all running VMs
# Extract the mac address from the XML data 
#-------------------------------------------

for vm in $(virsh list --all | grep running | awk '{print $2}')
 do
   # Print VM's hostname & take new line if printing multi-line IPv6 output 
   [[ -n $IPv4 ]] && echo -n "$vm = " | awk '{printf("%-15s%-3s", $1, $2)}'
   [[ -n $IPv6 ]] && echo -n "$vm = " | awk '{printf("%-15s%-3s\n", $1, $2)}'
   for mac_address in $(virsh dumpxml $vm | egrep 'mac address' | awk -F"'" '{print $2}')
    do
      # use readline in order to process multi-line output from duplicate mac addresses
      grep "${mac_address}" $ARP_DATA |
       while read line
        do
         [[ -n $IPv4 ]] && echo -n "$line" | awk '{printf("%-15s%-20s%-12s", $1,"("$2")","["$3"]")}'
         [[ -n $IPv6 ]] && echo -n "$line" | awk '{printf("%-15s%-20s%-12s\n", $1,"("$2")","["$3"]")}'
       done
    done
   echo ""
 done

exit
