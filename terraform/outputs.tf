output "api_gateway_invoke_url" {
  description = "The URL to POST clickstream events to."
  value       = module.ingestion.api_gateway_invoke_url
}
