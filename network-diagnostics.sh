#!/bin/bash

#____________________
END="\033[0m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
RED="\033[0;31m"
#_____________________________________________________________________________
CTS=/opt/express/
VOEX=/opt/express-voice/
##FBf=$(grep "cts_frontend:" /opt/express/settings.yaml | awk '{print $1}')
##FBb=$(grep "cts_backend:" /opt/express/settings.yaml | awk '{print $1}')


usage=' '$0' скрипт для диагностики сетевых взаимодействий
where:
    -h and --help 
        show this help text
    --path-settings-cts "/dir/settings.yaml" 
        Путь к настройкам Single CTS или Front-Back CTS. По умолчанию: '${CTS}'
    --path-settings-voex "/dir/settings.yaml"  
        Путь к настройкам Voex. По умолчанию: '${VOEX}'
    '
while [ $# -gt 0 ]
do
   case $1 in
      --help)
         echo "$usage"
         shift
         ;;
      -h)
         echo "$usage"
         shift
         ;;
      --path-settings-cts)
         CTS=${2}
         shift
         ;;
      --path-settings-voex)
         VOEX=${2}
         shift
         ;;
   esac
   shift
done

echo "$usage"

#_______________________________________________
##mkdir -p $PWD/cts_diagnostic/host_info/network
#_______________________________________________________________________________________________________________
function CheckRoot () {
        echo -e "${YELLOW} Checking root ${END}"
        if [ "$EUID" -ne 0 ]; then
                echo -e "${RED} This script must be run when root or sudoer, because of docker checking ${END}"
                exit 1
        else
                echo -e "${GREEN} OK! ${END}"
        fi
}

#____________________________________________________________________________
function CheckCTS() {

	if [ -d "$CTS" ]; then
                echo -e "${GREEN} CTS ${END}"

                if [ -n "$FBf" ]; then
                        echo -e "${GREEN} This Front CTS ${END}"
                        CheckNetwork
        	        CheckTelnet
        	        CheckSS
                        CheckDB
                        CheckKafka
                        CheckEtcd
                        CheckRedis
                        CheckFB
                        CheckSSL
                        

                elif [ -n "$FBb" ]; then
                        echo -e "${GREEN} This Back CTS ${END}"
                        CheckNetwork
        	        CheckTelnet
        	        CheckSS
                        CheckDB
                        CheckKafka
                        CheckEtcd
                        CheckRedis
                        CheckVoexCS
                        CheckFB
                        CheckJanus
                        CheckSSL
                        

                elif [ -z "$FBb" ] && [ -z "$FBf" ]; then
                        echo -e "${GREEN} This Single CTS ${END} "
                        CheckNetwork
        	        CheckTelnet
        	        CheckSS
                        CheckDB
                        CheckKafka
                        CheckEtcd
                        CheckRedis
                        CheckVoexCS
                        CheckJanus
                        CheckSSL
                        

                fi
        fi
	if [ -d "$VOEX" ]; then
                echo -e "${GREEN} This Voex server ${END}"
		CheckNetwork
        	CheckSS
		CheckVoexService
	fi
}
#____________________________________________________________________________
function CheckVoexService() {
        echo -e "${YELLOW} Checking network info ${END}"
        if [ -d "$VOEX" ]; then
        cp /opt/express-voice/.voex/express-voice.service $PWD/cts_diagnostic/host_info/network/
        fi
}

function CheckNetwork() {
        echo -e " ${GREEN} CheckNetwork ${END} "
        ip a > $PWD/cts_diagnostic/host_info/network/interfaces.txt
        iptables -L -nvx > $PWD/cts_diagnostic/host_info/network/iptables.txt
        ip route > $PWD/cts_diagnostic/host_info/network/iproute.txt
        if [ -d "$CTS" ]; then
        ccs_host=$(grep "ccs_host:" /opt/express/settings.yaml | awk '{print $2}')
        nslookup $ccs_host > $PWD/cts_diagnostic/host_info/network/nslookup.txt 2>&1
        elif [ ! -d "$CTS" ] && [ -d "$VOEX" ]; then
        ccs_host=$(grep "turnserver_server_name:" /opt/express-voice/settings.yaml | awk '{print $2}')
        nslookup $ccs_host > $PWD/cts_diagnostic/host_info/network/nslookup.txt 2>&1
        elif [ ! -d "$CTS" ] && [ ! -d "$VOEX" ]; then
        echo "/opt/express/ and /opt/express-voice/ didn't exist" > $PWD/cts_diagnostic/host_info/no-express-folders!.txt
        ccs_host=noname
        fi
}

function CheckTelnet() {
        echo -e " ${GREEN} CheckTelnet ${END} "
        if command -v telnet > /dev/null ; then
        (echo open ru.public.express 5001; sleep 1; echo quit) | telnet > $PWD/cts_diagnostic/host_info/network/telnet.txt 2> /dev/null
        (echo open registry.public.express 443; sleep 1; echo quit) | telnet >> $PWD/cts_diagnostic/host_info/network/telnet.txt 2> /dev/null
        else
        echo -e "${RED} Telnet is not installed ${END}"
        echo "Telnet is not installed" > $PWD/cts_diagnostic/host_info/network/telnet.txt
        fi
        echo -e "${GREEN} Network info written! ${END}"
}

