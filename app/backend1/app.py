from flask import *
from flask_cors import CORS
import time, datetime, os, math, logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

#------------------------------------------------------------#
# Add X-Ray SDK for Python with the middleware (Flask)
# - https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-python-middleware.html#xray-sdk-python-adding-middleware-flask
#------------------------------------------------------------#
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.ext.flask.middleware import XRayMiddleware
#------------------------------------------------------------#

#------------------------------------------------------------#
# Apply patches to Python libraries for tracing downstream HTTP requests
# - https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-python-patching.html
#------------------------------------------------------------#
from aws_xray_sdk.core import patch_all
patch_all()
#------------------------------------------------------------#

app = Flask(__name__)
CORS(app)

#------------------------------------------------------------#
# Setup X-Ray SDK and apply patch to Flask application
# - https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-python-middleware.html#xray-sdk-python-adding-middleware-flask
#------------------------------------------------------------#
xray_recorder.configure(service='Backend #1')
XRayMiddleware(app, xray_recorder)
#------------------------------------------------------------#


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "ok"
    })


@app.route("/", methods=["GET"])
def main():
    # Write to DynamoDB table
    dyname_db_table_name = os.environ.get('DYNAMO_DB_TABLE_NAME', '')
    region_name = os.environ.get('AWS_DEFAULT_REGION', '')
    try:
        dynamodb = boto3.resource('dynamodb', region_name=region_name)
        table = dynamodb.Table(dyname_db_table_name)
        table.put_item(Item={
            "SubAppId": "backend1",
            "LastAccessed": str(math.floor(time.time()))
        })
    except Exception as e:
        logger.exception(e)

    # Return current date
    current_datetime = datetime.datetime.fromtimestamp(time.time()).astimezone(datetime.timezone(datetime.timedelta(hours=9)))
    return jsonify({
        "currentDate": current_datetime.strftime('%Y/%m/%d')
    })


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=80)
