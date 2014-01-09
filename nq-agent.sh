#!/bin/sh
#
# NodeQuery Agent
#
# @version		0.7.1
# @date			2014-01-09
# @copyright	(c) 2014 http://nodequery.com
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Agent version
version="0.7.1"

# Root required
if [ $(id -u) != "0" ];
then
	echo "Error: You need to be root to run the NodeQuery agent."
	exit 1
fi

# Authentication required
if [ -f /etc/nodequery/nq-auth.log ]
then
	auth=($(cat /etc/nodequery/nq-auth.log))
else
	echo "Error: Authentication log is missing."
	exit 1
fi

# Prepare values
function prep ()
{
	echo "$1" | sed -e 's/^ *//g' -e 's/ *$//g' | sed -n '1 p'
}

# Base64 values
function base ()
{
	echo "$1" | tr -d '\n' | base64 | tr -d '=' | tr -d '\n'
}

# Integer values
function int ()
{
	echo ${1/\.*}
}

# Filter numeric
function num ()
{
	case $1 in
	    ''|*[!0-9\.]*) echo 0 ;;
	    *) echo $1 ;;
	esac
}

# Agent version
version=$(prep "$version")

# System uptime
uptime=$(prep $(int "$(cat /proc/uptime | awk '{ print $1 }')"))

# Login session count
sessions=$(prep "$(who | wc -l)")

# Process count
processes=$(prep "$(ps -Al | wc -l)")

# OS details
os_kernel=$(prep "$(uname -r)")
os_name=$(prep "$(cat /etc/*release | grep '^NAME=\|^DISTRIB_ID=' | awk -F\= '{ print $2 }' | tr -d '"')")

if [ -z "$os_name" ]
then
	if [ -e /etc/redhat-release ]
	then
		os_name=$(prep "$(cat /etc/redhat-release)")
	fi
	
	if [ -z "$os_name" ]
	then
		os_name=$(prep "$(uname -s)")
	fi
fi

case $(uname -m) in
x86_64)
	os_arch=$(prep "x64")
	;;
i*86)
	os_arch=$(prep "x86")
	;;
*)
	os_arch=$(prep "$(uname -m)")
	;;
esac

# CPU details
cpu_name=$(prep "$(cat /proc/cpuinfo | grep 'model name' | awk -F\: '{ print $2 }')")
cpu_cores=$(prep "$(($(cat /proc/cpuinfo | grep 'model name' | awk -F\: '{ print $2 }' | sed -e :a -e '$!N;s/\n/\|/;ta' | tr -cd \| | wc -c)+1))")
cpu_freq=$(prep "$(cat /proc/cpuinfo | grep 'cpu MHz' | awk -F\: '{ print $2 }')")

# RAM usage
ram_total=$(prep "$(free -b | grep 'Mem:' | awk '{ print $2 }')")
ram_usage=$(prep "$(free -b | grep 'cache:' | awk '{ print $3 }')")

# Swap usage
swap_total=$(prep "$(free -b | grep 'Swap:' | awk '{ print $2 }')")
swap_usage=$(prep "$(free -b | grep 'Swap:' | awk '{ print $3 }')")

