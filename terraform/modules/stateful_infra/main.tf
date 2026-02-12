resource "aws_msk_cluster" "main" {
  cluster_name           = "${var.project_name}-msk-cluster"
  kafka_version          = "3.3.1"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type  = "kafka.t3.small"
    client_subnets = var.private_subnet_ids
    security_groups = [var.msk_sg_id]
    storage_info {
      ebs_storage_info {
        volume_size = 10
      }
    }
  }
  
  # Enable IAM role-based authentication
  client_authentication {
    sasl {
      iam = true
    }
  }

  tags = {
    Name = "${var.project_name}-msk-cluster"
  }
}

resource "aws_msk_topic" "clickstream" {
  cluster_arn = aws_msk_cluster.main.arn
  topic_name = "clickstream_events"
  partitions = 3
  replication_factor = 2
}

resource "aws_opensearch_domain" "main" {
  domain_name    = "${var.project_name}-clicks"
  engine_version = "OpenSearch_2.5"

  cluster_config {
    instance_type  = "t3.small.search"
    instance_count = 2
  }

  vpc_options {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.opensearch_sg_id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "*" # Locked down by the security group
        },
        Action = "es:*",
        Resource = "${aws_opensearch_domain.main.arn}/*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-opensearch-domain"
  }
}

resource "aws_dynamodb_table" "recommendations" {
  name           = "${var.project_name}-recommendations"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "UserID"

  attribute {
    name = "UserID"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-recommendations-table"
  }
}
