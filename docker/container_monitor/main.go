package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/events"
	"github.com/docker/docker/client"
	"github.com/slack-go/slack"
)

func strictEnv(envVarName string) string {
	envVal := os.Getenv(envVarName)
	if envVal == "" {
		log.Fatalf("Error: Missing required environment variable %s.", envVarName)
	}
	return envVal
}

const tailLength = 20

func getContainerLogs(cli *client.Client, containerID string) (string, error) {
	ctx := context.Background()
	reader, err := cli.ContainerLogs(ctx, containerID, container.LogsOptions{
		ShowStdout: true,
		ShowStderr: true,
		Tail:       fmt.Sprintf("%d", tailLength),
	})
	if err != nil {
		return "", err
	}
	defer reader.Close()

	var logs strings.Builder
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		logs.WriteString(scanner.Text() + "\n")
	}

	if err := scanner.Err(); err != nil {
		return "", err
	}

	return logs.String(), nil
}

func main() {
	logger := log.New(os.Stdout, "", log.LstdFlags)
	slackToken := strictEnv("SLACK_BOT_TOKEN")
	slackChannel := strictEnv("SLACK_CHANNEL_NAME")
	slackBotName := strictEnv("SLACK_BOT_NAME")
	slackBotAvatar := strictEnv("SLACK_BOT_AVATAR")

	api := slack.New(slackToken)

	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		logger.Fatalf("Error creating Docker client: %v\n", err)
	}
	defer cli.Close()

	eventsChan, errsChan := cli.Events(context.Background(), events.ListOptions{})
	logger.Print("Listening for Docker events...\n")

	for {
		select {
		case event := <-eventsChan:
			if event.Type == events.ContainerEventType && event.Action == "die" {
				containerID := event.Actor.ID
				containerName := event.Actor.Attributes["name"]
				exitCode := event.Actor.Attributes["exitCode"]

				const exitedGracefully = "143"
				if exitCode != "0" && exitCode != exitedGracefully {
					message := fmt.Sprintf("Container %s exited unexpectedly with exit code %s.", containerName, exitCode)
					logger.Print("Sending Slack notification to channel", slackChannel, " with message:", message)

					postParams := slack.PostMessageParameters{
						Username: slackBotName,
						IconURL:  slackBotAvatar,
						Markdown: true,
					}

					channelID, timestamp, err := api.PostMessage(slackChannel, slack.MsgOptionText(message, false), slack.MsgOptionPostMessageParameters(postParams))
					if err != nil {
						logger.Fatalf("Failed to send Slack message: %v\n", err)
					}

					logger.Printf("Message sent to channel %s with timestamp: %s\n", channelID, timestamp)

					// Retrieve and send container logs
					logs, err := getContainerLogs(cli, containerID)
					if err != nil {
						logger.Printf("Failed to retrieve logs for container %s: %v\n", containerName, err)
						logs = "Unable to retrieve logs."
					}
					
					logMsg := fmt.Sprintf("Last %d lines of logs for container `%s`:\n```%s```", tailLength, containerName, logs)
					_, _, err = api.PostMessage(slackChannel, slack.MsgOptionText(logMsg, false), slack.MsgOptionPostMessageParameters(postParams), slack.MsgOptionTS(timestamp))
					if err != nil {
						logger.Fatalf("Failed to send logs thread message: %v\n", err)
					}

					// Send raw event JSON in the thread
					fullEventJSON, err := json.MarshalIndent(event, "", "  ")
					if err != nil {
						logger.Fatalf("Failed to marshal event to JSON: %v\n", err)
					}

					_, _, err = api.PostMessage(slackChannel, slack.MsgOptionText("Raw Event Data:\n```"+string(fullEventJSON)+"```", false), slack.MsgOptionPostMessageParameters(postParams), slack.MsgOptionTS(timestamp))
					if err != nil {
						logger.Fatalf("Failed to send raw event thread message: %v\n", err)
					}
				}
			}
		case err := <-errsChan:
			if err != nil {
				logger.Fatalf("Error reading Docker events: %v\n", err)
			}
		}
	}
}
