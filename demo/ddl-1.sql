SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

CREATE DATABASE IF NOT EXISTS bd1;

USE bd1;

CREATE TABLE IF NOT EXISTS data_raw (
	usr_id BIGINT,
	name STRING,
	url STRING,
	seconds BIGINT )
PARTITIONED BY (year INT, month SMALLINT, day SMALLINT, hour SMALLINT)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

LOAD DATA LOCAL INPATH '/opt/data-12h.csv' OVERWRITE INTO TABLE data_raw PARTITION(year=2021,month=1,day=10,hour=12);
LOAD DATA LOCAL INPATH '/opt/data-13h.csv' OVERWRITE INTO TABLE data_raw PARTITION(year=2021,month=1,day=10,hour=13);
LOAD DATA LOCAL INPATH '/opt/data-14h.csv' OVERWRITE INTO TABLE data_raw PARTITION(year=2021,month=1,day=10,hour=14);
