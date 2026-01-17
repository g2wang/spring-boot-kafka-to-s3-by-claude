# Chargeback Microservice

A Spring Boot microservice that consumes chargeback messages from Kafka and writes them to AWS S3 or local filesystem with hourly partitioning.

## Features

- Consumes messages from Kafka topic "chargebacks"
- Transforms and validates chargeback data
- Writes to S3 or local filesystem with hourly partitioning (year/month/day/hour)
- Configurable storage backend (S3 or local)
- Manual offset acknowledgment for guaranteed processing
- Health checks and metrics endpoints
- Containerized with Docker

## Prerequisites

- Java 17 or higher
- Gradle 8.x
- Kafka cluster
- **For S3 storage:**
  - AWS S3 bucket named "chargebacks"
  - AWS credentials configured
- **For local storage:**
  - Write permissions to the configured local directory

## Project Structure

```
src/
├── main/
│   ├── java/com/example/chargeback/
│   │   ├── ChargebackApplication.java
│   │   ├── config/
│   │   │   ├── KafkaConsumerConfig.java
│   │   │   └── AwsS3Config.java
│   │   ├── consumer/
│   │   │   └── ChargebackConsumer.java
│   │   ├── model/
│   │   │   └── ChargebackMessage.java
│   │   └── service/
│   │       └── S3Service.java
│   └── resources/
│       └── application.yml
├── build.gradle
├── settings.gradle
└── Dockerfile
```

## Configuration

Configure via environment variables or `application.yml`:

### Storage Configuration

- `STORAGE_TYPE`: Storage backend type - `s3` or `local` (default: `s3`)
- `STORAGE_LOCAL_PATH`: Local directory path for file storage (default: `./data/chargebacks`)
  - Only used when `STORAGE_TYPE=local`

### Kafka Configuration

- `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker addresses (default: `localhost:9092`)

### AWS Configuration (only required when `STORAGE_TYPE=s3`)

- `AWS_REGION`: AWS region (default: `us-east-1`)
- `S3_BUCKET_NAME`: S3 bucket name (default: `chargebacks`)

## Storage Options

### S3 Storage

When `STORAGE_TYPE=s3`, files are written to AWS S3. The service requires AWS credentials and the following IAM permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::chargebacks/*"
    }
  ]
}
```

### Local Storage

When `STORAGE_TYPE=local`, files are written to the local filesystem at the path specified by `STORAGE_LOCAL_PATH`. This is useful for:
- Local development and testing
- Environments without AWS access
- Debugging and troubleshooting

The local directory structure mirrors the S3 partitioning structure.

## File Partitioning Structure

Files are partitioned by hour using the same structure for both S3 and local storage:

**S3:**
```
s3://chargebacks/
  year=2026/
    month=01/
      day=17/
        hour=14/
          {chargeback_id}_{uuid}.json
```

**Local:**
```
./data/chargebacks/
  year=2026/
    month=01/
      day=17/
        hour=14/
          {chargeback_id}_{uuid}.json
```

## Building the Application

```bash
# Build with Gradle
./gradlew build

# Build Docker image
docker build -t chargeback-service:latest .
```

## Running Locally

### Using S3 Storage

```bash
# Set environment variables
export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
export STORAGE_TYPE=s3
export AWS_REGION=us-east-1
export S3_BUCKET_NAME=chargebacks

# Run with Gradle
./gradlew bootRun

# Or run the JAR
java -jar build/libs/chargeback-service-0.0.1-SNAPSHOT.jar
```

### Using Local Storage

```bash
# Set environment variables
export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
export STORAGE_TYPE=local
export STORAGE_LOCAL_PATH=./data/chargebacks

# Run with Gradle
./gradlew bootRun

# Or run the JAR
java -jar build/libs/chargeback-service-0.0.1-SNAPSHOT.jar
```

**Note:** When using local storage, AWS credentials are not required and AWS S3 beans are not initialized.

## Running with Docker

### Using S3 Storage

```bash
docker run -d \
  -e KAFKA_BOOTSTRAP_SERVERS=your-kafka-broker:9092 \
  -e STORAGE_TYPE=s3 \
  -e AWS_REGION=us-east-1 \
  -e S3_BUCKET_NAME=chargebacks \
  -e AWS_ACCESS_KEY_ID=your-access-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret-key \
  -p 8080:8080 \
  chargeback-service:latest
```

### Using Local Storage

```bash
docker run -d \
  -e KAFKA_BOOTSTRAP_SERVERS=your-kafka-broker:9092 \
  -e STORAGE_TYPE=local \
  -e STORAGE_LOCAL_PATH=/app/data/chargebacks \
  -v $(pwd)/data:/app/data \
  -p 8080:8080 \
  chargeback-service:latest
```

**Note:** When using local storage in Docker, mount a volume to persist data outside the container.

## Deploying to AWS

### Using ECS/Fargate

1. Push Docker image to ECR:
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin {account-id}.dkr.ecr.us-east-1.amazonaws.com
docker tag chargeback-service:latest {account-id}.dkr.ecr.us-east-1.amazonaws.com/chargeback-service:latest
docker push {account-id}.dkr.ecr.us-east-1.amazonaws.com/chargeback-service:latest
```

2. Create ECS Task Definition with appropriate IAM role
3. Deploy as ECS Service

### Using EKS

1. Create Kubernetes deployment and service manifests
2. Apply ConfigMap for environment variables
3. Deploy with kubectl

## Kafka Message Format

Expected JSON format:
```json
{
  "transaction_id": "TXN123456",
  "chargeback_id": "CB789012",
  "amount": 99.99,
  "currency": "USD",
  "merchant_id": "MERCH001",
  "reason_code": "FRAUD",
  "timestamp": "2026-01-17T14:30:00",
  "customer_id": "CUST456",
  "card_last_four": "1234",
  "status": "PENDING"
}
```

## Health Checks

- Health endpoint: `http://localhost:8080/actuator/health`
- Metrics endpoint: `http://localhost:8080/actuator/metrics`

## Monitoring

The service logs all processed messages with correlation IDs for tracking. Monitor CloudWatch logs for production deployments.

## Error Handling

- Failed messages are not acknowledged and will be reprocessed
- Storage write failures (S3 or local) are logged and will trigger reprocessing
- Consider implementing dead letter queue for persistent failures

## Configuration Examples

### application.yml Example

```yaml
storage:
  type: local  # or 's3'
  local:
    path: ./data/chargebacks

kafka:
  topic:
    chargebacks: chargebacks

aws:
  region: us-east-1
  s3:
    bucket-name: chargebacks
```

### Environment Variables Example

```bash
# For local development
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=./data/chargebacks
KAFKA_BOOTSTRAP_SERVERS=localhost:9092

# For production with S3
STORAGE_TYPE=s3
AWS_REGION=us-east-1
S3_BUCKET_NAME=chargebacks
KAFKA_BOOTSTRAP_SERVERS=kafka-cluster:9092
```
