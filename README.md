# docker-hbase-hive

This fork based on https://github.com/big-data-europe/docker-hbase

This branch: **hbase-1.2.0** has been prepared to develop and test applications against HBase 1.2.0

This deployment will start Zookeeper, HMaster and HRegionserver in separate containers. 

## My versions of docker and docker-compose
~~~
- Docker version 20.10.6, build 370c289
- docker-compose version 1.29.2, build unknown
~~~

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

## You may/should add following lines to /ect/hosts

~~~
...
172.25.1.1      namenode
172.25.1.2      datanode
172.25.1.3      resourcemanager
172.25.1.4      nodemanager
172.25.1.5      historyserver
172.25.2.1      zoo
172.25.3.1      hbase-master
172.25.3.2      hbase-region
~~~

## Writing data from Spark (DataFrame) to HBase

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

### Spark-shell with HBase dependencies
~~~
spark-shell --jars lib/hbase-common-1.2.0.jar,lib/hbase-shaded-client-1.2.0.jar
~~~

### Creating a sample DataFrame
~~~

import spark.implicits._

val columns = Seq("id", "id2", "name", "url", "seconds", "year", "month", "day", "hour")

val data = Seq(
  ("603", "AAA", "Juan", "URL1", 1001, 2021, 1, 10, 13), 
  ("702", "AAA", "David", "URL2", 1002, 2021, 1, 10, 13), 
  ("807", "AAA", "Maria", "URL1", 1003, 2021, 1, 10, 13),
  ("701", "BBB", "David", "URL2", 1004, 2021, 1, 10, 13), 
  ("808", "CCc", "Maria", "URL3", 1005, 2021, 1, 10, 13)
)

val df = data.toDF(columns:_* )
~~~

### Writing a DataFrame to HBase
~~~
import java.time._
import org.apache.hadoop.hbase.HBaseConfiguration
import org.apache.hadoop.hbase.client.ConnectionFactory
import org.apache.hadoop.hbase.client.Table
import org.apache.hadoop.hbase.TableName
import org.apache.hadoop.hbase.client.Put
import org.apache.hadoop.hbase.client.Result
import org.apache.hadoop.hbase.util.Bytes

val hbaseTable = "space1:data"
val rowKeyField1 = "id"
val rowKeyField2 = "id2"
val colFamily = "cf"

case class HBaseMapping(dfCol: String, colKey: String, dataType: String = "STRING")

val hbaseMapping = Seq(
  HBaseMapping("name", "name"),
  HBaseMapping("url", "url"),
  HBaseMapping("seconds", "sec", "BIGINT")
)

import scala.collection.JavaConverters._

val colFamilyBytes = Bytes.toBytes(colFamily)

df.foreachPartition( partition => {
  
  val conf1 = HBaseConfiguration.create()
  conf1.set("hbase.zookeeper.quorum", "zoo")
  conf1.set("hbase.zookeeper.property.clientPort", "2181")
  val connection1 = ConnectionFactory.createConnection(conf1)
  val htable1 = connection1.getTable(TableName.valueOf("space1:data"))

  partition.foreach( row => {
  
    val year = row.getAs[Int]("year")
    val month = row.getAs[Int]("month")
    val day = row.getAs[Int]("day")
    val hour = row.getAs[Int]("hour")

    val ts = LocalDateTime.of(year, month, day, hour, 0, 0).atZone(ZoneId.of("Europe/Madrid")).toInstant().toEpochMilli()
  
    val key1 = row.getAs[String](rowKeyField1)
    val key2 = row.getAs[String](rowKeyField2)
    val key = key1.reverse(0) + "0" + key1 + "_" + key2

    val p = new Put(Bytes.toBytes(key), ts)

    hbaseMapping.foreach( hbaseMapping => {
      val HBaseMapping(hiveCol, colKey, hiveDataType) = hbaseMapping
      val x = hiveDataType match {
        case "STRING" => Bytes.toBytes(row.getAs[String](hiveCol))
        case "INT" => Bytes.toBytes("" + row.getAs[Int](hiveCol))
        case "BIGINT" => Bytes.toBytes("" + row.getAs[Long](hiveCol))
      }
      //p.add(colFamilyBytes, Bytes.toBytes(colKey), x)
      p.addColumn(colFamilyBytes, Bytes.toBytes(colKey), x)
    })

    htable1.put(p)
  })

  htable1.close()
  connection1.close()
})
~~~

### Querying data from HBase
~~~
scan

get "space1:data", '800_AAA', {COLUMN => ['cf:sec', 'cf:url'], TIMERANGE => [1610280800000, 1610290000000], VERSIONS => 10}

get "space1:data", '800_AAA', {COLUMN => ['cf:sec', 'cf:url'], TIMERANGE => [1610280800000, 1610290000000]}
~~~

### Notes

1) We are avoiding deprecated classes (HTable) and methods (.add())

2) In this case, we prefer hashing instead of salting

https://dwgeek.com/avoid-hbase-hotspotting.html/
http://www.devdoc.net/bigdata/hbase-0.98.7-hadoop1/book/rowkey.design.html

3) Rowkey is composed by: key1 and key2 values and is prefixed with a simple hashfunction (to avoid hotspotting). The hash function gives as result two chars: the last character of key1 followed by '0'

4) Now to retrieve columns for a key (composed key) (key1, key2) := (k1, k2)
~~~
x = k1.reverse(0) + '0' + key1 + '_' + key2
GET 'space:data1', x ...
~~~


