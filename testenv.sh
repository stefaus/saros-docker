#!/bin/bash
# author: Stefan Moll <stefan@stefaus.de>
# version: 0.1 – worksforme
# it's not always beautiful solved, but should work

# assumptions to let this work
# - using mint linux / ubuntu, other linux should work
# - uses sudo for traffic control and docker if use is not added to docker group
# - using the folder structure


# use unofficial bash strict mode
set -euo pipefail
IFS=$'\n\t'

traperr() {
  # TODO cleanup on error?
  echo "ERROR: ${BASH_SOURCE[1]} at about ${BASH_LINENO[0]}"
}
set -o errtrace
trap traperr ERR
###############################################################################
swtnet="192.168.25.0/24"
declare -A swthosts
swthosts=(["saros-alice"]="192.168.25.100" ["saros-bob"]="192.168.25.101" ["saros-carl"]="192.168.25.102" ["saros-dave"]="192.168.25.103")

check() {
    echo "check sudo rights"
    sudo echo "ok"
    
    # work path is one folder above and we use the username and id to avoid 
    # filesystem rights trouble
    SAROSPATH=$(cd .. && pwd)
    echo "SAROSPATH: $SAROSPATH"
    SAROSUSERNAME=$(ls -l $SAROSPATH | grep workspaces | tr -s ' ' | cut -d ' ' -f 3)
    SAROSUSERID=$(ls -n $SAROSPATH | grep workspaces | tr -s ' ' | cut -d ' ' -f 3)
    echo "SAROSUSERNAME: $SAROSUSERNAME, SAROSUSERID: $SAROSUSERID"

    # check the structure
    folder_check eclipse
    folder_check jdk
    folder_check git/saros
    folder_check workspaces
    folder_check docker #should be
    
    echo 'Checking all requirements and download missing'
    if [ -z $(command -v docker) ]; then
        echo 'Docker not found! please install first\!'
        echo 'see https://docs.docker.com/install'
        exit 1
    fi
    if [ -z $(command -v tc) ]; then
        echo 'tc not found! please install iproute2 first!'
        echo 'just do "apt install iproute2"'
        exit 1
    fi
    if [ -z $(command -v socat) ]; then
        echo 'socat not found! please install socat first!'
        echo 'just do "apt install socat"'
        exit 1
    fi

    # check docker images, and build / pull
    founds=$(docker images | grep saros-eclipse || true)
    if [ -z "$founds" ]; then
        docker build -t saros-eclipse --build-arg USERNAME=$SAROSUSERNAME --build-arg USERID=$SAROSUSERID .
    fi
    founde=$(docker images | grep rroemhild/ejabberd | grep -v "ejabberd-data" || true)
    if [ -z "$founde" ]; then
        docker pull rroemhild/ejabberd
    fi
    founde=$(docker ps -a -q --filter "name=saros-data-ejabberd" || true)
    if [ -z "$founde" ]; then
        docker create --name saros-data-ejabberd rroemhild/ejabberd-data
    fi
    
    # create networks
    foundnet=$(docker network ls --filter 'name=saros-net' --format='{{.Name}}')
    if [ -z "$foundnet" ]; then
        docker network create --driver=bridge --subnet 192.168.26.0/24 \
           -o com.docker.network.bridge.enable_ip_masquerade=false saros-net
    fi
    foundswt=$(docker network ls --filter 'name=saros-swt' --format='{{.Name}}')
    if [ -z "$foundswt" ]; then
        docker network create --driver=bridge --subnet 192.168.25.0/24 \
           -o com.docker.network.bridge.enable_ip_masquerade=false saros-swt
    fi
    echo 'done'
}

