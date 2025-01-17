# Container Monitor

Container monitor is a simple script designed to watch for docker `die` events. These events are emitted whenever a container is stopped. We then check the exit code and send a message to slack if the exit code indicated an error.

This service can be customized by setting the following env vars. These must be set, if not, the service will fail to start.

```
- SLACK_BOT_TOKEN
- SLACK_CHANNEL_NAME
- SLACK_BOT_NAME
- SLACK_BOT_AVATAR
```
