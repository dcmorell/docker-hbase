DOCKER_NETWORK = docker-hbase-hivegit_default
ENV_FILE = hadoop.env
hadoop_branch := 2.0.0-hadoop2.7.4-java8
HBASE_VERSION := 1.2.0
HIVE_VERSION := 1.1.0

default: build

build:
	docker build --build-arg HBASE_VERSION=${HBASE_VERSION} -t bde2020/hbase-base:$(HBASE_VERSION) ./base
	docker build -t bde2020/hbase-master:$(HBASE_VERSION) ./hmaster
	docker build -t bde2020/hbase-regionserver:$(HBASE_VERSION) ./hregionserver
	docker build --build-arg HIVE_VERSION=${HIVE_VERSION} -t bde2020/hive:${HIVE_VERSION}-postgresql-metastore ./hive
	docker build -t bde2020/hive-metastore-postgresql:$(HIVE_VERSION) ./hive-metastore-postgresql

wordcount:
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hdfs dfs -mkdir -p /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hdfs dfs -copyFromLocal -f /opt/hadoop-2.7.4/README.txt /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hadoop jar /opt/hadoop-2.7.4/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.4.jar wordcount /input /output
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hdfs dfs -cat /output/*
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hdfs dfs -rm -r /output
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hdfs dfs -rm -r /input

test:
	docker cp final-hive-site.xml hive-server:/opt/hive/conf/hive-site.xml
	docker cp ~/.m2/repository/org/apache/hive/hive-hbase-handler/1.1.1/hive-hbase-handler-1.1.1.jar hive-server:/opt
	docker cp test-hive-hbase/data_1.csv hive-server:/opt/data_1.csv
	docker cp test-hive-hbase/ddl-hive.sql hive-server:/opt/
#	docker-compose exec hive-server hive -f /opt/hive/examples/hive-ddl.sql

clean:
	docker exec -d hive-server rm /opt/data_1.*