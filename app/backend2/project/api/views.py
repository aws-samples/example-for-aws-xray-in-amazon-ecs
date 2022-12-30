from django.http import JsonResponse
from rest_framework.decorators import api_view
import time, datetime, os, math, logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

#------------------------------------------------------------#
# Apply patches to Python libraries for tracing downstream HTTP requests
# - https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-python-patching.html
#------------------------------------------------------------#
from aws_xray_sdk.core import patch_all
patch_all()
#------------------------------------------------------------#


@api_view(["GET"])
def health_check(request):
    content = {
        "status": "ok"
    }
    return JsonResponse(content)


@api_view(["GET"])
def main(request):
    # Write to DynamoDB table
    dyname_db_table_name = os.environ.get('DYNAMO_DB_TABLE_NAME', '')
    region_name = os.environ.get('AWS_DEFAULT_REGION', '')
    try:
        dynamodb = boto3.resource('dynamodb', region_name=region_name)
        table = dynamodb.Table(dyname_db_table_name)
        table.put_item(Item={
            "SubAppId": "backend2",
            "LastAccessed": str(math.floor(time.time()))
        })
    except Exception as e:
        logger.exception(e)

    # Return current time
    current_datetime = datetime.datetime.fromtimestamp(time.time()).astimezone(datetime.timezone(datetime.timedelta(hours=9)))
    content = {
        "currentTime": current_datetime.strftime('%H:%M:%S')
    }
    return JsonResponse(content)
