#!/bin/bash

func_loop () 
{
 let counter=0 
 for i in $(func_list_${1}) 
  do
    let counter=${counter}+1
    Prefix=$(echo ${1} | tr "[:lower:]" "[:upper:]")
    echo -n "${Prefix}${counter}="
    func_get_${1}
  done 
}
#------------------------------------------------------------
# DISK
#------------------------------------------------------------
func_list_disk () { echo ""$(df -HP | grep -v Filesystem | awk '{print $NF}')"" 
                  }

func_get_disk () { df -HP $i | grep -v Filesystem
                 }
#------------------------------------------------------------
# NETWORK 
#------------------------------------------------------------
func_list_nic () { ifconfig | grep -v lo | grep mtu | awk '{print $1}' | awk -F':' '{print $1}'
                 }

func_get_nic () {
 #ifconfig $i | awk '/ether/{printf $2 "/"} /inet/{print $2}' 
 #ifconfig $i | awk '{
 #                    if($1~/ether/){printf $2 "/"}
 #                    if($1~/inet/){print $2}
 #                    else {print ""}
 #                   }' 
 ifconfig $i | awk '
                    $1~/ether/ {printf $2 "/"}
                    $1~/inet/ {print $2}
                    $1!~/ether/ && $1!~/inet/ {print ""}
                   ' | xargs echo
}
#------------------------------------------------------------
# * MAIN * 
#------------------------------------------------------------
func_loop disk 
func_loop nic 
