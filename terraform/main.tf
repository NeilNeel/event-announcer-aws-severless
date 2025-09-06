# SNS topic
resource "aws_sns_topic" "event_announcement_topic" {
  name = "event-announcement-topic"

  tags = {
    Name = "EventAnnouncementTopic"
    Environment = "development"
  }
}

# dynamo-table
resource "aws_dynamodb_table" "events_table" {
  name           = "event-announcement-events"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  tags = {
    Name        = "EventAnnouncementEvents"
    Environment = "development"
  }
}


# Role
resource "aws_iam_role" "lambda_sns_role" {
    name = "lambda_sns_role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                        Service = "lambda.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_role" "lambda_event_role" {
  name = "lambda_event_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_sns_subscribe_policy" {
    name = "lambda_sns_subscribe_policy"
    role = aws_iam_role.lambda_sns_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "sns:Subscribe"
                ]
                Resource = aws_sns_topic.event_announcement_topic.arn
            },
            {
              Effect = "Allow"
              Action = [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
              ]
              Resource = "arn:aws:logs:*:*:*"
            }
        ]
    })
}

resource "aws_iam_role_policy" "lambda_sns_event_policy" {
    name = "lambda_sns_event_policy"
    role = aws_iam_role.lambda_event_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "sns:publish"
                ]
                Resource = aws_sns_topic.event_announcement_topic.arn
            },
            {
              Effect = "Allow"
              Action = [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
              ]
              Resource = "arn:aws:logs:*:*:*"
            },
            {
              Effect = "Allow",
              Action = [
                "dynamodb:PutItem"
              ]
              Resource = aws_dynamodb_table.events_table.arn
            }
        ]
    })
}

# lambda subscribe
resource "aws_lambda_function" "subscribe_email" {
  filename = "subscribe_lambda.zip"
  function_name = "subscribe_email_to_sns"
  role = aws_iam_role.lambda_sns_role.arn
  handler = "subscribe_lambda.lambda_handler"
  runtime = "python3.9"

  source_code_hash = filebase64sha256("subscribe_lambda.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.event_announcement_topic.arn
    }
  }
}

# event lambda
resource "aws_lambda_function" "create_event" {
  filename = "create_event_lambda.zip"
  function_name = "create_event"
  role = aws_iam_role.lambda_event_role.arn
  handler = "create_event_lambda.lambda_handler"
  runtime = "python3.9"

  source_code_hash = filebase64sha256("create_event_lambda.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.event_announcement_topic.arn,
      DYNAMODB_TABLE_EVENT = aws_dynamodb_table.events_table.name
    }  
  } 
}

# API-gateway
resource "aws_api_gateway_rest_api" "event_announcement_api" {
  name = "event-announcement-api"
  description = "API for the event announcement system"
}

resource "aws_api_gateway_resource" "subscribe_resource" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  parent_id   = aws_api_gateway_rest_api.event_announcement_api.root_resource_id
  path_part = "subscribe"
}

resource "aws_api_gateway_method" "subscribe_method" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.subscribe_resource.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "subscribe_integration" {
  rest_api_id             = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id             = aws_api_gateway_resource.subscribe_resource.id
  http_method             = aws_api_gateway_method.subscribe_method.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.subscribe_email.invoke_arn
}

resource "aws_lambda_permission" "api_gw_subscribe" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.subscribe_email.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.event_announcement_api.execution_arn}/*/*"
}


# create event endpoint
resource "aws_api_gateway_resource" "create_event_resource" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  parent_id = aws_api_gateway_rest_api.event_announcement_api.root_resource_id
  path_part = "event"
}

resource "aws_api_gateway_method" "create_event_method" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.create_event_resource.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_event_integration" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.create_event_resource.id
  http_method = aws_api_gateway_method.create_event_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_event.invoke_arn
}

resource "aws_lambda_permission" "api_gw_create_event" {
  statement_id = "AllowExecutionFromAPIGatewayCreateEvent"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_event.function_name
  principal = "apigateway.amazonaws.com"
  source_arn ="${aws_api_gateway_rest_api.event_announcement_api.execution_arn}/*/*"
}


resource "aws_api_gateway_deployment" "event_api_deployment" {
  depends_on = [
    aws_api_gateway_method.subscribe_method,
    aws_api_gateway_integration.subscribe_integration,
    aws_api_gateway_method.subscribe_options,
    aws_api_gateway_integration.subscribe_options_integration,
    aws_api_gateway_method.create_event_method,
    aws_api_gateway_integration.create_event_integration,
    aws_api_gateway_method.create_event_options,
    aws_api_gateway_integration.create_event_options_integration,
  ]
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.subscribe_resource.id,
      aws_api_gateway_method.subscribe_method.id,
      aws_api_gateway_integration.subscribe_integration.id,
      aws_api_gateway_method.subscribe_options.id,
      aws_api_gateway_integration.subscribe_options_integration.id,
      aws_api_gateway_resource.create_event_resource.id,
      aws_api_gateway_method.create_event_method.id,
      aws_api_gateway_integration.create_event_integration.id,
      aws_api_gateway_method.create_event_options.id,
      aws_api_gateway_integration.create_event_options_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.event_api_deployment.id
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  stage_name = "dev"
}

