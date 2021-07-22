# docker-hbase-hive

This fork based on https://github.com/big-data-europe/docker-hbase, add the services for hive from https://github.com/big-data-europe/docker-hive and also metastore from https://github.com/big-data-europe/docker-hive-metastore-postgresql

This branch: **hbase1.2.0-hive.1.1.0** has been prepared to develop and test applications against HBase 1.2.0 and Hive 1.1.0

This deployment will start Zookeeper, HMaster and HRegionserver in separate containers. This deploys Hive and starts a hiveserver2 on port 10000. Metastore is running with a connection to postgresql database.

## Build docker images

In order to build docker images, execute:
~~~
$ make build
~~~

## Run HBase (Local distributed) and Hive

To run local distributed hbase including Hive with postgresql metastore:
~~~
$ docker-compose up -d
~~~

To check the running containers status:
~~~
$ docker-compose ps
~~~

## Testing Hive

Load/read data into/from Hive:
~~~
$ docker-compose exec hive-server hive -f demo/ddl-1.sql
$ docker-compose exec hive-server hive -e "SELECT * FROM data_raw"
~~~

## Testing HBase

Code example to read from Hive and writeto HBase

### Preparing HBase

~~~
$ docker-compose exec hbase-master hbase shell

# If table already exists:
# disable 'space1:data'
# drop 'space1:data'

> create_namespace 'space1'
> create 'space1:data', 'info', {NAME => 'nav', VERSIONS => 10}
> describe 'space1:data'
~~~

### Launching spark-shell with required libraries and hiveserver2 endpoint

~~~
$ spark-shell --conf spark.sql.hive.hiveserver2.jdbc.url="jdbc:hive2://hive-server:10000/" \
--jars lib/hbase-common-1.2.0.jar,\
lib/hbase-shaded-client-1.2.0.jar,\
lib/hbase-shaded-server-1.2.0.jar,\
lib/hbase-protocol-1.2.0.jar,\
lib/hbase-hadoop2-compat-1.2.0.jar,\
lib/metrics-core-2.2.0.jar
~~~

The rest of code snippets should be executed in the spark-shell.

### Input: Hive Partition data

~~~
val year = 2021
val month = 1
val day = 10
val hour = 13
~~~

### Parameters (looking for more generalization)

~~~
val hiveTable = "bd1.data_raw"
val hbaseTable = "space1:data"
val hbaseRowKey = "usr_id"

object HiveDataTypes extends Enumeration {
  type HiveDataType = Value
  val STRING, INT, BIGINT = Value
}

import HiveDataTypes._

case class HBaseMapping(hiveCol: String, colFamily: String, colKey: String, hiveDataType: HiveDataType = STRING)

val hbaseMapping = List(
  HBaseMapping("name", "info", "n"),
  HBaseMapping("url", "nav", "u"),
  HBaseMapping("seconds", "nav", "s", BIGINT)
)
~~~

### Compute Timestamp to data being stored in HBase

~~~
import java.time._
val ts = LocalDateTime.of(year, month, day, hour, 0, 0).atZone(ZoneId.of("Europe/Madrid")).toInstant().toEpochMilli()
~~~

### Read data from Hive for the given partition

~~~
val rawData = spark.sql(s"SELECT * FROM $hiveTable WHERE year=$year AND month=$month AND day=$day AND hour=$hour")
rawData.show()
~~~

### Connect to HBase

~~~
import org.apache.hadoop.hbase.HBaseConfiguration
import org.apache.hadoop.hbase.client.HTable
import org.apache.hadoop.hbase.client.Put
import org.apache.hadoop.hbase.client.Result
import org.apache.hadoop.hbase.util.Bytes

val conf = HBaseConfiguration.create()
conf.set("hbase.zookeeper.quorum", "zoo")
conf.set("hbase.zookeeper.property.clientPort", "2181")
~~~

### Write data to HBase: loop - each row in dataframe will be stored as a HBase row

~~~
val htable = new HTable(conf, hbaseTable)

import scala.collection.JavaConverters._

rawData.takeAsList(1000).asScala.foreach(row => {
  val key = "" + row.getAs[Long](hbaseRowKey)
  val p = new Put(Bytes.toBytes(key), ts)
  hbaseMapping.foreach( hbaseMapping => {
    val HBaseMapping(hiveCol, colFamily, colKey, hiveDataType) = hbaseMapping
    val x = hiveDataType match {
      case STRING => Bytes.toBytes(row.getAs[String](hiveCol))
      case INT => Bytes.toBytes("" + row.getAs[Int](hiveCol))
      case BIGINT => Bytes.toBytes("" + row.getAs[Long](hiveCol))
    }
    p.add(Bytes.toBytes(colFamily), Bytes.toBytes(colKey), x)
  })
  htable.put(p)
})
~~~      