function CheckSS(){
        echo -e " ${GREEN} CheckSS ${END} "
        if command -v ss > /dev/null ; then
        ss -tunlp > $PWD/cts_diagnostic/host_info/network/ss.txt
        else
        echo -e "${RED} SS is not installed ${END}"
        echo "SS is not installed" > $PWD/cts_diagnostic/host_info/network/ss.txt
        fi
        echo -e "${GREEN} SS info written! ${END}"
}

function CheckSSL () {
        echo -e "${YELLOW} Checking SSL info ${END}"
        echo -e "GET / HTTP/1.0\n\n" | timeout 15 openssl s_client -connect $ccs_host:443 > $PWD/cts_diagnostic/host_info/network/openssl_info.txt 2>&1
        echo -e "${GREEN} SSL info written! ${END}"
}

function CheckSettingsFiles () {
        echo -e "${YELLOW} Checking all settings files ${END}"
        mkdir cts_diagnostic/settings_files 

        if [ -d "$CTS" ]; then
                cp /opt/express/settings.yaml $PWD/cts_diagnostic/settings_files/cts_settings.yaml
        fi
        if [ -d "$VOEX" ]; then
		cp /opt/express-voice/settings.yaml $PWD/cts_diagnostic/settings_files/voice_settings.yaml
        fi

        echo -e "${GREEN} Settings written! ${END}"
}

function CheckServer() {
        echo -e " ${GREEN} CheckServer ${END} "
	CTS_front="frontend_host:"
        frontend_host=$(grep "frontend_host:" /opt/express/settings.yaml | awk '{print $1}')
	if [ -n "$frontend_host" ] && [[ "$frontend_host" == "$CTS_front" ]]; then
        echo -e "${GREEN} CTS front and back, check DB,VOEX,ETCD,kafka! ${END}"
        else
        echo -e "${GREEN} CTS singel! ${END}"
        fi
}

function CheckSingleCTS() {
        echo -e " ${GREEN} CheckSingleCTS ${END}"
#	DB="postgres_endpoints:"
	check_DB_point=$(grep "postgres_endpoints:" /opt/express/settings.yaml | awk '{print $1}')
	if [ -n "$check_DB_point" ]; then
		check_DB_ip=$(grep "postgres_endpoints:" /opt/express/settings.yaml | awk '{print $2}')
		ip_db=$(echo $check_DB_ip | awk -F ':' '{print $1}')
		port_db=$(echo $check_DB_ip | awk -F ':' '{print $2}')
		(echo open $ip_db $port_db; sleep 1; echo quit) | telnet >> $PWD/cts_diagnostic/host_info/network/db_telnet.txt 2> /dev/null
	fi
}


function CheckDB(){
        echo -e "${GREEN} CheckDB ${END}"
	check_DB_ip=$(grep "postgres_endpoints:" /opt/express/settings.yaml | awk '{print $2}')
	IFS=',' read -r -a addresses <<< "$check_DB_ip"
	declare -a ips
	declare -a ports
	for address in "${addresses[@]}"; do
    		IFS=':' read -r ip port <<< "$address"
    		ips+=("$ip")
    		ports+=("$port")
	done
	for i in "${!ips[@]}"; do
		ip="${ips[$i]}"
		port="${ports[$i]}"
		echo $ip
		echo $port
		(echo open $ip $port; sleep 1; echo quit) | telnet >> $PWD/cts_diagnostic/host_info/network/db_telnet.txt 2> /dev/null
	done
}


function CheckKafka(){
        echo -e " ${GREEN} CheckKafka ${END}"
        port_kafka_1="9092"
        port_kafka_2="9093"
        check_Kafka_ip=$(grep "kafka_host:" /opt/express/settings.yaml | awk '{print $2}')

        IFS=',' read -r -a addresses <<< "$check_Kafka_ip"
        declare -a ipk
        for address in "${addresses[@]}"; do
                IFS=':' read -r ip <<< "$address"
                ipk+=("$ip")
        done
        for i in "${!ipk[@]}"; do
                ip="${ipk[$i]}"
                echo $ip
                echo "check port 9092" >> $PWD/cts_diagnostic/host_info/network/kafka_telnet.txt
                (echo open $ip $port_kafka_1; sleep 1; echo quit) | telnet "$ip" "$port_kafka_1" >> $PWD/cts_diagnostic/host_info/network/kafka_telnet.txt 2>&1
                echo "check port 9093" >> $PWD/cts_diagnostic/host_info/network/kafka_telnet.txt
                (echo open $ip $port_kafka_2; sleep 1; echo quit) | telnet "$ip" "$port_kafka_2" >> $PWD/cts_diagnostic/host_info/network/kafka_telnet.txt 2>&1
        done
}


