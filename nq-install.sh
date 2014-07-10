#!/bin/bash
#
# NodeQuery Agent Installation Script
#
# @version		1.0.4
# @date			2014-07-08
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

# Prepare output
echo -e "|\n|   NodeQuery Installer\n|   ===================\n|"

# Root required
if [ $(id -u) != "0" ];
then
	echo -e "|   Error: You need to be root to install the NodeQuery agent\n|"
	echo -e "|          The agent itself will NOT be running as root but instead under its own non-privileged user\n|"
	exit 1
fi

# Parameters required
if [ $# -lt 1 ]
then
	echo -e "|   Usage: bash $0 'token'\n|"
	exit 1
fi

# Check if crontab is installed
if [ ! -n "$(command -v crontab)" ]
then
	# Attempt to install crontab
	if [ -n "$(command -v apt-get)" ]
	then
		echo -e "|\n|   Notice: Installing required package 'cron' via 'apt-get'"
	    apt-get -y update
	    apt-get -y install cron
	    service cron start
	elif [ -n "$(command -v yum)" ]
	then
		echo -e "|\n|   Notice: Installing required package 'cronie' via 'yum'"
	    yum -y install cronie
	    chkconfig crond on
	    service crond start
	elif [ -n "$(command -v pacman)" ]
	then
		echo -e "|\n|   Notice: Installing required package 'cronie' via 'pacman'"
	    pacman -S --noconfirm cronie
	    systemctl start cronie
	    systemctl enable cronie
	else
	    # Show error
	    echo -e "|\n|   Error: Crontab is required and could not be installed\n|"
	    exit 1
	fi
else
	# Check if cron is running
	if [ -z "$(ps -Al | grep cron | grep -v grep)" ]
	then
		# Attempt to start cron
		if [ -n "$(command -v apt-get)" ]
		then
			echo -e "|\n|   Notice: Starting 'cron' via 'service'"
			service cron start
		elif [ -n "$(command -v yum)" ]
		then
			echo -e "|\n|   Notice: Starting 'crond' via 'service'"
			chkconfig crond on
			service crond start
		elif [ -n "$(command -v pacman)" ]
		then
			echo -e "|\n|   Notice: Starting 'cronie' via systemctl"
		    systemctl start cronie
		    systemctl enable cronie
		fi
		
		# Check if cron was started
		if [ -z "$(ps -Al | grep cron | grep -v grep)" ]
		then
			# Show warning
			echo -e "|\n|   Warning: Cron is available but could not be started\n|"
		fi
	fi
fi

# Attempt to delete previous agent
if [ -f /etc/nodequery/nq-agent.sh ]
then
	# Remove agent dir
	rm -R /etc/nodequery

	# Remove cron entry and user
	if id -u nodequery >/dev/null 2>&1
	then
		(crontab -u nodequery -l | grep -v "/etc/nodequery/nq-agent.sh") | crontab -u nodequery - && userdel nodequery
	else
		(crontab -u root -l | grep -v "/etc/nodequery/nq-agent.sh") | crontab -u root -
	fi
fi

# Create agent dir
mkdir -p /etc/nodequery

# Download agent
echo -e "|   Downloading nq-agent.sh to /etc/nodequery\n|\n|   + $(wget -nv -o /dev/stdout -O /etc/nodequery/nq-agent.sh --no-check-certificate https://raw.github.com/nodequery/nq-agent/master/nq-agent.sh)"

if [ -f /etc/nodequery/nq-agent.sh ]
then
	# Create auth file
	echo "$1" > /etc/nodequery/nq-auth.log
	
	# Create user
	useradd nodequery -r -d /etc/nodequery -s /bin/false
	
	# Modify user permissions
	chown -R nodequery:nodequery /etc/nodequery && chmod -R 700 /etc/nodequery
	
	# Modify ping permissions
	chmod +s `type -p ping`

	# Configure cron
	crontab -u nodequery -l 2>/dev/null | { cat; echo "*/3 * * * * bash /etc/nodequery/nq-agent.sh > /etc/nodequery/nq-cron.log"; } | crontab -u nodequery -
	
	# Show success
	echo -e "|\n|   Success: The NodeQuery agent has been installed\n|"
	
	# Attempt to delete installation script
	if [ -f $0 ]
	then
		rm -f $0
	fi
else
	# Show error
	echo -e "|\n|   Error: The NodeQuery agent could not be installed\n|"
fi
