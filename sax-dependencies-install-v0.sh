#!/bin/bash
# Script to install RMQ & MySQL on HDInsight EdgeNode !!!
SAX_HOME="/saxHdInsightApp/"
SAX_INSTALLATION_DIR="/saxHdInsightApp/StreamAnalytix"
echo "--------------------------------------------------------------------------------"
echo "Installing StreamAnalytix dependencies RMQ & MySQL"
echo "User is : $(whoami)  !!" 
echo "StreamAnalytix @ HDInsight EdgeNode : Today is $(date)" 
echo "--------------------------------------------------------------------------------"
# echo "---------------------- Install & Configure RabbitMQ ----------------------"
echo "Installing RabbitMQ Server on Edge Node with user : $(whoami) " 
apt-get update  # To get the latest package lists
apt-get -y install rabbitmq-server
service rabbitmq-server restart
rabbitmq-plugins enable rabbitmq_management
service rabbitmq-server restart
#echo "User is : $(whoami)  !!" 
echo "RabbitMQ installation done.. Adding new user to RMQ"
rabbitmqctl add_user radmin radmin
rabbitmqctl set_user_tags radmin administrator
rabbitmqctl set_permissions -p / radmin ".*" ".*" ".*" 
service rabbitmq-server restart
echo "Restarted RMQ , after adding new radmin user !!" 

echo "---------------------- Install JQ ----------------------"
apt-get -y install jq


echo "--------------------------------------------------------------------------------"
