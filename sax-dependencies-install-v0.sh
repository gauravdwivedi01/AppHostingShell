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

echo "---------------------- Install & Configure Postgres ----------------------"
echo "Installing Postgres Server 9.3 on Edge Node with user : $(whoami) "

sudo bash -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' >> /etc/apt/sources.list.d/pgdg.list"
#sudo bash -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main' >> /etc/apt/sources.list.d/pgdg.list"
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
apt-get -y update
apt-get -y install postgresql-10 
#postgres psql -U postgres -d postgres -c "alter user postgres with password 'postgres';"
sudo -u postgres psql -c "alter user postgres with password 'postgres';"
service postgresql restart
echo "Postgres installation completed"

# update pgsql configuration
echo "Updating postgres configuration on pg_hba.conf & postgresql.conf " 
sudo cp /etc/postgresql/10/main/pg_hba.conf /etc/postgresql/10/main/pg_hba_1.conf
sudo truncate -s 0 /etc/postgresql/10/main/pg_hba.conf

echo "local   all             postgres                                peer" | sudo tee -a /etc/postgresql/10/main/pg_hba.conf
echo "# TYPE  DATABASE        USER            ADDRESS                 METHOD" | sudo tee -a /etc/postgresql/10/main/pg_hba.conf
echo "local   all             all                                     md5" | sudo tee -a /etc/postgresql/10/main/pg_hba.conf
echo "host    all             all             all                     md5" | sudo tee -a /etc/postgresql/10/main/pg_hba.conf
echo "host    all             all             ::1/128                 md5" | sudo tee -a /etc/postgresql/10/main/pg_hba.conf

echo "listen_addresses = '*'" | sudo tee -a /etc/postgresql/10/main/postgresql.conf

# Restart postgress sql
sudo service postgresql restart

# create data for application
sudo -u postgres psql << EOF
create database streamanalytix;
grant all privileges on database streamanalytix to postgres;
EOF

# Run StreamAnalytix DB scripts
echo "Running DDL/DML scripts for streamanalytix "

sudo -u postgres psql "dbname='streamanalytix' user='postgres' password='postgres'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_1.2/streamanalytix_DDL.sql

sudo -u postgres psql "dbname='streamanalytix' user='postgres' password='postgres'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_1.2/streamanalytix_DML.sql

sudo -u postgres psql "dbname='streamanalytix' user='postgres' password='postgres'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_2.0/streamanalytix_DDL.sql

sudo -u postgres psql "dbname='streamanalytix' user='postgres' password='postgres'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_2.0/streamanalytix_DML.sql

sudo -u postgres psql "dbname='streamanalytix' user='postgres' password='postgres'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_2.2/streamanalytix_DDL.sql

sudo -u postgres psql "dbname='streamanalytix' user='postgres' password='postgres'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_2.2/streamanalytix_DML.sql

sudo -u postgres psql "dbname='streamanalytix' user='postgres' password='postgres'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_3.0/streamanalytix_DDL.sql

sudo -u postgres psql "dbname='streamanalytix' user='postgres' password='postgres'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_3.0/streamanalytix_DML.sql

sudo -u postgres psql "dbname='streamanalytix' user='postgres' password='postgres'" -f $SAX_INSTALLATION_DIR/db_dump/pgsql_3.0/Ticket_DML.sql

echo "Installing Postgres & DB Scripts Completed"

echo "StreamAnalytix dependencies RMQ & MySQL & PGSQl installation completed at EdgeNode "
echo "--------------------------------------------------------------------------------"
