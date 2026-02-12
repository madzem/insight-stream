package main

import (
	"context"
	"encoding/json"
	"log"
	"net"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/segmentio/kafka-go"
)

// Define the structure of the incoming click event
type ClickEvent struct {
	UserID    string `json:"userId"`
	ProductID string `json:"productId"`
	EventType string `json:"eventType"`
	Timestamp int64  `json:"timestamp"`
}

var kafkaWriter *kafka.Writer

// Use init() to create the Kafka writer once per Lambda container
func init() {
	kafkaBrokers := os.Getenv("KAFKA_BROKERS")
	topic := os.Getenv("KAFKA_TOPIC")

	if kafkaBrokers == "" || topic == "" {
		log.Fatal("KAFKA_BROKERS and KAFKA_TOPIC must be set")
	}

	// kafka-go requires a resolver for DNS, which is standard for Lambda
	dialer := &kafka.Dialer{
		Timeout:   10 * time.Second,
		DualStack: true,
		Resolver:  &net.Resolver{},
	}

	kafkaWriter = &kafka.Writer{
		Addr:         kafka.TCP(strings.Split(kafkaBrokers, ",")...),
		Topic:        topic,
		Balancer:     &kafka.LeastBytes{},
		Dialer:       dialer,
		WriteTimeout: 10 * time.Second,
		ReadTimeout:  10 * time.Second,
	}
}

func HandleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	var event ClickEvent
	err := json.Unmarshal([]byte(request.Body), &event)
	if err != nil {
		log.Printf("Error unmarshalling request body: %v", err)
		return events.APIGatewayProxyResponse{Body: "Invalid request body", StatusCode: 400}, nil
	}

	// Basic validation
	if event.UserID == "" || event.Timestamp == 0 {
		return events.APIGatewayProxyResponse{Body: "Missing userId or timestamp", StatusCode: 400}, nil
	}

	// The key is important for partitioning in Kafka. Partitioning by UserID ensures
	// all events for a single user go to the same partition, preserving order.
	msg := kafka.Message{
		Key:   []byte(event.UserID),
		Value: []byte(request.Body),
	}

	err = kafkaWriter.WriteMessages(ctx, msg)
	if err != nil {
		log.Printf("Failed to write message to Kafka: %v", err)
		// This is a server-side error, so return 500
		return events.APIGatewayProxyResponse{Body: "Failed to process event", StatusCode: 500}, nil
	}

	log.Printf("Successfully produced message for user: %s", event.UserID)
	return events.APIGatewayProxyResponse{Body: `{"status": "event received"}`, StatusCode: 202}, nil
}

func main() {
	lambda.Start(HandleRequest)
}

