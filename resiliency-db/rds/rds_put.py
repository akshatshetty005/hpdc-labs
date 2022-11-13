import sys
import json
import logging
import rds_config
import pymysql
from faker import Faker

#rds settings

rds_host  = "resili.cxjrgdqlrpdp.us-east-1.rds.amazonaws.com"
name = rds_config.db_username
password = rds_config.db_password
db_name = rds_config.db_name

logger = logging.getLogger()
logger.setLevel(logging.INFO)

try:
    conn = pymysql.connect(host=rds_host, user=name, passwd=password, db=db_name, connect_timeout=5)
except pymysql.MySQLError as e:
    logger.error("ERROR: Unexpected error: Could not connect to MySQL instance.")
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
        name = mfaker.name()
        location = mfaker.city()
        phone = mfaker.phone_number()
        designation = mfaker.job()

        f_data["Name"] = mfaker.name()
        f_data["Location"] = mfaker.state()
        f_data["Phone"] = mfaker.phone_number()
        f_data["Designation"] = mfaker.job()

        #print (f_data)
        rec_d.append(f_data.copy())
        #print (rec_d)

    #print (rec_d)
    ret_data["Records"] = rec_d
    #print (json.dumps(ret_data, indent=2))
    return ret_data
 
#generate_fake_data()

def lambda_handler(event, context):
    """
    This function fetches content from MySQL RDS instance
    """
   
    item_count = 0

    with conn.cursor() as cur:
        cur.execute("create table if not exists EmpDB1 (EmpID  int(11) NOT NULL AUTO_INCREMENT, Name varchar(255) NOT NULL,Location varchar(255), Phone varchar(255) NOT NULL, Designation varchar(255) NOT NULL, Timestamp datetime default now(), PRIMARY KEY (EmpID))")

        for rec in event["Records"]:
            n=rec["Name"]
            l=rec["Location"]
            p=rec["Phone"]
            d=rec["Designation"]
            #print (n,l,p,d)
            
            sql_cmd=("INSERT INTO EmpDB1 (Name, Location, Phone,  Designation)  VALUES (\"{}\",\"{}\",\"{}\",\"{}\")".format(n,l,p,d))
            #print (sql_cmd)
            
            cur.execute(sql_cmd)
            conn.commit()
            cur.execute("select * from EmpDB1")

            for row in cur:
                item_count += 1
                logger.info(row)
                #print(row)
            conn.commit()

    return "Added %d items from RDS MySQL table" %(item_count)


if __name__ == "__main__" :
    inp_data = generate_fake_data()
    print (json.dumps(inp_data, indent=2))
    lambda_handler(inp_data, 1)
