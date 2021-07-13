# docker-hbase-hive

To current project (https://github.com/big-data-europe/docker-hbase) I'm adding the services for hive from https://github.com/big-data-europe/docker-hive

## Run HBase (Local distributed) and Hive

To run local distributed hbase including Hive with postgresql metastore and Presto coordinator:
```
docker-compose up -d
```

This deployment will start Zookeeper, HMaster and HRegionserver in separate containers.

This deploys Hive and starts a hiveserver2 on port 10000.

Metastore is running with a connection to postgresql database.

The hive configuration is performed with HIVE_SITE_CONF_ variables (see hadoop-hive.env for an example).

## Testing Hive
Load data into Hive:
```
  $ docker-compose exec hive-server bash
  # /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000
  > CREATE TABLE pokes (foo INT, bar STRING);
  > LOAD DATA LOCAL INPATH '/opt/hive/examples/files/kv1.txt' OVERWRITE INTO TABLE pokes;
```

Then query it from PrestoDB. You can get [presto.jar](https://prestosql.io/docs/current/installation/cli.html) from PrestoDB website:
```
  $ wget https://repo1.maven.org/maven2/io/prestosql/presto-cli/308/presto-cli-308-executable.jar
  $ mv presto-cli-308-executable.jar presto.jar
  $ chmod +x presto.jar
  $ ./presto.jar --server localhost:8080 --catalog hive --schema default
  presto> select * from pokes;
```
