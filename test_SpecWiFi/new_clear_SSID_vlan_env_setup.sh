#! /bin/bash

##########################################
######### for vlan clear
######### pass arguement as start/stop/restart
######### and mode as 6 for ipv6 and anything for ipv4
##########################################

fun_setup_info(){
	if [ "$1" == "6" ]	
	then
		IP6=“true”
	fi
	if [ -z ${IP6+x} ];
	then
	    echo "IP6 not set"
		LOCAL_EP=11.0.0.60
		REMOTE_EP=11.0.0.1
		SEC_LOCAL_EP=11.0.0.11
		GRENAME=gretap_clr
		SEC_GRE_NAME=secgretap_clr
	else
		LOCAL_EP=2001:db9::4
		REMOTE_EP=2001:db9::1
		SEC_LOCAL_EP=2001:db9::5
		GRENAME=gretap6_clr
		SEC_GRE_NAME=secgretap6_clr

	fi

	BRCOMNAME=br-clr_com
	BRTAPNAME=br-clr_comtap
	GRE_VLAN_ID=5
	VLAN_ID=7
	#nick#ETH_IF_NAME=eth0
	ETH_IF_NAME=enp7s0
	
	echo "Local Endpoint : $LOCAL_EP"
	echo "Sec Local Endpoint : $SEC_LOCAL_EP"
	echo "Remote Endpoint : $REMOTE_EP"
	
	echo "Gre Tap name : $GRENAME"
	echo "Sec Gre Tap name : $SEC_GRE_NAME"
	
	echo "Bridge com name : $BRCOMNAME"
	echo "Bridge com Tap name : $BRTAPNAME"
	
}
	
fun_down_intf(){
	
	if [ "$1" == "6" ]	
	then
		IP6=true
	fi
	
	echo "Removing Previous Configurations"
	brctl delif $BRTAPNAME $GRENAME
	brctl delif $BRTAPNAME $SEC_GRE_NAME
	brctl delif $BRTAPNAME veth2
		
	if [ -z ${IP6+x} ];
	then
		ip addr del $LOCAL_EP/24 dev $ETH_IF_NAME.$GRE_VLAN_ID
		ip addr del $SEC_LOCAL_EP/24 dev $ETH_IF_NAME.$GRE_VLAN_ID
		echo "Deleting $ETH_IF_NAME.$GRE_VLAN_ID"
		vconfig rem $ETH_IF_NAME.$GRE_VLAN_ID
	else
		ip -6 addr del $LOCAL_EP/64 dev $ETH_IF_NAME.$GRE_VLAN_ID
		ip -6 addr del $SEC_LOCAL_EP/64 dev $ETH_IF_NAME.$GRE_VLAN_ID
		echo "Deleting $ETH_IF_NAME.$GRE_VLAN_ID"
		vconfig rem $ETH_IF_NAME.$GRE_VLAN_ID
	fi
	
	
	ip link del dev $GRENAME
	ip link del dev $SEC_GRE_NAME
	ifconfig $BRTAPNAME down
	brctl delbr $BRTAPNAME
	
	if [ -z ${VLAN_ID+x} ];
	then
	echo "VLAN for SSID not set"
	        brctl delif $BRCOMNAME veth3
	else
	        brctl delif $BRCOMNAME veth3.$VLAN_ID
	        vconfig rem veth3.$VLAN_ID
	fi
	sleep 1
	ip link del dev veth2
	ifconfig $BRCOMNAME down
	brctl delbr $BRCOMNAME
	sleep 1
	
	echo "Stoping coova-chilli service"	
	#/etc/init.d/chilli stop
	killall chilli
	
	echo "Stoping freeradius server"
	/etc/init.d/freeradius stop
	
	echo ">>>>>>>>>Deleting and Cleaning is Done>>>>>>>>"
}

