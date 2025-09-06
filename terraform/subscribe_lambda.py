import json
import boto3
import os
import re
import logging

sns = boto3.client('sns')
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

def email_validation(email):
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    isValid =  re.match(pattern, email) is not None
    logger.debug(f"Validating email: {email}, Is valid: {isValid}")
    return isValid

def lambda_handler(event, context):
    logger.info("Source IP: " + event['requestContext']['identity']['sourceIp'])
    logger.info(f"Received event: {json.dumps(event['body'])}")

    try:
        body = json.loads(event['body'])
        email = body.get('email')

        if not email:
            logger.warning("No email provided in the request")
            return build_response(400, {'error':'No email provided!'})

        if not email_validation(email):
            logger.warning(f"Invalid email format: {email}")
            return build_response(400, {'error': 'Invalid email format, check again!'})

        logger.info(f"Subscribing email: {email} to SNS topic")
        sns.subscribe(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Protocol='email',
            Endpoint=email
        )

        logger.info(f"Subscription initiated for {email}") 
        return build_response(200, f'Subscription initiated for {email}. Check your email to confirm!')

    except Exception as e:
        logger.error(f"Error subscribing email: {str(e)}", exc_info=True)
        return build_response(500, f'Error subscribing email: {str(e)}')

def build_response(status_code, body):
    logger.debug(f"Building response with status {status_code}: {body}")    
    return {
        'statusCode': status_code,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'OPTIONS,POST',
            'Access-Control-Allow-Headers': 'Content-Type'
        },
        'body': json.dumps(body) if isinstance(body, (dict, list)) else json.dumps({'message': body})
    }