function CheckEtcd(){
        echo -e "${GREEN} CheckEtcd ${END}"
	check_etcd_ip=$(grep "etcd_endpoints:" /opt/express/settings.yaml | awk '{print $2}' | sed 's,http://,,g')
	IFS=',' read -r -a addresses <<< "$check_etcd_ip"
	declare -a ips
	declare -a ports
	for address in "${addresses[@]}"; do
    		IFS=':' read -r ip port <<< "$address"
    		ips+=("$ip")
    		ports+=("$port")
	done
	for i in "${!ips[@]}"; do
		ip="${ips[$i]}"
		port="${ports[$i]}"
		echo $ip
		echo $port
		(echo open $ip $port; sleep 1; echo quit) | telnet >> $PWD/cts_diagnostic/host_info/network/etcd_telnet.txt 2> /dev/null
	done
}

function CheckRedis(){
        echo -e "${GREEN} CheckRedis ${END}"
	check_redis_ip=$(grep -E 'redis_connection_string' /opt/express/settings.yaml | grep -v 'voex_' | awk '{print $2}' | sed -e 's,redis://,,g' -e 's,/0,,g')
	IFS=',' read -r -a addresses <<< "$check_redis_ip"
	declare -a ips
	declare -a ports
	for address in "${addresses[@]}"; do
    		IFS=':' read -r ip port <<< "$address"
    		ips+=("$ip")
    		ports+=("$port")
	done
	for i in "${!ips[@]}"; do
		ip="${ips[$i]}"
		port="${ports[$i]}"
		echo $ip
		echo $port
		(echo open $ip $port; sleep 1; echo quit) | telnet >> $PWD/cts_diagnostic/host_info/network/redis_telnet.txt 2> /dev/null
	done
}

function CheckVoexCS(){
        echo -e "${GREEN} CheckVoexCS ${END}"
	check_voex_cs=$(grep "voex_redis_connection_string:" /opt/express/settings.yaml | awk -F'[@:]' '{print $(NF-1)":"$NF}' | sed 's,/1,,g')
	if [[ -n $check_voex_cs ]]; then
        IFS=',' read -r -a addresses <<< "$check_voex_cs"
	declare -a ips
	declare -a ports
	for address in "${addresses[@]}"; do
    		IFS=':' read -r ip port <<< "$address"
    		ips+=("$ip")
    		ports+=("$port")
	done
	for i in "${!ips[@]}"; do
		ip="${ips[$i]}"
		port="${ports[$i]}"
		echo $ip
		echo $port
		(echo open $ip $port; sleep 1; echo quit) | telnet >> $PWD/cts_diagnostic/host_info/network/voex_r_cs_telnet.txt 2> /dev/null
	done
        fi
}

function CheckFB() {
        echo -e "${GREEN} CheckFB ${END}"
        front_ip=$(grep "frontend_host:" /opt/express/settings.yaml | awk '{print $2}')
        back_ip=$(grep "backend_host:" /opt/express/settings.yaml | awk '{print $2}')
        echo "ping front"
        ping -c 4 $front_ip >> $PWD/cts_diagnostic/host_info/network/ping_front.txt 2> /dev/null
        echo "ping back"
        ping -c 4 $back_ip >> $PWD/cts_diagnostic/host_info/network/ping_back.txt 2> /dev/null
}

function CheckJanus(){
        echo -e "${GREEN} CheckJanus ${END}"
	check_janus_ws=$(docker exec -it cts-messaging-1 ./bin/messaging rpc Messaging.janus_urls | sed -e 's/\[//g' -e 's/\]//g' -e 's/\"//g' -e 's,ws://,,g')
	if [[ -n $check_voex_cs ]]; then
        IFS=',' read -r -a addresses <<< "$check_janus_ws"
	declare -a ips
	declare -a ports
	for address in "${addresses[@]}"; do
    		IFS=':' read -r ip port <<< "$address"
    		ips+=("$ip")
    		ports+=("$port")
	done
	for i in "${!ips[@]}"; do
		ip="${ips[$i]}"
		port="${ports[$i]}"
		echo $ip
		echo $port
		(echo open $ip $port; sleep 1; echo quit) | telnet >> $PWD/cts_diagnostic/host_info/network/Janus_telnet.txt 2> /dev/null
	done
        fi
}

function CreateArchive () {
        if [ -d "$CTS" ]; then
                if grep -q "cts_frontend: true" /opt/express/settings.yaml; then serverrole=front-network
                elif grep -q "cts_backend: true" /opt/express/settings.yaml; then serverrole=back-network
                else serverrole=single-network
                fi
        elif [ ! -d "$CTS" ] && [ -d "$VOEX" ]; then
        serverrole=voex-network
        elif [ ! -d "$CTS" ] && [ ! -d "$VOEX" ]; then
        serverrole=noserver
        echo -e "${RED} No Express folders in /opt! ${END}"
        fi
        tar -czf $ccs_host-$serverrole.tar.gz cts_diagnostic/
        rm -rf cts_diagnostic
        echo -e "${GREEN} Written to $PWD/$ccs_host-$serverrole.tar.gz ${END}"
}


#CheckRoot
#CheckCTS
#CheckSettingsFiles
#CreateArchive
#CheckSingleCTS
#CheckServer