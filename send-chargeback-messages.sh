#!/bin/bash

# Script to send chargeback messages to Kafka
# Usage: ./send-chargeback-messages.sh [count]
#   count: Number of messages to send (default: 1)

set -e

# Configuration
KAFKA_BROKER="${KAFKA_BROKER:-localhost:9092}"
KAFKA_TOPIC="${KAFKA_TOPIC:-chargebacks}"
DOCKER_CONTAINER="${DOCKER_CONTAINER:-kafka}"
USE_DOCKER="${USE_DOCKER:-true}"

# Number of messages to send
COUNT=${1:-1}

# Function to check if Kafka is available
check_kafka() {
    if [ "$USE_DOCKER" = "true" ]; then
        if ! docker ps | grep -q "$DOCKER_CONTAINER"; then
            echo "Error: Kafka container '$DOCKER_CONTAINER' is not running."
            echo "Please start it with: docker-compose up -d"
            exit 1
        fi
    else
        if ! command -v kafka-console-producer &> /dev/null; then
            echo "Error: kafka-console-producer not found. Please install Kafka or use Docker."
            exit 1
        fi
    fi
}

# Function to generate a sample chargeback message
generate_chargeback_message() {
    local index=$1
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")
    local transaction_id="TXN-$(date +%s)-${index}"
    local chargeback_id="CB-$(date +%s)-${index}"
    local amount=$(awk "BEGIN {printf \"%.2f\", ($RANDOM % 10000) / 100}")
    local merchant_id="MERCHANT-$(($RANDOM % 1000))"
    local customer_id="CUST-$(($RANDOM % 10000))"
    local card_last_four=$(printf "%04d" $(($RANDOM % 10000)))
    
    # Array of reason codes
    local reason_codes=("4855" "4850" "4840" "4834" "4808" "4750")
    local reason_code=${reason_codes[$RANDOM % ${#reason_codes[@]}]}
    
    # Array of statuses
    local statuses=("PENDING" "APPROVED" "REJECTED" "UNDER_REVIEW")
    local status=${statuses[$RANDOM % ${#statuses[@]}]}
    
    # Array of currencies
    local currencies=("USD" "EUR" "GBP" "JPY")
    local currency=${currencies[$RANDOM % ${#currencies[@]}]}

    # line-delimited JSON, media type: application/x-ndjson
    # each line is a json message
    cat <<EOF
{ "transaction_id": "${transaction_id}", "chargeback_id": "${chargeback_id}", "amount": ${amount}, "currency": "${currency}", "merchant_id": "${merchant_id}", "reason_code": "${reason_code}", "timestamp": "${timestamp}", "customer_id": "${customer_id}", "card_last_four": "${card_last_four}", "status": "${status}" }
EOF
}

# Function to send messages using Docker
send_via_docker() {
    echo "Sending $COUNT chargeback message(s) to Kafka topic '$KAFKA_TOPIC' via Docker..."
    echo ""
    
    # Use internal broker address when running inside Docker container
    local internal_broker="kafka:9093"
    
    for i in $(seq 1 $COUNT); do
        message=$(generate_chargeback_message $i)
        echo "Sending message $i/$COUNT..."
        echo "$message" | docker exec -i "$DOCKER_CONTAINER" kafka-console-producer \
            --bootstrap-server "$internal_broker" \
            --topic "$KAFKA_TOPIC"
        
        if [ $? -eq 0 ]; then
            echo "✓ Message $i sent successfully"
        else
            echo "✗ Failed to send message $i"
        fi
        echo ""
    done
}

# Function to send messages using local Kafka
send_via_local() {
    echo "Sending $COUNT chargeback message(s) to Kafka topic '$KAFKA_TOPIC' via local Kafka..."
    echo ""
    
    for i in $(seq 1 $COUNT); do
        message=$(generate_chargeback_message $i)
        echo "Sending message $i/$COUNT..."
        echo "$message" | kafka-console-producer \
            --bootstrap-server "$KAFKA_BROKER" \
            --topic "$KAFKA_TOPIC"
        
        if [ $? -eq 0 ]; then
            echo "✓ Message $i sent successfully"
        else
            echo "✗ Failed to send message $i"
        fi
        echo ""
    done
}

# Function to send a custom message
send_custom_message() {
    local message="$1"
    if [ "$USE_DOCKER" = "true" ]; then
        local internal_broker="kafka:9093"
        echo "$message" | docker exec -i "$DOCKER_CONTAINER" kafka-console-producer \
            --bootstrap-server "$internal_broker" \
            --topic "$KAFKA_TOPIC"
    else
        echo "$message" | kafka-console-producer \
            --bootstrap-server "$KAFKA_BROKER" \
            --topic "$KAFKA_TOPIC"
    fi
}

# Main execution
main() {
    check_kafka
    
    if [ "$USE_DOCKER" = "true" ]; then
        send_via_docker
    else
        send_via_local
    fi
    
    echo "========================================="
    echo "Successfully sent $COUNT message(s) to topic '$KAFKA_TOPIC'"
    echo "========================================="
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [count] [options]"
        echo ""
        echo "Send chargeback messages to Kafka"
        echo ""
        echo "Arguments:"
        echo "  count              Number of messages to send (default: 1)"
        echo ""
        echo "Options:"
        echo "  -h, --help         Show this help message"
        echo "  --custom FILE      Send a custom JSON message from file"
        echo "  --no-docker        Use local Kafka installation instead of Docker"
        echo "  --broker HOST:PORT Override Kafka broker (default: localhost:9092)"
        echo "  --topic TOPIC      Override topic name (default: chargebacks)"
        echo ""
        echo "Environment variables:"
        echo "  KAFKA_BROKER       Kafka broker address (default: localhost:9092)"
        echo "  KAFKA_TOPIC        Kafka topic name (default: chargebacks)"
        echo "  DOCKER_CONTAINER   Docker container name (default: kafka)"
        echo "  USE_DOCKER         Use Docker (true/false, default: true)"
        echo ""
        echo "Examples:"
        echo "  $0                 Send 1 message"
        echo "  $0 5               Send 5 messages"
        echo "  $0 --custom msg.json  Send custom message from file"
        echo "  $0 --no-docker     Use local Kafka installation"
        exit 0
        ;;
    --custom)
        if [ -z "$2" ]; then
            echo "Error: --custom requires a file path"
            exit 1
        fi
        check_kafka
        if [ ! -f "$2" ]; then
            echo "Error: File '$2' not found"
            exit 1
        fi
        echo "Sending custom message from $2..."
        send_custom_message "$(cat "$2")"
        echo "Message sent successfully!"
        exit 0
        ;;
    --no-docker)
        USE_DOCKER="false"
        shift
        COUNT=${1:-1}
        main
        ;;
    --broker)
        KAFKA_BROKER="$2"
        shift 2
        COUNT=${1:-1}
        main
        ;;
    --topic)
        KAFKA_TOPIC="$2"
        shift 2
        COUNT=${1:-1}
        main
        ;;
    *)
        main
        ;;
esac
