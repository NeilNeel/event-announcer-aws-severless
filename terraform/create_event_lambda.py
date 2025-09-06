import boto3
import json
import uuid
import time
import datetime
import os
import logging
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

def is_valid_future_timestamp(timestamp):
    logger.debug(f"Validating timestamp: {timestamp}")
    try:
        timestamp = int(timestamp)
        current_time = int(time.time())
        max_future = current_time + (365 * 24 * 60 * 60 * 10)  # 10 years
        isValid = current_time < timestamp <= max_future
        logger.debug(f"Timestamp {timestamp} is valid: {isValid}")
        return isValid
    
    except (ValueError, TypeError):
        logger.warning(f"Invalid timestamp: {timestamp}")
        return False
    
def lambda_handler(event, context):
    logger.info("Source IP: " + event['requestContext']['identity']['sourceIp'])
    logger.info(f"Received event: {json.dumps(event['body'])}")

    try:
        body = json.loads(event['body'])

        # required fields
        required_fields = ['event_title','event_datetime']
        for field in required_fields:
            if field not in body:
                logger.warning(f"{field}: is required for the successful event creation")
                return build_response(400, f'{field} is required!')
        
        if not is_valid_future_timestamp(body['event_datetime']):
            logger.warning(f"Event datetime must be a valid future timestamp: {body['event_datetime']}")
            return build_response(400, {'error': 'Event datetime must be a valid future timestamp'})
            
        # optional fields
        event_data = {
            'event_id': str(uuid.uuid4()),
            'event_title': body['event_title'][:50],
            'event_datetime': int(body['event_datetime']),
            'created_at': int(time.time()),
        }

        if body.get('event_description'):
            event_data['event_description'] = body['event_description']
        if body.get('location'):
            event_data['location'] = body['location']
        if body.get('category'):
            event_data['category'] = body['category']

        logger.info(f"Saving event data: {event_data}")
        table = dynamodb.Table(os.environ['DYNAMODB_TABLE_EVENT'])
        try:
            table.put_item(Item=event_data)
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == 'ProvisionedThroughputExceededException':
                logger.error("ProvisionedThroughputExceededException: " + str(e))
                return build_response(503, {'error': 'Service temporarily unavailable. Please try again.'})
            elif error_code == 'ResourceNotFoundException':
                logger.error("ResourceNotFoundException: " + str(e))
                return build_response(500, {'error': 'Database configuration error'})
            else:
                logger.error("Unexpected error: " + str(e))
                return build_response(500, {'error': 'Failed to save event. Please try again.'})

        # send sns notification
        logger.info("Sending SNS notification")
        message = f"New event: {event_data['event_title']}\n"
        if event_data.get('event_description'):
            message += f"{event_data['event_description']}\n"

        sns.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Message = message,
            Subject = 'New Event Announcement'
        )

        logger.info("Event created successfully")
        return build_response(201, {
            'message': 'Event created successfully',
            'event_id': event_data['event_id']
        })
        

    except Exception as e:
        logger.error(f"Error creating event: {str(e)}", exc_info=True)
        return build_response(500, f'Error creating event: {str(e)}')

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