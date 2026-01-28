-- Switch to ACCOUNTADMIN role
USE ROLE ACCOUNTADMIN;

-- Create Snowflake Intelligence admin role
CREATE OR REPLACE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- Assign role to current user
SET CURRENT_USER = (SELECT CURRENT_USER());   
GRANT ROLE SNOWFLAKE_INTELLIGENCE_ADMIN TO USER IDENTIFIER($CURRENT_USER);
ALTER USER SET DEFAULT_ROLE = SNOWFLAKE_INTELLIGENCE_ADMIN;
ALTER USER SET DEFAULT_WAREHOUSE = SF_INTEL_WH;

-- Use the new admin role
USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- Create database, schema, and warehouse
CREATE OR REPLACE DATABASE SF_INTEL_POC_DB;
CREATE OR REPLACE SCHEMA RAW;
CREATE OR REPLACE WAREHOUSE SF_INTEL_WH WITH WAREHOUSE_SIZE = 'LARGE';

-- Create demo schema for agents
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_DEMO;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_DEMO.AGENT_DEMO;
GRANT CREATE AGENT ON SCHEMA SNOWFLAKE_INTELLIGENCE_DEMO.AGENT_DEMO TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- Switch context to database, schema, warehouse
USE DATABASE SF_INTEL_POC_DB;
USE SCHEMA RAW;
USE WAREHOUSE SF_INTEL_WH;

-- Create tables from sample data
CREATE TABLE SF_INTEL_POC_DB.RAW.CUSTOMER 
AS SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF100TCL.CUSTOMER;

CREATE TABLE SF_INTEL_POC_DB.RAW.CUSTOMER_ADDRESS 
AS SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF100TCL.CUSTOMER_ADDRESS;

CREATE TABLE SF_INTEL_POC_DB.RAW.CUSTOMER_DEMOGRAPHICS 
AS SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF100TCL.CUSTOMER_DEMOGRAPHICS;

CREATE TABLE SF_INTEL_POC_DB.RAW.ITEM
AS SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF100TCL.ITEM;

CREATE OR REPLACE TABLE SF_INTEL_POC_DB.RAW.SALES
AS SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF100TCL.CATALOG_SALES LIMIT 1000000000;

-- Create stage for semantic models where yml file for cortex analyst need to be uploaded 
CREATE OR REPLACE STAGE SEMANTIC_MODELS
ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE') 
DIRECTORY = (ENABLE = TRUE);

-- Create email integration for notifications
CREATE OR REPLACE NOTIFICATION INTEGRATION EMAIL_INTEGRATION
  TYPE = EMAIL
  ENABLED = TRUE
  DEFAULT_SUBJECT = 'SNOWFLAKE INTELLIGENCE';

-- Email procedure for notifications
create or replace procedure send_email(
    recipient_email varchar,
    subject varchar,
    body varchar
)
returns varchar
language python
runtime_version = '3.12'
packages = ('snowflake-snowpark-python')
handler = 'send_email'
as
$$
def send_email(session, recipient_email, subject, body):
    try:
        # Escape single quotes in the body
        escaped_body = body.replace("'", "''")
        
        # Execute the system procedure call
        session.sql(f"""
            CALL SYSTEM$SEND_EMAIL(
                'email_integration',
                '{recipient_email}',
                '{subject}',
                '{escaped_body}',
                'text/html'
            )
        """).collect()
        
        return "Email sent successfully"
    except Exception as e:
        return f"Error sending email: {str(e)}"
$$;