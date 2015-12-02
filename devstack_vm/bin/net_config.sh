MYIP=$(/sbin/ifconfig eth0 2>/dev/null| grep "inet addr:" 2>/dev/null| sed 's/.*inet addr://g;s/ .*//g' 2>/dev/null)

set +e
sudo ovs-vsctl del-br br-eth1
set -e

sudo ovs-vsctl --may-exist add-br br-ex
sudo ovs-vsctl --may-exist add-port br-ex eth0
sudo ip addr del $MYIP/23 brd 10.0.3.255 dev eth0
sudo ip addr add $MYIP/23 brd 10.0.3.255 dev br-ex
sudo ifconfig br-ex up
sudo ip r replace default via 10.0.2.1 dev br-ex
