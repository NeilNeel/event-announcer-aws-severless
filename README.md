# Event Announcement System

A disco-themed event announcement system built with AWS serverless architecture. Users can subscribe to receive email notifications about groovy 1970s disco events and create new events that get announced to all subscribers.

## Architecture Overview

![Architecture Diagram](screenshots/aws-serverless-event-announcement-system-architecture.png)

The system demonstrates production-ready serverless patterns including Infrastructure as Code, event-driven architecture, and security-first deployment practices with WAF protection and rate limiting.

## Features

- **Email Subscription System** for event notifications
- **Event Creation Portal** with disco-themed categories
- **Real-time Notifications** via SNS to all subscribers
- **Serverless Architecture** with AWS Lambda and API Gateway
- **Static Website Hosting** on S3 with CloudFront CDN
- **WAF Protection** with rate limiting and security rules
- **Infrastructure as Code** managed with Terraform

## Tech Stack

- **Frontend**: HTML5, CSS3, JavaScript (Disco-themed UI)
- **Infrastructure**: AWS (Lambda, API Gateway, SNS, DynamoDB, S3, CloudFront)
- **IaC**: Terraform
- **Security**: WAF, API Keys, CORS

## API Endpoints

### Subscribe to Events
```http
POST /subscribe
Content-Type: application/json
```

**Parameters:**
- `email` (string): User email address

**Response:**
```json
{
  "message": "Successfully subscribed to event announcements",
  "status": "subscribed"
}
```

### Create Event
```http
POST /event
Content-Type: application/json
```

**Parameters:**
- `title` (string): Event title
- `description` (string): Event description
- `datetime` (string): Event date and time
- `location` (string): Event location
- `category` (string): Event category

**Response:**
```json
{
  "event_id": "event-12345",
  "title": "Saturday Night Fever",
  "status": "created",
  "notification_sent": true
}
```

## Quick Start

### Prerequisites
- AWS Account with appropriate permissions
- Terraform installed
- Python 3.9+ for Lambda functions

### Local Development

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/event-announcement-system
cd event-announcement-system
```

2. **Prepare Lambda packages**
```bash
cd terraform/
zip subscribe_lambda.zip subscribe_lambda.py
zip create_event_lambda.zip create_event_lambda.py
```

3. **View the static site locally**
```bash
cd static-site/
python -m http.server 8000
# Visit http://localhost:8000
```

### Production Deployment

1. **Deploy infrastructure**
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

2. **Get the CloudFront URL**
```bash
terraform output cloudfront_url
```

3. **Update API endpoints in frontend**
- Edit `static-site/script.js` with your API Gateway URLs

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SNS_TOPIC_ARN` | SNS topic for notifications | `arn:aws:sns:us-east-1:123:events` |
| `DYNAMODB_TABLE_EVENT` | DynamoDB table for events | `event-announcement-events` |

## AWS Resources Created

- **Lambda Functions** for subscribe and event creation
- **API Gateway** with CORS configuration
- **DynamoDB Table** for event storage
- **SNS Topic** for email notifications
- **S3 Bucket** for static website hosting
- **CloudFront Distribution** with custom domain support
- **WAF Web ACL** with rate limiting rules
- **IAM Roles** with least-privilege permissions

## Security Features

- **WAF Protection**: Rate limiting (2000 requests/5min) and AWS managed rules
- **API Rate Limiting**: 5 requests/second, 100 requests/day
- **HTTPS Only**: CloudFront enforces secure connections
- **CORS Configuration**: Proper cross-origin resource sharing
- **IAM Roles**: Least-privilege permissions for Lambda functions

## Scalability Considerations

The serverless architecture automatically scales with demand. For additional scale:

- **DynamoDB On-Demand**: Automatically scales read/write capacity
- **Lambda Concurrency**: Auto-scales to handle concurrent requests
- **CloudFront**: Global CDN for worldwide content delivery
- **SNS Fanout**: Efficiently handles large subscriber lists

## Troubleshooting

### Common Issues

**CORS errors in browser:**
- Verify API Gateway CORS configuration is deployed
- Check that OPTIONS methods are properly configured

**Email notifications not working:**
- Confirm SNS topic subscription via email
- Verify Lambda has SNS publish permissions

**Static site not loading:**
- Check S3 bucket policy allows CloudFront access
- Verify CloudFront distribution is deployed

### Logs
```bash
# Check Lambda function logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/

# Check API Gateway logs
aws logs describe-log-groups --log-group-name-prefix API-Gateway-Execution-Logs
```

## Project Structure

```
.
├── static-site/          # Frontend disco-themed website
│   ├── index.html       # Main webpage with subscription/event forms
│   ├── styles.css       # 1970s disco styling and animations
│   └── script.js        # Frontend JavaScript and API calls
├── terraform/           # Infrastructure as Code
│   ├── main.tf          # Main Terraform configuration
│   ├── provider.tf      # AWS provider setup
│   ├── variables.tf     # Variable definitions
│   ├── output.tf        # Output values
│   ├── create_event_lambda.py    # Lambda for event creation
│   └── subscribe_lambda.py       # Lambda for email subscription
└── screenshots/         # Project demonstration images
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/groovy-feature`)
3. Make changes and test locally
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Note**: This project demonstrates AWS serverless architecture patterns with a fun disco theme. The system is production-ready but additional monitoring and logging could be implemented for enterprise use.