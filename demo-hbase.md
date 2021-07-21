# Copy data from Hive to HBase

## spark-shell
~~~
spark-shell --conf spark.sql.hive.hiveserver2.jdbc.url="jdbc:hive2://hive-server:10000/" \
--jars \
hive/lib/hbase-common-1.2.0.jar,\
hive/lib/hbase-shaded-client-1.2.0.jar,\
hive/lib/hbase-shaded-server-1.2.0.jar,\
hive/lib/hbase-protocol-1.2.0.jar,\
hive/lib/hbase-hadoop2-compat-1.2.0.jar,\
hive/lib/metrics-core-2.2.0.jar
~~~

## Inputs: Partition data
~~~
val year = 2021
val month = 1
val day = 10
val hour = 13
~~~

## Parameters (looking for more generalization)
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

## Compute Timestamp to data being stored in HBase
~~~
import java.time._
val ts = LocalDateTime.of(year, month, day, hour, 0, 0).atZone(ZoneId.of("Europe/Madrid")).toInstant().toEpochMilli()
~~~


## Read data from Hive for the given partition
~~~
val rawData = spark.sql(s"SELECT * FROM $hiveTable WHERE year=$year AND month=$month AND day=$day AND hour=$hour")
rawData.show()
~~~


## Connect to HBase
~~~
import org.apache.hadoop.hbase.HBaseConfiguration
import org.apache.hadoop.hbase.client.HBaseAdmin
import org.apache.hadoop.hbase.client.HTable
import org.apache.hadoop.hbase.client.Get
import org.apache.hadoop.hbase.client.Put
import org.apache.hadoop.hbase.client.Result
import org.apache.hadoop.hbase.util.Bytes
import org.apache.hadoop.hbase.client.Result
import org.apache.hadoop.hbase.client.ResultScanner
import org.apache.hadoop.hbase.client.Scan
import org.apache.hadoop.hbase.client.Table
import org.apache.hadoop.hbase.client.Connection
import org.apache.hadoop.hbase.client.ConnectionFactory

val conf = HBaseConfiguration.create()
//conf.addResource(new Path("/etc/hbase/conf/hbase-default.xml"))
//conf.addResource(new Path("/etc/hbase/conf/hbase-site.xml"))
conf.set("hbase.zookeeper.quorum", "zoo")
conf.set("hbase.zookeeper.property.clientPort", "2181")

//val hbaseOk = HBaseAdmin.checkHBaseAvailable(conf)
~~~


## Write data to HBase: loop - each row in dataframe will be stored as a HBase row
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
