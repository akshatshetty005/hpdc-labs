import sys
import json
import datetime
import logging
import boto3
from faker import Faker


tabl_name = "employee"
p_after = 3600
logger = logging.getLogger()
logger.setLevel(logging.INFO)

try:
    dyn_client = boto3.client('dynamodb', region_name="us-east-1")
except Exception as e:
    logger.error("ERROR: Unexpected error: Could not connect to Dynamodb client.")
    logger.error(e)
    sys.exit()

logger.info("SUCCESS: Connection to RDS MySQL instance succeeded")

def generate_fake_data():
    """
    This function generate fake data using Faker module
    """
    f_data = {}
    rec_d = []
    ret_data = {}
    for cou in range (10):
        mfaker = Faker()

        f_data["EmpId"] = mfaker.random_int(1000, 999999)
        f_data["Name"] = mfaker.name()
        f_data["Location"] = mfaker.state()
        f_data["Phone"] = mfaker.phone_number()
        f_data["Designation"] = mfaker.job()
        f_data["Timestamp"] = datetime.datetime.now().isoformat()
        utc_time = datetime.datetime.strptime(f_data["Timestamp"], "%Y-%m-%dT%H:%M:%S.%f")
        f_data["PurgeAfter"] = int((utc_time - datetime.datetime(1970, 1, 1)).total_seconds()) + p_after

        #print (f_data)
        rec_d.append(f_data.copy())
        #print (rec_d)

    #print (rec_d)
    ret_data["Records"] = rec_d
    print (json.dumps(ret_data, indent=2))
    return ret_data
 
#generate_fake_data()

def lambda_handler(event, context):
    """
    This function inserts items to DynamoDB table
    """
   
    item_count = 0

    for rec in event["Records"]:
        i=str(rec["EmpId"])
        n=rec["Name"]
        l=rec["Location"]
        p=rec["Phone"]
        d=rec["Designation"]
        t=rec["Timestamp"]
        g=str(rec["PurgeAfter"])
        
        ret = dyn_client.put_item(
                TableName=tabl_name,
                Item = {
                        "EmpId" : {"N" : i},
                        "Name" : {"S" : n},
                        "Location" : {"S" : l},
                        "Phone" : {"S" : p},
                        "Designation" : {"S" : d},
                        "Timestamp" : {"S" : t},
                        "PurgeAfter" : {"N" : g}
                    }
                )

        item_count +=1

    return "Added %d items to DynamoDB table" %(item_count)


if __name__ == "__main__" :
    inp_data = generate_fake_data()
    print (json.dumps(inp_data, indent=2))
    lambda_handler(inp_data, 1)