fun_up_intf(){
	if [ "$1" == "6" ]	
	then
		IP6=true
	fi

	echo ">>>>>>>>>Now Starting to create and Setup Fresh>>>>>>>>"

	echo "Now Creating a $BRTAPNAME"
	
	brctl addbr $BRTAPNAME

	echo "Creating $GRE_NAME with local $LOCAL_EP and remote $REMOTE_EP"
	echo "Creating $SEC_GRE_NAME with local $SEC_LOCAL_EP and remote $REMOTE_EP"	

	if [ -z ${IP6+x} ];
	then
		ip link add $GRENAME type gretap local $LOCAL_EP remote $REMOTE_EP
		ip link add $SEC_GRE_NAME type gretap local $SEC_LOCAL_EP remote $REMOTE_EP
		ip link set dev $GRENAME up 
		ip link set dev $SEC_GRE_NAME up
	else
		ip -6 link add $GRENAME type ip6gretap local $LOCAL_EP remote $REMOTE_EP
		ip -6 link add $SEC_GRE_NAME type ip6gretap local $SEC_LOCAL_EP remote $REMOTE_EP
		ip -6 link set dev $GRENAME up 
		ip -6 link set dev $SEC_GRE_NAME up
	fi

	echo "Creating a $BRCOMNAME"

	brctl addbr $BRCOMNAME
	
	echo "Now creating vlan interface for $ETH_IF_NAME.$GRE_VLAN_ID"
	
	if [ -z ${IP6+x} ];
	then
		vconfig add $ETH_IF_NAME $GRE_VLAN_ID
		echo "Assigning ipv4 ip's to local and sec local ep "
		ip addr add $LOCAL_EP/24 dev $ETH_IF_NAME.$GRE_VLAN_ID
		ip addr add $SEC_LOCAL_EP/24 dev $ETH_IF_NAME.$GRE_VLAN_ID
		ifconfig $ETH_IF_NAME.$GRE_VLAN_ID up
	else
		vconfig add $ETH_IF_NAME $GRE_VLAN_ID
		echo "Assigning ipv6 ip's to local and sec local ep "
		ip -6 addr add $LOCAL_EP/64 dev $ETH_IF_NAME.$GRE_VLAN_ID
		ip -6 addr add $SEC_LOCAL_EP/64 dev $ETH_IF_NAME.$GRE_VLAN_ID
		ifconfig $ETH_IF_NAME.$GRE_VLAN_ID up

	fi
	
	echo "Creating veth pipe"
	ip link add veth2 type veth peer name veth3
	
	if [ -z ${VLAN_ID+x} ];
	then
		brctl addif $BRCOMNAME veth3
	else
		echo "Creating veth3.$VLAN_ID"
		vconfig add veth3 $VLAN_ID
		sleep 1
		echo "Adding veth3.$VLAN_ID to $BRCOMNAME"
		brctl addif $BRCOMNAME veth3.$VLAN_ID
	fi


	echo "Adding $GRE_NAME $SEC_GRE_NAME and veth2 in $BRTAPNAME"
	brctl addif $BRTAPNAME $GRENAME
	brctl addif $BRTAPNAME $SEC_GRE_NAME
	brctl addif $BRTAPNAME veth2

	echo "Bringing the veth interfaces up"
	ifconfig veth2 up
	if [ -z ${VLAN_ID+x} ];
	then
		ifconfig veth3 up
	else
		ifconfig veth3 up     ###this interface must be setup at first.
		ifconfig veth3.$VLAN_ID up
	fi
	
	echo "Bringing $BRTAPNAME up"
	ifconfig $BRTAPNAME up
	
	echo "Bringing $BRCOMNAME up"
	ifconfig $BRCOMNAME up

	echo "Starting coova-chilli service"	
	/etc/init.d/chilli start
	
	echo "Start freeradius server"
	/etc/init.d/freeradius start
	
	ip addr show $ETH_IF_NAME.$GRE_VLAN_ID	
	echo "******---------- Creation is Done ------****"
}

MODE=$2
fun_setup_info $MODE

case "$1" in
        restart)
	        fun_down_intf $MODE
	        fun_up_intf $MODE
        ;;
        start)
	        fun_up_intf $MODE
        ;;
        stop)
	        fun_down_intf $MODE
        ;;
esac

