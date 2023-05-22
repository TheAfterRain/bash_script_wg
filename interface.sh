#!/bin/bash

IP="95.140.153.177"



if [ -z $1 ]; then
BEGIN=1
END=5
else
BEGIN=$1
END=$1
fi

for (( n = $BEGIN; n <= $END; n++))
do
# number of peers in interface
PEERS_NUMBER=5

# ordinal number of interface
IFACE_NUMBER=$n

#############################################################

# interface name var
IFACE="wg$IFACE_NUMBER"

LAST=$(( 1 + PEERS_NUMBER * IFACE_NUMBER ))
ADDRESS="10.1.1.${LAST}"

# server-side keys of interface
umask 077
PRIVATESERVER=$(wg genkey)

PORT=$((51820 + 10 * $IFACE_NUMBER))

DIR=${IFACE}_confs
mkdir $DIR

# config generation
CONFIG="
[Interface] \n
PrivateKey = $PRIVATESERVER \n
ListenPort = $PORT \n
"

for (( i = 1; i <= $PEERS_NUMBER; i++ ))
do
PUBLICSERVER=$( echo $PRIVATESERVER | wg pubkey )
((LAST++))
ADDRESS="10.1.1.${LAST}"

PRIVATEPEER=$(wg genkey)
PUBLICPEER=$( echo $PRIVATEPEER | wg pubkey )

# peer part of server config
PEER="
[Peer] \n
PublicKey = $PUBLICPEER \n
AllowedIPs = ${ADDRESS}/32 \n
"
CONFIG+="$PEER"

PEER_CONFIG="
[Interface] \n
PrivateKey = $PRIVATEPEER \n
Address = $ADDRESS \n
DNS = 8.8.8.8 \n
[Peer] \n
PublicKey = $PUBLICSERVER \n
Endpoint = ${IP}:${PORT} \n
AllowedIPs = 0.0.0.0/0 \n 
PersistentKeepalive = 20 \n
"
echo -e $PEER_CONFIG > ./${DIR}/${IFACE_NUMBER}${i}.conf
done

echo -e $CONFIG > ./${IFACE}.conf
chmod 777 ${IFACE}.conf

#############################################################

cp ${IFACE}.conf /etc/wireguard/${IFACE}.conf

# adds and setup the interface
#ip link add $IFACE type wireguard && ip link set $IFACE up

# open port
#iptables -i $IFACE -A INPUT -p udp --dport $PORT -j ACCEPT

wg-quick up $IFACE
wg setconf wg1 wg1.conf

#############################################################

IB="inbound_$IFACE"
LIMIT=20mbit 

tc qdisc add dev $IFACE parent root handle 1: hfsc default 1 
tc class add dev $IFACE parent 1: classid 1:1 hfsc sc rate $LIMIT ul rate $LIMIT 

ip link add name $IB type ifb 
ip link set dev $IB up 

tc qdisc add dev $IFACE handle ffff: ingress 
tc filter add dev $IFACE protocol ip parent ffff: matchall action mirred egress redirect dev $IB 

tc qdisc add dev $IB parent root handle f: hfsc default 19 
tc class add dev $IB parent f: classid f:1 hfsc sc rate $LIMIT ul rate $LIMIT
tc class add dev $IB parent f:1 classid f:19 hfsc ls rate $LIMIT

done

#############################################################

chmod 777 *.conf
chmod -R 777 wg*