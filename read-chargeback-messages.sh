#!/bin/bash

# Script to read chargeback messages from Kafka
# Usage: ./read-chargeback-messages.sh [options]

set -e

# Configuration
KAFKA_BROKER="${KAFKA_BROKER:-localhost:9092}"
KAFKA_TOPIC="${KAFKA_TOPIC:-chargebacks}"
DOCKER_CONTAINER="${DOCKER_CONTAINER:-kafka}"
USE_DOCKER="${USE_DOCKER:-true}"
CONSUMER_GROUP="${CONSUMER_GROUP:-chargeback-reader-group}"
OFFSET="${OFFSET:-earliest}"
MAX_MESSAGES="${MAX_MESSAGES:-}"
FOLLOW="${FOLLOW:-false}"

# Function to check if Kafka is available
check_kafka() {
    if [ "$USE_DOCKER" = "true" ]; then
        if ! docker ps | grep -q "$DOCKER_CONTAINER"; then
            echo "Error: Kafka container '$DOCKER_CONTAINER' is not running."
            echo "Please start it with: docker-compose up -d"
            exit 1
        fi
    else
        if ! command -v kafka-console-consumer &> /dev/null; then
            echo "Error: kafka-console-consumer not found. Please install Kafka or use Docker."
            exit 1
        fi
    fi
}

# Function to read messages using Docker
read_via_docker() {
    local internal_broker="kafka:9093"
    local cmd_args=(
        "kafka-console-consumer"
        "--bootstrap-server" "$internal_broker"
        "--topic" "$KAFKA_TOPIC"
        "--from-beginning"
    )
    
    if [ "$OFFSET" = "latest" ]; then
        # Remove --from-beginning if offset is latest
        cmd_args=(
            "kafka-console-consumer"
            "--bootstrap-server" "$internal_broker"
            "--topic" "$KAFKA_TOPIC"
        )
    fi
    
    if [ -n "$MAX_MESSAGES" ] && [ "$MAX_MESSAGES" -gt 0 ]; then
        cmd_args+=("--max-messages" "$MAX_MESSAGES")
    fi
    
    if [ "$FOLLOW" = "true" ]; then
        cmd_args+=("--property" "print.timestamp=true")
        cmd_args+=("--property" "print.key=true")
        cmd_args+=("--property" "print.partition=true")
        cmd_args+=("--property" "print.offset=true")
    fi
    
    echo "Reading messages from topic '$KAFKA_TOPIC'..."
    if [ "$OFFSET" = "earliest" ]; then
        echo "Starting from: beginning of topic"
    else
        echo "Starting from: latest messages"
    fi
    
    if [ -n "$MAX_MESSAGES" ] && [ "$MAX_MESSAGES" -gt 0 ]; then
        echo "Maximum messages to read: $MAX_MESSAGES"
    fi
    
    if [ "$FOLLOW" = "true" ]; then
        echo "Following new messages (press Ctrl+C to stop)..."
        echo ""
    fi
    
    echo "========================================="
    echo ""
    
    docker exec -i "$DOCKER_CONTAINER" "${cmd_args[@]}"
}

# Function to read messages using local Kafka
read_via_local() {
    local cmd_args=(
        "kafka-console-consumer"
        "--bootstrap-server" "$KAFKA_BROKER"
        "--topic" "$KAFKA_TOPIC"
        "--from-beginning"
    )
    
    if [ "$OFFSET" = "latest" ]; then
        # Remove --from-beginning if offset is latest
        cmd_args=(
            "kafka-console-consumer"
            "--bootstrap-server" "$KAFKA_BROKER"
            "--topic" "$KAFKA_TOPIC"
        )
    fi
    
    if [ -n "$MAX_MESSAGES" ] && [ "$MAX_MESSAGES" -gt 0 ]; then
        cmd_args+=("--max-messages" "$MAX_MESSAGES")
    fi
    
    if [ "$FOLLOW" = "true" ]; then
        cmd_args+=("--property" "print.timestamp=true")
        cmd_args+=("--property" "print.key=true")
        cmd_args+=("--property" "print.partition=true")
        cmd_args+=("--property" "print.offset=true")
    fi
    
    echo "Reading messages from topic '$KAFKA_TOPIC'..."
    if [ "$OFFSET" = "earliest" ]; then
        echo "Starting from: beginning of topic"
    else
        echo "Starting from: latest messages"
    fi
    
    if [ -n "$MAX_MESSAGES" ] && [ "$MAX_MESSAGES" -gt 0 ]; then
        echo "Maximum messages to read: $MAX_MESSAGES"
    fi
    
    if [ "$FOLLOW" = "true" ]; then
        echo "Following new messages (press Ctrl+C to stop)..."
        echo ""
    fi
    
    echo "========================================="
    echo ""
    
    "${cmd_args[@]}"
}

