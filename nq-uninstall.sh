#!/bin/bash
#
# NodeQuery Agent Removal Script
#
# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Prepare output
echo -e "|\n|   NodeQuery Uninstaller\n|   ===================\n|"

# Root required
if [ $(id -u) != "0" ];
then
	echo -e "|   Error: You need to be root to uninstall the NodeQuery agent\n|"
	exit 1
fi

# Attempt to delete previous agent
if [ -f /etc/nodequery/nq-agent.sh ]
then

	# Remove cron entry and user
	if id -u nodequery >/dev/null 2>&1
	then
		# Show Feedback
		echo -e "|\n|   nodequery user [FOUND]\n|"
	
		(crontab -u nodequery -l | grep -v "/etc/nodequery/nq-agent.sh") | crontab -u nodequery - && userdel nodequery
		
		# Show Feedback
		echo -e "|\n|   nodequery user & cron [DELETED]\n|"
	fi
	
	# Show Feedback
	echo -e "|\n|   /etc/nodequery/nq-agent.sh [FOUND]\n|"
	
	# Remove agent dir
	rm -Rf /etc/nodequery
	
	# Show Feedback
	echo -e "|\n|   /etc/nodequery [DELETED]\n|"
	
else 

	# Show Feedback
	echo -e "|\n|   /etc/nodequery/nq-agent.sh not found\n|"

fi
