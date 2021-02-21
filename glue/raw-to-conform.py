import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
import pyspark.sql.functions as F

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
## @type: DataSource
## @args: [database = "raw", table_name = "lda_s3_raw", transformation_ctx = "datasource0"]
## @return: datasource0
## @inputs: []
datasource0 = glueContext.create_dynamic_frame.from_catalog(database = "raw", table_name = "lda_s3_raw", transformation_ctx = "datasource0")
## @type: ApplyMapping
## @args: [mapping = [("sensor_type", "string", "sensor_type", "string"), ("subject_id", "string", "subject_id", "string"), ("heart_beat_count", "double", "heart_beat_count", "double"), ("timestamp", "string", "timestamp", "string"), ("ro_id", "string", "ro_id", "string"), ("x_gyro", "double", "x_gyro", "double"), ("z_gyro", "double", "z_gyro", "double"), ("y_gyro", "double", "y_gyro", "double"), ("x_acceleration", "double", "x_acceleration", "double"), ("y_acceleration", "double", "y_acceleration", "double"), ("z_acceleration", "double", "z_acceleration", "double"), ("partition_0", "string", "year", "string"), ("partition_1", "string", "month", "string"), ("partition_2", "string", "day", "string"), ("partition_3", "string", "hour", "string")], transformation_ctx = "applymapping1"]
## @return: applymapping1
## @inputs: [frame = datasource0]
applymapping1 = ApplyMapping.apply(frame = datasource0, mappings = [("sensor_type", "string", "sensor_type", "string"), ("currentTemperature", "string", "currentTemperature", "string"), ("status", "string", "status", "string"), ("partition_0", "string", "year", "string"), ("partition_1", "string", "month", "string"), ("partition_2", "string", "day", "string"), ("partition_3", "string", "hour", "string")], transformation_ctx = "applymapping1")
spark_df = applymapping1.toDF()
unique_val = spark_df.select('sensor_type').distinct().collect()

def drop_null_columns(df):
    """
    This function drops all the columns which contains null values.
    """
    null_set = {"none", "null" , "nan"}
    # Iterate over each column in the DF
    for col in df.columns:
        # Get the distinct values of the column
        unique_val = df.select(col).distinct().collect()[0][0]
        # See whether the unique value is only none/nan or null
        if str(unique_val).lower() in null_set:
            #print("Dropping " + col + " because of all null values.")
            df = df.drop(col)
    return df

for val in unique_val:
    data_filter = spark_df.filter("sensor_type == '"+val.sensor_type+"'")
    data_filter = drop_null_columns(data_filter)
    
    data_filter_dynamic_frame = DynamicFrame.fromDF(data_filter, glueContext, "data_filter_dynamic_frame")
    ## @type: ResolveChoice
    ## @args: [choice = "make_struct", transformation_ctx = "resolvechoice2"]
    ## @return: resolvechoice2
    ## @inputs: [frame = applymapping1]
    resolvechoice2 = ResolveChoice.apply(frame = data_filter_dynamic_frame, choice = "make_struct", transformation_ctx = "resolvechoice2")
    ## @type: DropNullFields
    ## @args: [transformation_ctx = "dropnullfields3"]
    ## @return: dropnullfields3
    ## @inputs: [frame = resolvechoice2]
    #dropnullfields3 = DropNullFields.apply(frame = resolvechoice2, transformation_ctx = "dropnullfields3")
    ## @type: DataSink
    ## @args: [connection_type = "s3", connection_options = {"path": "s3://lda-s3-conform"}, format = "parquet", transformation_ctx = "datasink4"]
    ## @return: datasink4
    ## @inputs: [frame = dropnullfields3]
    datasink4 = glueContext.write_dynamic_frame.from_options(frame = resolvechoice2, connection_type = "s3", connection_options = {"path": "s3://lda-s3-conform/"+val.sensor_type , "partitionKeys": ["year", "month", "day", "hour"]}, format = "parquet", transformation_ctx = "datasink4")
job.commit()