#!/bin/bash
# Script to install RMQ & MySQL on HDInsight EdgeNode !!!
SAX_HOME="/saxHdInsightApp/"
SAX_INSTALLATION_DIR="/saxHdInsightApp/StreamAnalytix"
JQ="/saxHdInsightApp/jq"
#JQ=/home/impadmin/Desktop/Azure_HDInsightApp/AzureMarketPlace/15-06-2018-scripts/jq
CLUSTER_NAME=$1
HDI_ADMIN=$2
SSH_USER=$3
SSH_PWD=$4
HDI_CREDS="$HDI_ADMIN:$SSH_PWD"
DB_USERNAME="postgres"
DB_PASSWORD="postgres"
DB_DRIVER="org.postgresql.Driver"
#DB_URL="jdbc:postgresql://$HOST_NAME:5432/streamanalytix"
YAML_ZK_PORT=":2181,"
PROP_ZK_PORT="\:2181,"
SPARK_HOME="/usr/hdp/2.6.2.38-1/spark2"
YAML_FILE="$SAX_INSTALLATION_DIR/conf/yaml/env11.yaml"
PROP_FILE="$SAX_INSTALLATION_DIR/conf/config.properties"


echo "--------------------------------------------------------------------------------"
echo "User is : $(whoami)  !!" 
echo "StreamAnalytix @ HDInsight EdgeNode is $(hostname) & ip is $(hostname -i)"
echo "CLUSTER_NAME is : $CLUSTER_NAME" 
echo "HDI_ADMIN is : $HDI_ADMIN" 
echo "SSH_USER is : $SSH_USER" 
echo "SSH_PWD is : $SSH_PWD" 
echo "--------------------------------------------------------------------------------"

#following functions are used to determine headnodes. 
#Returns fully qualified headnode names separated by comma by inspecting hdfs-site.xml.
#Returns empty string in case of errors.
function get_headnodes
{
    hdfssitepath=/etc/hadoop/conf/hdfs-site.xml
    nn1=$(sed -n '/<name>dfs.namenode.http-address.mycluster.nn1/,/<\/value>/p' $hdfssitepath)
    nn2=$(sed -n '/<name>dfs.namenode.http-address.mycluster.nn2/,/<\/value>/p' $hdfssitepath)

    nn1host=$(sed -n -e 's/.*<value>\(.*\)<\/value>.*/\1/p' <<< $nn1 | cut -d ':' -f 1)
    nn2host=$(sed -n -e 's/.*<value>\(.*\)<\/value>.*/\1/p' <<< $nn2 | cut -d ':' -f 1)

    nn1hostnumber=$(sed -n -e 's/hn\(.*\)-.*/\1/p' <<< $nn1host)
    nn2hostnumber=$(sed -n -e 's/hn\(.*\)-.*/\1/p' <<< $nn2host)

    #only if both headnode hostnames could be retrieved, hostnames will be returned
    #else nothing is returned
    if [[ ! -z $nn1host && ! -z $nn2host ]]
    then
        if (( $nn1hostnumber < $nn2hostnumber )); then
                        echo "$nn1host,$nn2host"
        else
                        #echo "$nn2host,$nn1host"
			echo "$nn1host,$nn2host"
        fi
    fi
}

#following functions are used to determine primary headnode.
function get_primary_headnode
{
        headnodes=`get_headnodes`
        echo "`(echo $headnodes | cut -d ',' -f 1)`"
}

#following functions are used to determine secondary headnode.
function get_secondary_headnode
{
        headnodes=`get_headnodes`
        echo "`(echo $headnodes | cut -d ',' -f 2)`"
}

#following functions are used to determine dfs nameservice.
function get_dfs_nameservice
{
    hdfssitepath=/etc/hadoop/conf/hdfs-site.xml
    nameservice=$(sed -n '/<name>dfs.nameservices/,/<\/value>/p' $hdfssitepath)
    nServ=$(sed -n -e 's/.*<value>\(.*\)<\/value>.*/\1/p' <<< $nameservice | cut -d ':' -f 1)
    echo "$nServ"
} 

#set property file value to key
# usage: setProperty $key $value $filename
setProperty(){
  awk -v pat="^$1=" -v value="$1=$2" '{ if ($0 ~ pat) print value; else print $0; }' $3 > $3.tmp
  mv $3.tmp $3
}



echo "-----------------CLUSTER_CONF-----------------"

echo "SAX_INSTALLATION_DIR : $SAX_INSTALLATION_DIR"