# Function to list topic information
list_topic_info() {
    echo "Topic Information for '$KAFKA_TOPIC':"
    echo "========================================="
    
    if [ "$USE_DOCKER" = "true" ]; then
        local internal_broker="kafka:9093"
        docker exec "$DOCKER_CONTAINER" kafka-topics \
            --bootstrap-server "$internal_broker" \
            --describe \
            --topic "$KAFKA_TOPIC" 2>/dev/null || echo "Topic may not exist yet"
    else
        kafka-topics \
            --bootstrap-server "$KAFKA_BROKER" \
            --describe \
            --topic "$KAFKA_TOPIC" 2>/dev/null || echo "Topic may not exist yet"
    fi
    echo ""
}

# Main execution
main() {
    check_kafka
    
    if [ "$SHOW_INFO" = "true" ]; then
        list_topic_info
        exit 0
    fi
    
    if [ "$USE_DOCKER" = "true" ]; then
        read_via_docker
    else
        read_via_local
    fi
}

# Parse command line arguments
SHOW_INFO=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Read chargeback messages from Kafka topic"
            echo ""
            echo "Options:"
            echo "  -h, --help              Show this help message"
            echo "  -f, --follow            Follow/stream new messages (default: false)"
            echo "  -n, --max-messages NUM  Maximum number of messages to read"
            echo "  --offset OFFSET         Start offset: 'earliest' or 'latest' (default: earliest)"
            echo "  --latest                Start from latest messages (same as --offset latest)"
            echo "  --earliest             Start from beginning (same as --offset earliest)"
            echo "  --no-docker             Use local Kafka installation instead of Docker"
            echo "  --broker HOST:PORT      Override Kafka broker (default: localhost:9092)"
            echo "  --topic TOPIC           Override topic name (default: chargebacks)"
            echo "  --info                  Show topic information and exit"
            echo ""
            echo "Environment variables:"
            echo "  KAFKA_BROKER            Kafka broker address (default: localhost:9092)"
            echo "  KAFKA_TOPIC             Kafka topic name (default: chargebacks)"
            echo "  DOCKER_CONTAINER        Docker container name (default: kafka)"
            echo "  USE_DOCKER              Use Docker (true/false, default: true)"
            echo "  OFFSET                  Start offset: earliest or latest (default: earliest)"
            echo ""
            echo "Examples:"
            echo "  $0                      Read all messages from beginning"
            echo "  $0 --follow             Follow and stream new messages"
            echo "  $0 -n 5                 Read only 5 messages"
            echo "  $0 --latest             Read only new messages (from now)"
            echo "  $0 --follow --latest    Follow new messages from now"
            echo "  $0 --info               Show topic information"
            exit 0
            ;;
        -f|--follow)
            FOLLOW="true"
            shift
            ;;
        -n|--max-messages)
            MAX_MESSAGES="$2"
            shift 2
            ;;
        --offset)
            OFFSET="$2"
            if [ "$OFFSET" != "earliest" ] && [ "$OFFSET" != "latest" ]; then
                echo "Error: Offset must be 'earliest' or 'latest'"
                exit 1
            fi
            shift 2
            ;;
        --latest)
            OFFSET="latest"
            shift
            ;;
        --earliest)
            OFFSET="earliest"
            shift
            ;;
        --no-docker)
            USE_DOCKER="false"
            shift
            ;;
        --broker)
            KAFKA_BROKER="$2"
            shift 2
            ;;
        --topic)
            KAFKA_TOPIC="$2"
            shift 2
            ;;
        --info)
            SHOW_INFO="true"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

main
