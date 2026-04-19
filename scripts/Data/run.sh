spark
from pyspark.sql import SparkSession
spark = SparkSession.builder \
.appName('kkp') \
.master('yarn') \
.getOrCreate()
data = [ 
    "kkp paroi kishor",
    "nishi kkp paroi nishi",
    "kishor nishi kkp kkp"
]
data
rdd = spark.sparkContext.parallelize(data)
rdd.collect()
!hadoop fs -ls /tmp/

hdfs_path = '/tmp/input.txt'
rdd_hdfs = spark.sparkContext.textFile(hdfs_path)
rdd_hdfs.collect()
big_ans_combined = rdd_hdfs.flatMap(lambda line:line.split(' ')).map(lambda word:(word,1)).reduceByKey(lambda a,b: a + b)
big_ans_combined.collect()

big = '/tmp/customers300mb.csv'
medium = '/tmp/customers10mb.csv'
small = '/tmp/customers1mb.csv'

big_rdd = spark.sparkContext.textFile(big)
med_rdd = spark.sparkContext.textFile(medium)
small_rdd = spark.sparkContext.textFile(small)
small_rdd.collect()