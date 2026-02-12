
# --- 1. Networking Foundation ---
module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  vpc_cidr           = "10.0.0.0/16"
  public_sn_count    = 2
  private_sn_count   = 2
  availability_zones = var.availability_zones
}

# --- 2. Security (IAM & Security Groups) ---
module "security" {
  source = "./modules/security"

  project_name = var.project_name
  vpc_id       = module.networking.vpc_id
}

# --- 3. Stateful Infrastructure (Kafka, OpenSearch, DynamoDB) ---
module "stateful_infra" {
  source = "./modules/stateful_infra"

  project_name           = var.project_name
  private_subnet_ids     = module.networking.private_subnet_ids
  msk_sg_id              = module.security.msk_sg_id
  opensearch_sg_id       = module.security.opensearch_sg_id
  fargate_task_role_arn  = module.security.fargate_task_role_arn
  lambda_execution_role_arn = module.security.lambda_execution_role_arn
}

# --- 4. Ingestion Endpoint (API GW & Lambda) ---
module "ingestion" {
  source = "./modules/ingestion"

  project_name              = var.project_name
  lambda_execution_role_arn = module.security.lambda_execution_role_arn
  lambda_sg_id              = module.security.lambda_sg_id
  private_subnet_ids        = module.networking.private_subnet_ids
  kafka_brokers             = module.stateful_infra.msk_bootstrap_brokers
  kafka_topic               = module.stateful_infra.msk_topic_name
}

# --- 5. Compute Services (ECS/Fargate) ---
module "compute" {
  source = "./modules/compute"

  project_name                = var.project_name
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  fargate_sg_id               = module.security.fargate_sg_id
  fargate_task_execution_role_arn = module.security.fargate_task_execution_role_arn
  fargate_task_role_arn       = module.security.fargate_task_role_arn
  
  # Pass connection details to the Fargate tasks
  kafka_brokers               = module.stateful_infra.msk_bootstrap_brokers
  kafka_topic                 = module.stateful_infra.msk_topic_name
  opensearch_endpoint         = module.stateful_infra.opensearch_endpoint
  dynamodb_table_name         = module.stateful_infra.dynamodb_table_name
}