start_ejabberd() {
    running=$(docker ps -a -q --filter "name=saros-ejabberd" )
    if [ -z $running ]; then
        docker run -d --rm \
            --name "saros-ejabberd" \
            --network saros-net \
            --ip 192.168.26.10 \
            --hostname 'xmpp.example.com' \
            --env "XMPP_DOMAIN=example.com" \
            --env "EJABBERD_ADMINS=admin@example.com" \
            --env "EJABBERD_USERS=admin@example.com:password1234 \
                                  alice@example.com:alice bob@example.com:bob\
                                  carl@example.com:carl dave@example.com:dave" \
            --env "TZ=Europe/Berlin" \
            --env "EJABBERD_PROTOCOL_OPTIONS_TLSV1=true" \
            --volumes-from saros-data-ejabberd \
            -v /dev/null:/opt/ejabberd/scripts/post/10_ejabberd_modules_update_specs.sh\
            rroemhild/ejabberd >/dev/null

        #docker network connect --ip 192.168.26.10 saros-net saros-ejabberd
        echo "saros-ejabberd started"
    fi
}

start_client() {
    running=$(docker ps -a -q --filter "name=$1")
    if [ $running ]; then
        echo "$1 already running"
    else
        docker run -d -ti --rm \
               --network saros-net \
               --add-host="example.com:192.168.26.10" \
               --add-host="xmpp.example.com:192.168.26.10" \
               --env DISPLAY=$DISPLAY \
               --env SAROSPATH=$SAROSPATH \
               -v /tmp/.X11-unix:/tmp/.X11-unix \
               -v $SAROSPATH:$SAROSPATH \
               --hostname $1 \
               --name $1 \
               saros-eclipse \
               bash $SAROSPATH/docker/stfclient.sh >/dev/null

        docker network connect --ip ${swthosts[$1]} saros-swt $1
        open_ports $1&
        echo "$1 started"
    fi
}

open_ports() {
    # we need the rmi ports to communicate with the master eclipse on host
    # and we map them into the host, eclipse will never know the difference...
    (sleep 3s
    while true
    do
        ports=$(docker exec $1 ss -ltp 2>/dev/null | grep java | tr -s ' ' | cut -d ' ' -f 4 | cut -d ':' -f 2 | grep -vE "^(9090|6006|7777)" || echo "failed")
        if [ "$ports" = "failed" ]; then
            break
        fi 
        echo "$ports" | while read -r PORT; do
            socat=$(ps aux | grep socat | grep "${swthosts[$1]}:$PORT" | wc -l || true)
            # TODO disown this, simple disown doesn't work...
            if [ "$socat" -eq "0" ]; then
                socat -s TCP4-LISTEN:$PORT TCP4:${swthosts[$1]}:$PORT &
            fi
        done
        sleep 3s
    done)&
}

folder_check() {
    if [ ! -d ../$1 ]; then
        echo -e "\e[31m$1 should be at $SAROSPATH/$1\e[0m"
        exit 1
    fi
}

init() {
    # unused
    apt install socat iproute2
    docker build -t saros-eclipse SAROSPATH/docker
    docker pull rroemhild/ejabberd
    docker network create --driver=bridge --subnet $swtnet \
           -o com.docker.network.bridge.enable_ip_masquerade=false saros-swt
    docker network create --driver=bridge --subnet 192.168.26.0/24 saros-net
}

show_info() {
    running=$(docker ps -a --filter 'name=saros' --format='{{.Names}}' | sort | grep -v saros-data-ejabberd || true)
    if [ -n "$running" ]; then
        echo "Running:"
        echo "$running" | while read -r vm; do
            echo "$vm - interface: $(get_interface $vm || true)"
            if [ -n "$(echo $vm | grep -v ejabberd || true)" ]; then
                ps a | grep socat | grep ${swthosts[$vm]} || true
            fi
        done
    else
        echo "Running: none"
    fi
}

start_bash() {
    echo "# start a bash"
    running=$(docker ps -a --filter 'name=saros' --format='{{.Names}}' | grep -v ejabberd | sort || true)
    if [ -n "$running" ]; then
        PS3='which container: '
        select opt in $running "all"
        do
            case "$opt" in
                "") echo "invalid option" ;;
                "all") 
                    echo "$running" | while read -r vm; do
                        x-terminal-emulator -e "docker exec -it $vm /bin/bash"
                    done
                    break
                    ;;
                 *) x-terminal-emulator -e "docker exec -it $opt /bin/bash"
                    break
                    ;;
           esac
        done
    else
        echo "Running: none"
    fi
}

