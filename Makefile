DOCKER_NETWORK = hadoop
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