# Disk usage
for disk_loop in 0 1
do
	if [[ $disk_loop == "0" ]]
	then
		disk=($(df -B 1 | grep '^/' | awk '{ print $2 }' | sed -e :a -e '$!N;s/\n/ /;ta'))
	else
		disk=($(df -B 1 | grep '^/' | awk '{ print $3 }' | sed -e :a -e '$!N;s/\n/ /;ta'))
	fi
		
	disk_temp=0
		
	if [[ ${#disk[@]} != "1" ]]
	then
		for i in "${!disk[@]}"
		do
			if [[ ${#disk[@]} > "$(($i+1))" ]]
			then
				disk_temp=$(($disk_temp+$((${disk[$i]}+${disk[$(($i+1))]}))))
			fi
		done
	else
		disk_temp=${disk[0]}
	fi
	
	if [[ $disk_loop == "0" ]]
	then
		disk_total=$(prep "$disk_temp")
	else
		disk_usage=$(prep "$disk_temp")
	fi
done

# Disk array
disk_array=$(prep "$(df -B 1 | grep '^/' | awk '{ print $1" "$2" "$3";" }' | sed -e :a -e '$!N;s/\n/ /;ta')")

# Network interface
nic=$(prep "$(ip route get 8.8.8.8 | grep dev | awk -F'dev' '{ print $2 }' | awk '{ print $1 }')")

if [ -z $nic ]
then
	nic=$(prep "$(ip link show | grep 'eth[0-9]' | awk '{ print $2 }' | tr -d ':')")
fi

# IP addresses and network usage
if [ $nic ]
then
	ipv4=$(prep "$(ip addr show $nic | grep 'inet ' | awk '{ print $2 }' | awk -F\/ '{ print $1 }' | grep -v '^127')")
	ipv6=$(prep "$(ip addr show $nic | grep 'inet6 ' | awk '{ print $2 }' | awk -F\/ '{ print $1 }' | grep -v '^::' | grep -v '^0000:' | grep -v '^fe80:')")
	
	if [ -d /sys/class/net/$nic/statistics ]
	then
		rx=$(prep "$(cat /sys/class/net/$nic/statistics/rx_bytes)")
		tx=$(prep "$(cat /sys/class/net/$nic/statistics/tx_bytes)")
	else
		rx=$(prep "$(ip -s link show $nic | grep '[0-9]*' | grep -v '[A-Za-z]' | awk '{ print $1 }' | sed -n '1 p')")
		tx=$(prep "$(ip -s link show $nic | grep '[0-9]*' | grep -v '[A-Za-z]' | awk '{ print $1 }' | sed -n '2 p')")
	fi
	
	if [ -z $ipv4 ]
	then
		ipv4="N/A"
	fi
	
	if [ -z $ipv6 ]
	then
		ipv6="N/A"
	fi
	
	if [ -z $rx ]
	then
		rx="0"
	fi
	
	if [ -z $tx ]
	then
		tx="0"
	fi
else
	ipv4="N/A"
	ipv6="N/A"
	rx="0"
	tx="0"
fi

# Average system load
load=$(prep "$(cat /proc/loadavg | awk '{ print $1" "$2" "$3 }')")

# Detailed system load calculation
time=$(date +%s)
stat=($(cat /proc/stat | head -n1 | sed 's/cpu //'))
cpu=$((${stat[0]}+${stat[1]}+${stat[2]}+${stat[3]}))
io=$((${stat[3]}+${stat[4]}))
idle=${stat[3]}

if [ -e /etc/nodequery/nq-data.log ]
then
	data=($(cat /etc/nodequery/nq-data.log))
	interval=$(($time-${data[0]}))
	cpu_gap=$(($cpu-${data[1]}))
	io_gap=$(($io-${data[2]}))
	idle_gap=$(($idle-${data[3]}))
	
	if [[ $cpu_gap > "0" ]]
	then
		load_cpu=$(((1000*($cpu_gap-$idle_gap)/$cpu_gap+5)/10))
	else
		load_cpu="0"
	fi
	
	if [[ $io_gap > "0" ]]
	then
		load_io=$(((1000*($io_gap-$idle_gap)/$io_gap+5)/10))
	else
		load_io="0"
	fi
	
	rx_gap=$(($rx-${data[4]}))
	tx_gap=$(($tx-${data[5]}))
	
	if [[ $rx_gap < "0" ]]
	then
		rx_gap="0"
	fi
	
	if [[ $tx_gap < "0" ]]
	then
		tx_gap="0"
	fi
else
	rx_gap="0"
	tx_gap="0"
	load_cpu="0"
	load_io="0"
fi

# System load cache
echo "$time $cpu $io $idle $rx $tx" > /etc/nodequery/nq-data.log

# Prepare load variables
rx_gap=$(prep "$rx_gap")
tx_gap=$(prep "$tx_gap")
load_cpu=$(prep "$load_cpu")
load_io=$(prep "$load_io")

# Get network latency
ping_eu=$(prep $(num "$(ping -c 2 -w 2 ping-eu.nodequery.com | grep rtt | cut -d'/' -f4 | awk '{ print $3 }')"))
ping_us=$(prep $(num "$(ping -c 2 -w 2 ping-us.nodequery.com | grep rtt | cut -d'/' -f4 | awk '{ print $3 }')"))
ping_as=$(prep $(num "$(ping -c 2 -w 2 ping-as.nodequery.com | grep rtt | cut -d'/' -f4 | awk '{ print $3 }')"))

# Build data for post
data_array=("$version" "$uptime" "$sessions" "$processes" "$os_kernel" "$os_name" "$os_arch" "$cpu_name" "$cpu_cores" "$cpu_freq" "$ram_total" "$ram_usage" "$swap_total" "$swap_usage" "$disk_array" "$disk_total" "$disk_usage" "$nic" "$ipv4" "$ipv6" "$rx" "$tx" "$rx_gap" "$tx_gap" "$load" "$load_cpu" "$load_io" "$ping_eu" "$ping_us" "$ping_as")
data_post="token=${auth[0]}&secret=${auth[1]}&data="
IFS=""

for item in ${data_array[*]}
do
	data_post="$data_post$(base $item) "
done

# API Request
wget -q -o /dev/null -O /etc/nodequery/nq-agent.log -T 60 --post-data "$data_post" https://nodequery.com/api/agent.json

# Finished
exit 1