SAX_HOST_NAME=$(hostname)
echo "SAX_HOST_NAME : $SAX_HOST_NAME"

#SAX_FULL_HOST_NAME=$(hostname -f)

## get HDInsights cluster name 
#CLUSTER_NAME="$(curl -s -u $HDI_CREDS -X GET $HDI_URLBASE | sed -n 's/.*"cluster_name" : "\([^\"]*\)".*/\1/p')"

echo "SAX_CLUSTER_NAME : $CLUSTER_NAME"

HDINSIGHT_URLBASE="http://$CLUSTER_NAME.azurehdinsight.net/api/v1/clusters/$CLUSTER_NAME"
HDINSIGHT_CLUSTER_URL="http://$CLUSTER_NAME.azurehdinsight.net"
SAX_WEB_URL="http://$SAX_HOST_NAME:8090/StreamAnalytix"

## repalce StreamAnalytix app deatils at at env-config.yaml
sed -ri 's|^(\s*)(sax.installation.dir\s*:\s*/home/impadmin/\s*$)|\1sax.installation.dir: '"$SAX_INSTALLATION_DIR"'|' $YAML_FILE
sed -ri 's|^(\s*)(sax.ui.host\s*:\s*localhost\s*$)|\1sax.ui.host: '"$SAX_HOST_NAME"'|' $YAML_FILE
sed -ri 's|^(\s*)(sax.web.url\s*:\s*http://localhost:8090/StreamAnalytix\s*$)|\1sax.web.url: '"$SAX_WEB_URL"'|' $YAML_FILE
sed -ri 's|^(\s*)(database.dialect\s*:\s*hypersql\s*$)|\1database.dialect: 'postgresql'|' $YAML_FILE

## replace HDInsight cluster deatils at env-config.yaml

sed -ri 's|^(\s*)(url\s*:\s*"http://localhost:8080"\s*$)|\1url: '"$HDINSIGHT_CLUSTER_URL"'|' $YAML_FILE
sed -ri 's|^(\s*)(username\s*:\s*""\s*$)|\1username: '"$HDI_ADMIN"'|' $YAML_FILE
#sed -ri 's|^(\s*)(password\s*:\s*""\s*$)|\1password: '"$HDI_ADMIN_PWD"'|' $YAML_FILE
sed -ri 's|^(\s*)(clustername\s*:\s*""\s*$)|\1clustername: '"$CLUSTER_NAME"'|' $YAML_FILE

echo "-----------------YARN_RESOURCE_MANAGER-----------------"

## get HDInsights YARN resource manager 
YARN_RESOURCE_MANAGER=$(curl -s -u $HDI_CREDS $HDINSIGHT_URLBASE/services/YARN/components/RESOURCEMANAGER \ | $JQ '.host_components[].HostRoles.host_name')
echo "YARN_RESOURCE_MANAGER : $YARN_RESOURCE_MANAGER"

echo "-----------------ZOOKEEPER_CLIENTS-----------------"

## get HDInsights zookeeper clients
PROP_ZK_KEY="zk.hosts"
ZOOKEEPER_CLIENTS=$(curl -s -u $HDI_CREDS $HDINSIGHT_URLBASE/services/ZOOKEEPER/components/ZOOKEEPER_CLIENT \ | $JQ '.host_components[].HostRoles.host_name')
##join('"$ZK_PORT"')'
ZOOKEEPER_HOSTS=$(curl -s -u $HDI_CREDS $HDINSIGHT_URLBASE/services/ZOOKEEPER/components/ZOOKEEPER_CLIENT \ | $JQ -r '.host_components | map(.HostRoles.host_name) | join("##")')

echo "ZOOKEEPER_CLIENTS : $ZOOKEEPER_CLIENTS" 
echo "ZOOKEEPER_HOSTS : $ZOOKEEPER_HOSTS"

# make zkClient string as per env-config.yaml / config.properties

