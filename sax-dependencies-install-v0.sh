#!/bin/bash
# Script to install RMQ & MySQL on HDInsight EdgeNode !!!
SAX_HOME="/saxHdInsightApp/"
SAX_INSTALLATION_DIR="/saxHdInsightApp/StreamAnalytix"
DB_NAME="streamanalytix"
DB_USER="saxpostgres"
DB_PWD="saxpostgres"
PG_HBA_CONF_PATH="/etc/postgresql/9.5/main/pg_hba.conf"
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

echo "---------------------- Install & Configure Postgres ----------------------"

# Restart postgress sql
sudo service postgresql restart

sudo -u postgres psql -c "CREATE USER $DB_USER with PASSWORD '$DB_PWD';"

# update pgsql configuration
echo "Updating postgres configuration on pg_hba.conf & postgresql.conf " 
sudo cp $PG_HBA_CONF_PATH /etc/postgresql/9.5/main/pg_hba_1.conf
sudo truncate -s 0 $PG_HBA_CONF_PATH

echo "local   all             postgres                                peer" | sudo tee -a $PG_HBA_CONF_PATH
echo "# TYPE  DATABASE        USER            ADDRESS                 METHOD" | sudo tee -a $PG_HBA_CONF_PATH
echo "local   all             postgres                                peer" | sudo tee -a $PG_HBA_CONF_PATH
echo "host    all             all             all                     md5" | sudo tee -a $PG_HBA_CONF_PATH
echo "host    all             all             ::1/128                 md5" | sudo tee -a $PG_HBA_CONF_PATH

echo "# Allow replication connections from localhost, by a user with the replication privilege." | sudo tee -a $PG_HBA_CONF_PATH

echo "local  all  ambari,mapred md5" | sudo tee -a $PG_HBA_CONF_PATH
echo "host  all   ambari,mapred 0.0.0.0/0  md5" | sudo tee -a $PG_HBA_CONF_PATH
echo "host  all   ambari,mapred ::/0 md5" | sudo tee -a $PG_HBA_CONF_PATH

# Restart postgress sql
sudo service postgresql restart

sudo -u postgres psql << EOF
create database $DB_NAME;
grant all privileges on database $DB_NAME to $DB_USER;
EOF


# Run StreamAnalytix DB scripts
echo "Running DDL/DML scripts for streamanalytix "

sudo -u postgres psql "dbname='$DB_NAME' user='$DB_USER' password='$DB_PWD'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_1.2/streamanalytix_DDL.sql

sudo -u postgres psql "dbname='$DB_NAME' user='$DB_USER'' password='$DB_PWD'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_1.2/streamanalytix_DML.sql

sudo -u postgres psql "dbname='$DB_NAME' user='$DB_USER'' password='$DB_PWD'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_2.0/streamanalytix_DDL.sql

sudo -u postgres psql "dbname='$DB_NAME' user='$DB_USER'' password='$DB_PWD'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_2.0/streamanalytix_DML.sql

sudo -u postgres psql "dbname='$DB_NAME' user='$DB_USER'' password='$DB_PWD'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_2.2/streamanalytix_DDL.sql

sudo -u postgres psql "dbname='$DB_NAME' user='$DB_USER'' password='$DB_PWD'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_2.2/streamanalytix_DML.sql

sudo -u postgres psql "dbname='$DB_NAME' user='$DB_USER'' password='$DB_PWD'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_3.0/streamanalytix_DDL.sql

sudo -u postgres psql "dbname='$DB_NAME' user='$DB_USER'' password='$DB_PWD'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_3.0/streamanalytix_DML.sql

sudo -u postgres psql "dbname='$DB_NAME' user='$DB_USER'' password='$DB_PWD'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_3.0/Ticket_DML.sql

echo "Installing Postgres & DB Scripts Completed" 

echo "---------------------- ---------------------- ----------------------"
