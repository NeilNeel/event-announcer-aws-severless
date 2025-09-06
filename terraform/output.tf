output "api_gateway_subscribe_url" {
  description = "URL for the subscribe endpoint"
  value       = "https://${aws_api_gateway_rest_api.event_announcement_api.id}.execute-api.${var.aws_region}.amazonaws.com/dev/subscribe"
}

output "api_gateway_event_url" {
  description = "URL for the create event endpoint"
  value       = "https://${aws_api_gateway_rest_api.event_announcement_api.id}.execute-api.${var.aws_region}.amazonaws.com/dev/event" 
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for frontend hosting"
  value       = aws_s3_bucket.frontend_event_bucket.bucket
}

output "s3_bucket_website_url" {
  description = "Website URL of the S3 bucket"
  value       = aws_s3_bucket_website_configuration.frontend_event_bucket_config.website_endpoint
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.event_announcement_frontend_distribution.domain_name
}
