DOCKER_NETWORK = hbase
ENV_FILE = hadoop.env
current_branch := $(shell git rev-parse --abbrev-ref HEAD)
hadoop_branch := 2.0.0-hadoop2.7.4-java8
version_of_hive := 1.1.1
build:
	docker build -t bde2020/hbase-master:$(current_branch) ./hmaster
	docker build -t bde2020/hbase-regionserver:$(current_branch) ./hregionserver
	docker build -t bde2020/hbase-standalone:$(current_branch) ./standalone
	docker build --build-arg HIVE_VERSION=${version_of_hive} -t bde2020/hive:${version_of_hive}-postgresql-metastore ./hive
	docker build -t bde2020/hive-metastore-postgresql:$(version_of_hive) ./hive-metastore-postgresql

wordcount:
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hdfs dfs -mkdir -p /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hdfs dfs -copyFromLocal -f /opt/hadoop-2.7.4/README.txt /input/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} hadoop-wordcount
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hdfs dfs -cat /output/*
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hdfs dfs -rm -r /output
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} bde2020/hadoop-base:$(hadoop_branch) hdfs dfs -rm -r /input
