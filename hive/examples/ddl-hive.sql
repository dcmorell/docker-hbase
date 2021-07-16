
CREATE TABLE IF NOT EXISTS tbl_hive_1 (
	usr_id BIGINT,
	name STRING,
	address STRING,
	salary INT,
	url STRING,
	seconds BIGINT )
PARTITIONED BY (year INT, month SMALLINT, day SMALLINT, hour SMALLINT);

CREATE EXTERNAL TABLE IF NOT EXISTS tbl_hbase_1 (usr_id BIGINT,	name STRING, url STRING, seconds BIGINT, year INT, month SMALLINT, day SMALLINT, hour SMALLINT) STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler' WITH SERDEPROPERTIES ("hbase.columns.mapping" = ":key,info:n,nav:u,nav:s,nav:y,nav:m,nav:d,nav:h") TBLPROPERTIES ("hbase.table.name" = "tbl_hbase_1", "hbase.mapred.output.outputtable" = "tbl_hbase_1");


LOAD DATA LOCAL INPATH '/opt/data_1.csv' OVERWRITE INTO TABLE tbl_hive_1;

INSERT OVERWRITE TABLE tbl_hbase_1 SELECT * FROM tbl_hive_1;


--https://stackoverflow.com/questions/42370170/read-data-from-hbase-by-using-spark-with-java
--https://medium.com/nerd-for-tech/spark-read-from-write-to-hbase-table-using-dataframes-5c3b585c161