# s3
resource "aws_s3_bucket" "frontend_event_bucket" {
  bucket = "event-announcement-frontend-${random_string.bucket_suffix.result}"
  
  tags = {
    Name = "EventAnnouncementFrontend"
    Environment = "development"
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  upper   = false
  special = false
}

resource "aws_s3_bucket_website_configuration" "frontend_event_bucket_config" {
  bucket = aws_s3_bucket.frontend_event_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_event_bucket_pab" {
  bucket = aws_s3_bucket.frontend_event_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "frontend_event_bucket_policy" {
  bucket = aws_s3_bucket.frontend_event_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.frontend_event_bucket_pab]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service : "cloudfront.amazonaws.com"
        }
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend_event_bucket.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.event_announcement_frontend_distribution.arn
          }
        } 
      }
    ]
  })
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend_event_bucket.id
  key          = "index.html"
  source       = "../static-site/index.html"  
  content_type = "text/html"
  etag         = filemd5("../static-site/index.html") 
}

resource "aws_s3_object" "styles" {
  bucket       = aws_s3_bucket.frontend_event_bucket.id
  key          = "styles.css"
  source       = "../static-site/styles.css"
  content_type = "text/css"
  etag         = filemd5("../static-site/styles.css")
}

resource "aws_s3_object" "script" {
  bucket       = aws_s3_bucket.frontend_event_bucket.id
  key          = "script.js"
  source       = "../static-site/script.js"
  content_type = "application/javascript"
  etag         = filemd5("../static-site/script.js")
}

# CORS
resource "aws_api_gateway_method" "subscribe_options" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.subscribe_resource.id
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "subscribe_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.subscribe_resource.id
  http_method = aws_api_gateway_method.subscribe_options.http_method
  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "subscribe_options" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.subscribe_resource.id
  http_method = aws_api_gateway_method.subscribe_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "subscribe_options" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.subscribe_resource.id
  http_method = aws_api_gateway_method.subscribe_options.http_method
  status_code = aws_api_gateway_method_response.subscribe_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# CORS for create_event endpoint
resource "aws_api_gateway_method" "create_event_options" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.create_event_resource.id
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_event_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.create_event_resource.id
  http_method = aws_api_gateway_method.create_event_options.http_method
  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "create_event_options" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.create_event_resource.id
  http_method = aws_api_gateway_method.create_event_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "create_event_options" {
  rest_api_id = aws_api_gateway_rest_api.event_announcement_api.id
  resource_id = aws_api_gateway_resource.create_event_resource.id
  http_method = aws_api_gateway_method.create_event_options.http_method
  status_code = aws_api_gateway_method_response.create_event_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_usage_plan" "rate_limit_plan" {
  name        = "event-announcement-rate-limit"
  description = "Rate limiting for event announcement API"

  api_stages {
    api_id = aws_api_gateway_rest_api.event_announcement_api.id
    stage  = aws_api_gateway_stage.dev.stage_name
  }

  throttle_settings {
    rate_limit  = 5    # 5 requests per second
    burst_limit = 10   # burst capacity of 10
  }

  quota_settings {
    limit  = 100       # 100 requests per day
    period = "DAY"
  }
}

resource "aws_api_gateway_api_key" "rate_limit_key" {
  name = "event-announcement-key"
}

resource "aws_api_gateway_usage_plan_key" "rate_limit_plan_key" {
  key_id        = aws_api_gateway_api_key.rate_limit_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.rate_limit_plan.id
}

resource "aws_cloudfront_origin_access_control" "event_announcement_frontend_oac" {
  name                              = "event-announcement-frontend-oac"
  description                       = "OAC for S3 bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "event_announcement_frontend_distribution" {
  enabled = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.frontend_event_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend_event_bucket.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.event_announcement_frontend_oac.id
  }

   default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend_event_bucket.id}"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"  # Force HTTPS
  }

  web_acl_id = aws_wafv2_web_acl.frontend_waf.arn

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "frontend_waf" {
  name        = "event-announcement-waf"
  scope       = "CLOUDFRONT"
  description = "WAF ACL to protect event announcement system"
 
  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 2000  # requests per 5 minutes
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "frontend_waf-metrics"
    sampled_requests_enabled   = true
  }
}
