# TP WebSocket Relay

Cloudflare Worker + Durable Object relay for two WebSocket endpoints:

- `/ws1` — receivers wait for teleport requests.
- `/ws2` — senders publish a `join` request.
- `/` — health/status response.

Message sent to `/ws2`:

```json
{
  "type": "join",
  "placeId": 109983668079237,
  "jobId": "ROBLOX_JOB_ID"
}
```

The relay forwards valid `join` messages to every currently connected `/ws1` socket, then replies to the sender with:

```json
{
  "type": "sent",
  "receivers": 1
}
```

## Cloudflare deployment

This repository is configured for Wrangler. The Worker name is `tp-websocket`, so on an account whose workers.dev subdomain is `xyzcheatz`, the endpoints are:

- `wss://tp-websocket.xyzcheatz.workers.dev/ws1`
- `wss://tp-websocket.xyzcheatz.workers.dev/ws2`

Deploy with:

```bash
npm install
npm run deploy
```

Or connect this repository under Cloudflare Workers & Pages and use `npm run deploy` as the deploy command.

The Durable Object binding is named `TP_RELAY` and the class is `TriggerRoom`.


## Discord base-find webhook

The Worker expects the Discord webhook URL in a Cloudflare secret named `DISCORD_WEBHOOK_URL`.
Do not commit the webhook URL to this public repository.

With Wrangler:

```bash
npx wrangler secret put DISCORD_WEBHOOK_URL
```

Paste the webhook URL when Wrangler prompts for the secret value, then deploy again.

In the Cloudflare dashboard, the equivalent is to add a secret/environment variable named
`DISCORD_WEBHOOK_URL` to the `tp-websocket` Worker and redeploy.

The Worker sends a Discord notification only when a receiver's non-empty base snapshot changes.
It also stores up to 200 numbered snapshots in Durable Object storage and displays them in
the site's **Stored Finds** section.
