#!/bin/bash
#
# NodeQuery Agent Installation Script
#
# @version		1.0.6
# @date			2014-07-30
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

# Helper Functions
function printRed() {
	echo -e "\e[31m${*}\e[0m"
}

function printGreen() {
	printf "\e[32m${1}\e[0m"
}

function printBold() {
	printf "\033[1m${1}\033[0m"
}

function fail() {
  printRed $1
  exit 1
}

# Prepare output
printBold "|\n| NodeQuery Installer\n| ===================\n"

# Root required
if [ $(id -u) != "0" ];
then
	fail "|\n| Error: You need to be root to install the NodeQuery agent\n|\tThe agent itself will NOT be running as root but instead under its own non-privileged user\n|"
fi

# Parameters required
if [ $# -lt 1 ]
then
	fail "|\n| Usage: bash $0 'token'\n|"
fi

# Check if crontab is installed
if [ ! -n "$(command -v crontab)" ]
then

	# Confirm crontab installation
	echo "|" && read -p "| Crontab is required and could not be found. Do you want to install it? [Y/n] " input_variable_install

	# Attempt to install crontab
	if [ -z $input_variable_install ] || [ $input_variable_install == "Y" ] || [ $input_variable_install == "y" ]
	then
		if [ -n "$(command -v apt-get)" ]
		then
			printBold "| Notice: Installing required package 'cron' via 'apt-get': "
			(
		    apt-get -y update
		    apt-get -y install cron
			) > /dev/null && printGreen "OK" || fail "FAIL"
		elif [ -n "$(command -v yum)" ]
		then
			printBold "| Notice: Installing required package 'cron' via 'yum': "
		  yum -y install cronie

		  if [ ! -n "$(command -v crontab)" ]
		  then
				printBold "| Notice: Installing required package 'vixie-cron' via 'yum': "
				(
		  		yum -y install vixie-cron
				) > /dev/null && printGreen "OK" || fail "FAIL"
		  fi
		elif [ -n "$(command -v pacman)" ]
		then
			printBold "| Notice: Installing required package 'cronie' via 'pacman': "
			(
		  	pacman -S --noconfirm cronie
			) > /dev/null && printGreen "OK" || fail "FAIL"
		fi
	fi

	if [ ! -n "$(command -v crontab)" ]
	then
    # Show error
    fail "|\tError: Crontab is required and could not be installed\n"
	fi
fi

# Check if cron is running
if [ -z "$(ps -Al | grep cron | grep -v grep)" ]
then

	# Confirm cron service
	echo "|" && read -p "| Cron is available but not running. Do you want to start it? [Y/n] " input_variable_service

	# Attempt to start cron
	if [ -z $input_variable_service ] || [ $input_variable_service == "Y" ] || [ $input_variable_service == "y" ]
	then
		if [ -n "$(command -v apt-get)" ]
		then
			printBold "| Notice: Starting 'cron' via 'service': "
			(
				service cron start
			) > /dev/null && printGreen "OK" || fail "FAIL"
		elif [ -n "$(command -v yum)" ]
		then
			printBold "| Notice: Starting 'crond' via 'service': "
			(
				chkconfig crond on
				service crond start
			) > /dev/null && printGreen "OK" || fail "FAIL"
		elif [ -n "$(command -v pacman)" ]
		then
			printBold "| Notice: Starting 'cronie' via 'systemctl': "
			(
		    systemctl start cronie
		    systemctl enable cronie
			) > /dev/null && printGreen "OK" || fail "FAIL"
		fi
	fi

	# Check if cron was started
	if [ -z "$(ps -Al | grep cron | grep -v grep)" ]
	then
		# Show error
		fail "|\tError: Cron is available but could not be started\n"
	fi
fi

# Attempt to delete previous agent
if [ -f /etc/nodequery/nq-agent.sh ]
then
	# Remove agent dir
	rm -Rf /etc/nodequery

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
printBold "\n| Downloading nq-agent.sh to /etc/nodequery\n|\n|   + $(wget -nv -o /dev/stdout -O /etc/nodequery/nq-agent.sh --no-check-certificate https://raw.github.com/nodequery/nq-agent/master/nq-agent.sh)\n"

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
	crontab -u nodequery -l 2>/dev/null | { cat; echo "*/3 * * * * bash /etc/nodequery/nq-agent.sh > /etc/nodequery/nq-cron.log 2>&1"; } | crontab -u nodequery -

	# Show success
	printBold "| ================================================\n"
	printGreen "| Success: The NodeQuery agent has been installed\n"
	printBold "| ================================================\n"

	# Attempt to delete installation script
	if [ -f $0 ]
	then
		rm -f $0
	fi
else
	# Show error
	fail "\tError: The NodeQuery agent could not be installed\n"
fi