YAML_ZK_HOST=$(for ZK_HOST in ${ZOOKEEPER_HOSTS//##/ }; do echo -n "${ZK_HOST}":2181,; done| sed 's/,$//') ; 
PROP_ZK_HOST=$(for ZK_HOST in ${ZOOKEEPER_HOSTS//##/ }; do echo -n "${ZK_HOST}"'\:2181,'; done| sed 's/,$//') ;
echo "YAML_ZK_HOST : $YAML_ZK_HOST"
echo "PROP_ZK_HOSTS : $PROP_ZK_HOST"

# replace zk.hosts at env-config.yaml
sed -ri 's|^(\s*)(hosts\s*:\s*localhost:2181\s*$)|\1hosts: '"$YAML_ZK_HOST"'|' $YAML_FILE
# replace hosts at config.properties zk.hosts=localhost\:2181
setProperty $PROP_ZK_KEY $PROP_ZK_HOST $PROP_FILE
#sed -ri 's|^(\s*)(zk.hosts\s*:\s*localhost\:2181\s*$)|\zk.hosts: '"$PROP_ZK_HOST"'|' $PROP_FILE

echo "-----------------SAx Database-----------------"

## get JDBC configuration details 
JDBC_PASSWORD=$DB_PASSWORD
JDBC_DRIVER=$DB_DRIVER
JDBC_URL="jdbc:postgresql://$SAX_HOST_NAME:5432/streamanalytix"
JDBC_USERNAME=$DB_USERNAME

echo "JDBC_USERNAME : $JDBC_USERNAME"
echo "JDBC_PASSWORD : $JDBC_PASSWORD"
echo "JDBC_DRIVER : $JDBC_DRIVER"
echo "JDBC_URL : $JDBC_URL"

## replace jdbc configurations at env-config.yaml
sed -ri 's|^(\s*)(driver\s*:\s*org.postgresql.Driver\s*$)|\1driver: '"$JDBC_DRIVER"'|' $YAML_FILE
sed -ri 's|^(\s*)(url\s*:\s*"jdbc:postgresql://localhost:5432/streamanalytix"\s*$)|\1url: '"$JDBC_URL"'|' $YAML_FILE
sed -ri 's|^(\s*)(username\s*:\s*"SA"\s*$)|\1username: '"$JDBC_USERNAME"'|' $YAML_FILE
sed -ri 's|^(\s*)(password\s*:\s*""\s*$)|\1password: '"$JDBC_PASSWORD"'|' $YAML_FILE

echo "-----------------RMQ-----------------"

## get RMQ configuration details 
RABBITMQ_PASSWORD="radmin"
RABBITMQ_PORT="5672"
RABBITMQ_STOMP_URL="http://$SAX_HOST_NAME:15674/stomp"
RABBITMQ_HOST="$SAX_HOST_NAME:5672"
RABBITMQ_VIRTUAL_HOST="/"
RABBITMQ_USERNAME="radmin"
RABBITMQ_WEB_URL="http://$SAX_HOST_NAME:15672"

echo "RABBITMQ_STOMP_URL : $JDBC_USERNAME"
echo "RABBITMQ_WEB_URL : $JDBC_PASSWORD"
echo "RABBITMQ_HOST : $RABBITMQ_HOST"

## replace RMQ configurations at env-config.yaml
sed -ri 's|^(\s*)(host\s*:\s*localhost:5672\s*$)|\1host: '"$RABBITMQ_HOST"'|' $YAML_FILE
sed -ri 's|^(\s*)(port\s*:\s*5672\s*$)|\1port: '"$RABBITMQ_PORT"'|' $YAML_FILE
sed -ri 's|^(\s*)(username\s*:\s*guest\s*$)|\1username: '"$RABBITMQ_USERNAME"'|' $YAML_FILE
sed -ri 's|^(\s*)(password\s*:\s*guest\s*$)|\1password: '"$RABBITMQ_PASSWORD"'|' $YAML_FILE
sed -ri 's|^(\s*)(stompUrl\s*:\s*http://localhost:15674/stomp\s*$)|\1stompUrl: '"$RABBITMQ_STOMP_URL"'|' $YAML_FILE
sed -ri 's|^(\s*)(web.url\s*:\s*http://localhost:15672\s*$)|\1web.url: '"$RABBITMQ_WEB_URL"'|' $YAML_FILE

echo "-----------------METRIC_COLLECTOR-----------------"

## get Ambari Metric Collector configuration details
SAX_METRIC_SERVER="ambari"
AMBARI_COLLECTOR_PORT="6188"
AMBARI_COLLECTOR_HOST=$(curl -s -u $HDI_CREDS $HDINSIGHT_URLBASE/services/AMBARI_METRICS/components/METRICS_COLLECTOR \ | $JQ -r '.host_components[].HostRoles.host_name')

echo "AMBARI_COLLECTOR_HOST : $AMBARI_COLLECTOR_HOST"
echo "SAX_METRIC_SERVER : $SAX_METRIC_SERVER"

## replace ambari metric collector configurations at env-config.yaml
sed -ri 's|^(\s*)(collector.host\s*:\s*localhost\s*$)|\1collector.host: '"$AMBARI_COLLECTOR_HOST"'|' $YAML_FILE
sed -ri 's|^(\s*)(sax.metric.server\s*:\s*ambari\s*$)|\1sax.metric.server: '"$SAX_METRIC_SERVER"'|' $YAML_FILE

echo "-----------------SPARK-----------------"

## get HDInsights SPARK2 configuration details
SPARK_CLUSTER_MANAGER="yarn"
## get HDInsights YARN resource manager 
YARN_RESOURCE_MANAGER=$(curl -s -u $HDI_CREDS $HDINSIGHT_URLBASE/services/YARN/components/RESOURCEMANAGER \ | $JQ '.host_components[].HostRoles.host_name')

## get HDInsights Spark History Server
SPARK_HISTORY_SERVER=$(curl -s -u $HDI_CREDS $HDINSIGHT_URLBASE/services/SPARK2/components/SPARK2_JOBHISTORYSERVER \ | $JQ -r '.host_components[].HostRoles.host_name')
SPARK_HISTORY_SERVER_URI="$SPARK_HISTORY_SERVER:18080"
SPARK_YARN_RESOURCE_MANAGER_HOST=$YARN_RESOURCE_MANAGER
SPARK_JOB_SUBMIT_MODE="spark-submit"


echo "YARN_RESOURCE_MANAGER : $YARN_RESOURCE_MANAGER"
echo "SPARK_YARN_RESOURCE_MANAGER_HOST : $SPARK_YARN_RESOURCE_MANAGER_HOST" 
echo "SPARK_HISTORY_SERVER : $SPARK_HISTORY_SERVER"
## replace SPARK2 configurations at env-config.yaml

sed -ri 's|^(\s*)(home\s*:\s*/usr/hdp/2.4.2.0-258/spark\s*$)|\1home: '"$SPARK_HOME"'|' $YAML_FILE
sed -ri 's|^(\s*)(cluster.manager\s*:\s*"standalone"\s*$)|\1cluster.manager: '"yarn"'|' $YAML_FILE
sed -ri 's|^(\s*)(history.server\s*:\s*"localhost:18080"\s*$)|\1history.server: '"$SPARK_HISTORY_SERVER_URI"'|' $YAML_FILE
sed -ri 's|^(\s*)(resource.manager.host\s*:\s*localhost\s*$)|\1resource.manager.host: '"$SPARK_YARN_RESOURCE_MANAGER_HOST"'|' $YAML_FILE

echo "-----------------HDFS-----------------"

## get HDInsights HDFS configuration details
PRIMARY_HEAD_NODE=`get_primary_headnode`
SECONDARY_HEAD_NODE=`get_secondary_headnode`
HADOOP_DFS_NAMESERVICE=`get_dfs_nameservice`

HADOOP_HDFS_URI="hdfs://$HADOOP_DFS_NAMESERVICE"
HADOOP_DFS_NAMENODE1_DETAILS="nn1,$PRIMARY_HEAD_NODE:8020"
HADOOP_DFS_NAMENODE2_DETAILS="nn2,$SECONDARY_HEAD_NODE:8020"

echo "PRIMARY_HEAD_NODE : $PRIMARY_HEAD_NODE"
echo "SECONDARY_HEAD_NODE : $SECONDARY_HEAD_NODE"
echo "HADOOP_DFS_NAMESERVICE : $HADOOP_DFS_NAMESERVICE"
echo "HADOOP_HDFS_URI : $HADOOP_HDFS_URI"
echo "HADOOP_DFS_NAMENODE1_DETAILS : $HADOOP_DFS_NAMENODE1_DETAILS"
echo "HADOOP_DFS_NAMENODE2_DETAILS : $HADOOP_DFS_NAMENODE2_DETAILS"
## replace HDFS configurations at env-config.yaml

sed -ri 's|^(\s*)(ha.enabled\s*:\s*false\s*$)|\1ha.enabled: 'true'|' $YAML_FILE
sed -ri 's|^(\s*)(hdfs.uri\s*:\s*"hdfs://localhost:9000/"\s*$)|\1hdfs.uri: '"$HADOOP_HDFS_URI"'|' $YAML_FILE
sed -ri 's|^(\s*)(dfs.nameservices\s*:\s*""\s*$)|\1dfs.nameservices: '"$HADOOP_DFS_NAMESERVICE"'|' $YAML_FILE
sed -ri 's|^(\s*)(dfs.namenode1.details\s*:\s*""\s*$)|\1dfs.namenode1.details: '"$HADOOP_DFS_NAMENODE1_DETAILS"'|' $YAML_FILE
sed -ri 's|^(\s*)(dfs.namenode2.details\s*:\s*""\s*$)|\1dfs.namenode2.details: '"$HADOOP_DFS_NAMENODE2_DETAILS"'|' $YAML_FILE

echo "-----------------HIVE-----------------" 

# get hive meta store hostname
HIVE_META_STORE_HOST=$(curl -s -u $HDI_CREDS $HDINSIGHT_URLBASE/services/HIVE/components/HIVE_METASTORE \ | $JQ '.host_components[].HostRoles.host_name')
HIVE_META_STORE_URI="thrift://$HIVE_META_STORE_HOST:9083"

# get hiveServer2 hostname
HIVE_SERVER2_HOST=$(curl -s -u $HDI_CREDS $HDINSIGHT_URLBASE/services/HIVE/components/HIVE_SERVER \ | $JQ '.host_components[].HostRoles.host_name')
HIVE_SERVER2_URI="jdbc:hive2://$HIVE_SERVER2_HOST:10000"

echo "HIVE_META_STORE_HOST : $HIVE_META_STORE_HOST"
echo "HIVE_META_STORE_URI : $HIVE_META_STORE_URI"
echo "HIVE_SERVER2_HOST : $HIVE_SERVER2_HOST"
echo "HIVE_SERVER2_URI : $HIVE_SERVER2_URI"
## replace HIVE configurations at env-config.yaml
sed -ri 's|^(\s*)(metaStoreURI\s*:\s*thrift://localhost:9083\s*$)|\1metaStoreURI: '"$HIVE_META_STORE_URI"'|' $YAML_FILE
sed -ri 's|^(\s*)(hiveServer2\s*:\s*jdbc:hive2://localhost:10000\s*$)|\1hiveServer2: '"$HIVE_SERVER2_URI"'|' $YAML_FILE

echo "-----------------OOZIE-----------------"

## get HDInsights Oozie configuration details
OOZIE_SERVER_HOST=$(curl -s -u $HDI_CREDS $HDINSIGHT_URLBASE/services/OOZIE/components/OOZIE_SERVER \ | $JQ -r '.host_components[].HostRoles.host_name')
OOZIE_SERVER_URL="http://$OOZIE_SERVER_HOST:11000/oozie"
OOZIE_LIB_PATH="/user/oozie/share/lib"
OOZIE_NAMENODE_URI="hdfs://$PRIMARY_HEAD_NODE:9000/"
OOZIE_JOBTRACKER_URL="$OOZIE_SERVER_HOST:8032"
OOZIE_WORKFLOW_NOTIFICATION_URL="/workflow/ackWorkflowStatus/${tenantId}/$jobId/$status"
OOZIE_ACTION_NOTIFICATION_URL="/workflow/ackWorkflowActionStatus/${tenantId}/$jobId/$nodeName/$status"
OOZIE_COORDINATOR_ACTION_NOTIFUCATION_URL="/workflow/ackWorkflowActionStatus/${tenantId}/$jobId/$actionId/$status"


echo "OOZIE_SERVER_HOST : $OOZIE_SERVER_HOST"
echo "OOZIE_SERVER_URL : $OOZIE_SERVER_URL"
echo "OOZIE_NAMENODE_URI : $OOZIE_NAMENODE_URI"
echo "OOZIE_JOBTRACKER_URL : $OOZIE_JOBTRACKER_URL"
## replace Oozie configurations at env-config.yaml

sed -ri 's|^(\s*)(server.url\s*:\s*"http://localhost:11000/oozie/"\s*$)|\1server.url: '"$OOZIE_SERVER_URL"'|' $YAML_FILE
sed -ri 's|^(\s*)(namenodeUri\s*:\s*"hdfs://localhost:9000/"\s*$)|\1namenodeUri: '"$OOZIE_NAMENODE_URI"'|' $YAML_FILE
sed -ri 's|^(\s*)(jobtrackerURL\s*:\s*"localhost:8032"\s*$)|\1jobtrackerURL: '"$OOZIE_JOBTRACKER_URL"'|' $YAML_FILE

echo "env-config.yaml & config.properties file updation completed successfully !!"

##echo "-----------------AMBARI_SERVICES-----------------"

##AMBARI_SERVICES=$(curl -u $HDI_CREDS -X GET $HDINSIGHT_URLBASE/services | grep service_name| awk -F":" '{print $2}')
##echo "AMBARI_SERVICES >>>>>>>>> $AMBARI_SERVICES"
##echo "--------------------------------------------------------------------------------"

echo "--------------------------------------------------------------------------------" 