get_logs() {
    echo "# get logs"
    running=$(docker ps -a --filter 'name=saros' --format='{{.Names}}' | sort | grep -v saros-data-ejabberd || true)
    if [ -n "$running" ]; then
        PS3='which container: '
        select opt in $running "all"
        do
            case "$opt" in
                "") echo "invalid option" ;;
                "all") 
                    echo "$running" | while read -r vm; do
                        x-terminal-emulator -e "bash -c \"while true; do docker logs -f $vm ; sleep 3; done\""
                    done
                    break
                    ;;
                 *) x-terminal-emulator -e "bash -c \"while true; do docker logs -f $opt; sleep 3; done\""
                    break
                    ;;
           esac
        done
    else
        echo "Running: none"
    fi
}

socat_restart() {
    killall socat 2>/dev/null || true
    running=$(docker ps -a --filter 'name=saros' --format='{{.Names}}' | grep -v ejabberd || true)
    if [ -n "$running" ]; then
        echo "$running" | while read -r vm; do
            open_ports $vm
        done
        echo "done"
    else
        echo "none Running"
    fi
}


# gets the eth1 inteface name of docker container (the one for the internal)
get_interface() {
    grep -l \
    "^$(docker exec saros-ejabberd bash -c 'cat /sys/class/net/eth0/iflink' |tr -d '\r')\$"\
    /sys/class/net/veth*/ifindex | cut -d '/' -f 5
}

# call with container_name, upload in mbit, delay is ms
limit_connection() {
    while true
    do
        interface="$(get_interface $1 || true)"
        if [ -z "$interface" ]; then
            sleep 0.5
            continue
        fi

        sudo tc qdisc del dev $interface root 2>/dev/null || true
        sudo tc qdisc add dev $interface root handle 1:0 netem delay $3ms
        sudo tc qdisc add dev $interface parent 1:1 handle 10: tbf rate $2mbit burst 15k latency 50ms
        break
    done
}

clean() {
    docker rm $(docker ps -a -q --filter 'name=saros-data-ejabberd')
    docker network rm saros-swt || true
    docker network rm saros-net || true
    docker rmi -f saros-eclipse || true
    docker rmi -f rroemhild/ejabberd || true
    docker rmi -f rroemhild/ejabberd-data || true
    echo 'done'
    #echo 'to clean up untagged container:'
    #echo '  docker rmi $(docker images -f "dangling=true" -q)'
}

troubleshooting() {
    echo "# troubleshooting:"
    select opt in "get logs" "reinit all" "remove all created container" "back"
    do
        case "$opt" in
            "") echo "invalid option" ;;
            "reinit all")
                quit                
                clean
                check
                ;;
            "remove all created container")
                quit
                clean
                ;;
             "get logs")
                get_logs
                break
                ;;
             "back")
                break
                ;;
       esac
    done
}

quit() {
    echo "shut down all saros container and killall socat processes"
    docker stop $(docker ps -a -q --filter "name=saros") 2>/dev/null || true
    killall socat || true
}

###############################################################################

check

while true
do
echo
echo "########## main menu ##########"
PS3='Please enter your choice: '
options=("start 1 eclipse instance" "start 2 eclipse instances" "start 3 eclipse instances" "start 4 eclipse instances" "show running" "start bash" "restart socat" "troubleshooting" "quit")
select opt in "${options[@]}"
do
    case $opt in
        "start 4 eclipse instances")
            start_client saros-dave
            limit_connection saros-dave 5 15
            ;&
        "start 3 eclipse instances")
            start_client saros-carl
            limit_connection saros-carl 5 15
            ;&
        "start 2 eclipse instances")
            start_client saros-bob
            limit_connection saros-bob 5 15
            ;&
        "start 1 eclipse instance")
            start_client saros-alice
            limit_connection saros-alice 5 15
            start_ejabberd
            limit_connection saros-ejabberd 100 30
            ;;
        "show running")
            show_info
            break
            ;;
        "start bash")
            start_bash
            break
            ;;
        "restart socat")
            socat_restart
            ;;
        "troubleshooting")
            troubleshooting
            break
            ;;
        "quit")
            quit
            exit
            ;;
        *) echo invalid option;;
    esac
done
done

