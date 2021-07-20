SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

USE bd1;

CREATE EXTERNAL TABLE IF NOT EXISTS data (
	usr_id BIGINT, 
	name STRING, 
	url STRING, 
	seconds BIGINT, 
	year INT, 
	month SMALLINT, 
	day SMALLINT, 
	hour SMALLINT) 
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler' 
WITH SERDEPROPERTIES ("hbase.columns.mapping" = ":key,info:n,nav:u,nav:s,nav:y,nav:m,nav:d,nav:h") 
TBLPROPERTIES ("hbase.table.name" = "space1:data", "hbase.mapred.output.outputtable" = "space1:data");

INSERT OVERWRITE TABLE data SELECT * FROM data_raw;
