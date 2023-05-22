#!/bin/bash

IFACE="wg${1}"

wg-quick down $IFACE
ip link set inbound_${IFACE} down
ip link delete inbound_${IFACE}