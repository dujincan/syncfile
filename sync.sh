#!/bin/bash 

log=/tmp/sync.log
function check_ip() {
            VALID_CHECK=$(echo $ip|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
            if echo $ip|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null;
            then
                retval=$?
                if [ ${VALID_CHECK:-no} != "yes" ];
                then
                    retval=$?
                    echo "IP $ip not available!"
                    exit $retval
                fi
            else
                echo "IP format error!"
                exit $retval
            fi
}

function check_ip_available() {
            loss=`ping -f -c 10 -f $ip |grep loss |awk -F "%" '{print $1}' |awk '{print $NF}'`
            if [ $loss -ne 0 ]
            then
                echo "ip unreachable"
                exit 1
            fi
}

function check_passwd() {
            $ssh  "free -m" &>/dev/null
            retval=$?
            if [ $retval -ne 0 ]
            then
                echo "passwd is fail"
                exit $retval
            fi
}

read -t 30 -p "Please enter new conf file path and name(/root/nginx.conf):" local_conf
[ -f $local_conf ] || exit 1
read -t 30 -p "Please enter server ip:" server
ip=$server
check_ip
check_ip_available
read -t 30 -p "Please enter server passwd:" passwd
ssh="sshpass -p $passwd ssh $ip"
check_passwd
read -t 30 -p "Please enter server conf file(/application/nginx/conf/nginx.conf):" server_path
$ssh "ls $server_path" &>$log
retval=$?
if [ $retval -ne 0 ]
then
    echo "$server_path not exist"
    exit $retval
fi

sshpass -p $passwd ssh $server "cp $server_path ${server_path}.`date +%F-%T`" &>$log
retval=$?
if [ $retval -eq 0 ]
then
    sshpass -p $passwd scp $local_conf $server:$server_path &>$log
    retval=$?
    if [ $retval -eq 0 ]
    then
        md5s=`md5sum $local_conf|awk '{print $1}'`
        md5d=`sshpass -p $passwd ssh $server "md5sum $server_path"|awk '{print $1}'`
        if [ $md5s == $md5d ]
        then
            echo "conf file sync successful"
        else
            echo "copy conf file fail"
            echo "please check $log"
            exit 1
        fi
    else
        echo "copy conf file fail"
        echo "please check $log"
        exit $retval
    fi 
else
    echo "old conf file backup fail"
    echo "please check $log"
    exit $retval
fi 

