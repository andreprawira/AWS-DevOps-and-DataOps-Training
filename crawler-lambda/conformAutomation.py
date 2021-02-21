import json
import boto3

print('Loading function')

glue = boto3.client(service_name='glue', region_name='us-east-2',
              endpoint_url='https://glue.us-east-2.amazonaws.com')

def lambda_handler(event, context):
    #print("Received event: " + json.dumps(event, indent=2))

    try:
       glue.start_crawler(Name='conform')
    except Exception as e:
        print(e)
        print('Error starting crawler')
        raise e