# 🚀 Microservices on AWS ECS (Fargate) + Terraform

## Architecture Overview

```
Internet
   │
   ▼
┌──────────────────────────────────────┐
│   Application Load Balancer (ALB)    │  ← Path-based routing
│   /users/* → user-service            │
│   /products/* → product-service      │
│   /orders/* → order-service          │
│   /* → api-gateway                   │
└────────────────┬─────────────────────┘
                 │  Private Subnets (Fargate)
    ┌────────────┼────────────────┐
    ▼            ▼                ▼
┌──────────┐ ┌──────────┐ ┌──────────────┐
│api-gateway│ │user-svc  │ │product-svc   │
│  :8000   │ │  :8001   │ │  :8002       │
└──────────┘ └──────────┘ └──────────────┘
                                ┌──────────────┐
                                │order-svc     │
                                │  :8003       │
                                └──────────────┘
        Service Discovery via AWS Cloud Map
        (*.myapp-dev.local)
```

## Services

| Service         | Port | Responsibility                            |
|----------------|------|-------------------------------------------|
| api-gateway     | 8000 | Reverse proxy, request routing            |
| user-service    | 8001 | User CRUD                                 |
| product-service | 8002 | Product catalogue & stock management      |
| order-service   | 8003 | Order creation, orchestrates other services|

## Infrastructure Components

| Component            | AWS Resource                        |
|---------------------|-------------------------------------|
| Container runtime    | ECS Fargate (serverless)            |
| Container images     | ECR (with image scanning)           |
| Load balancing       | ALB with path-based routing         |
| Service discovery    | AWS Cloud Map (private DNS)         |
| Auto scaling         | Application Auto Scaling (CPU/RAM)  |
| Networking           | VPC, public + private subnets, NAT  |
| Secrets              | AWS Secrets Manager                 |
| Logs                 | CloudWatch Logs                     |
| CI/CD                | GitHub Actions                      |

---

## Prerequisites

```bash
# Install tools
brew install terraform awscli docker

# Configure AWS credentials
aws configure
# Region: ap-south-1 (Mumbai) – or your preferred region
```

## Quick Start

### Step 1 – Bootstrap Terraform state bucket

```bash
aws s3 mb s3://myapp-terraform-state-dev --region ap-south-1
aws s3 mb s3://myapp-terraform-state-prod --region ap-south-1

aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

### Step 2 – Deploy infrastructure (dev)

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Step 3 – Build & push Docker images

```bash
# Get ECR login token
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com

# Build and push (replace ACCOUNT_ID)
ECR_BASE="<ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/myapp/dev"
TAG=$(git rev-parse --short HEAD)

for SERVICE in api-gateway user-service product-service order-service; do
  docker build -t "$ECR_BASE/$SERVICE:$TAG" services/$SERVICE/
  docker push "$ECR_BASE/$SERVICE:$TAG"
done
```

### Step 4 – Deploy services

```bash
# Update ECS services to pull new images
for SVC in api-gateway user-service product-service order-service; do
  aws ecs update-service \
    --cluster myapp-dev \
    --service $SVC \
    --force-new-deployment
done

# Wait for them to stabilize
aws ecs wait services-stable \
  --cluster myapp-dev \
  --services api-gateway user-service product-service order-service
```

### Step 5 – Test the deployment

```bash
# Get ALB URL from Terraform output
ALB_URL=$(terraform output -raw alb_url)

# Health checks
curl $ALB_URL/health
curl $ALB_URL/users/health
curl $ALB_URL/products/health
curl $ALB_URL/orders/health

# Create a user
curl -X POST $ALB_URL/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@example.com","password":"secret"}'

# Create a product
curl -X POST $ALB_URL/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","description":"Fast laptop","price":999.99,"stock":50,"category":"Electronics"}'
```

---

## CI/CD (GitHub Actions)

### Required Secrets

| Secret                  | Value                        |
|------------------------|------------------------------|
| `AWS_ACCESS_KEY_ID`     | IAM user access key          |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key          |

### Deploy Flow

```
Push to develop  →  test → build images → deploy to DEV
Push to main     →  test → build images → deploy to PROD
```

---

## Debugging

### ECS Exec (shell into a running container)

```bash
aws ecs execute-command \
  --cluster myapp-dev \
  --task <TASK_ARN> \
  --container user-service \
  --interactive \
  --command "/bin/sh"
```

### View logs

```bash
aws logs tail /ecs/myapp/dev --follow --filter-pattern "ERROR"
```

### Scale a service manually

```bash
aws ecs update-service \
  --cluster myapp-dev \
  --service user-service \
  --desired-count 3
```

---

## Directory Structure

```
microservice-project/
├── services/
│   ├── api-gateway/        # FastAPI reverse proxy
│   ├── user-service/       # User management
│   ├── product-service/    # Product catalogue
│   └── order-service/      # Order orchestration
├── terraform/
│   ├── modules/
│   │   ├── vpc/            # VPC, subnets, NAT
│   │   ├── ecs/            # ECS cluster, services, ALB, scaling
│   │   ├── ecr/            # Container registries
│   │   └── rds/            # Optional PostgreSQL
│   └── environments/
│       ├── dev/            # Dev environment entry point
│       └── prod/           # Prod environment entry point
├── .github/workflows/
│   └── deploy.yml          # CI/CD pipeline
└── docker-compose.yml      # Local development
```
