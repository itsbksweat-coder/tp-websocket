import { DurableObject } from "cloudflare:workers";

const RECEIVER_PATH = "/ws1";
const SENDER_PATH = "/ws2";
const ROOM_NAME = "global";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/") {
      return Response.json({
        ok: true,
        service: "tp-websocket",
        receiver: RECEIVER_PATH,
        sender: SENDER_PATH,
      });
    }

    if (url.pathname !== RECEIVER_PATH && url.pathname !== SENDER_PATH) {
      return new Response("Not found", { status: 404 });
    }

    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("Expected WebSocket upgrade", { status: 426 });
    }

    const id = env.TP_RELAY.idFromName(ROOM_NAME);
    const stub = env.TP_RELAY.get(id);
    return stub.fetch(request);
  },
};

export class TriggerRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx = ctx;
  }

  async fetch(request) {
    const url = new URL(request.url);

    let role;
    if (url.pathname === RECEIVER_PATH) {
      role = "receiver";
    } else if (url.pathname === SENDER_PATH) {
      role = "sender";
    } else {
      return new Response("Not found", { status: 404 });
    }

    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("Expected WebSocket upgrade", { status: 426 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    this.ctx.acceptWebSocket(server, [role]);
    server.serializeAttachment({ role });

    server.send(
      JSON.stringify({
        type: "connected",
        role,
      }),
    );

    return new Response(null, {
      status: 101,
      webSocket: client,
    });
  }

  async webSocketMessage(ws, message) {
    const attachment = ws.deserializeAttachment() || {};
    const role = attachment.role;

    // Only /ws2 is allowed to publish TP requests.
    if (role !== "sender") {
      return;
    }

    if (typeof message !== "string") {
      this.safeSend(ws, {
        type: "error",
        error: "Text JSON messages only",
      });
      return;
    }

    let data;
    try {
      data = JSON.parse(message);
    } catch {
      this.safeSend(ws, {
        type: "error",
        error: "Invalid JSON",
      });
      return;
    }

    if (!data || data.type !== "join") {
      this.safeSend(ws, {
        type: "error",
        error: "Expected type=join",
      });
      return;
    }

    const placeId = Number(data.placeId);
    const jobId = String(data.jobId ?? "").trim();

    if (!Number.isSafeInteger(placeId) || placeId <= 0) {
      this.safeSend(ws, {
        type: "error",
        error: "Invalid placeId",
      });
      return;
    }

    if (!jobId || jobId.length > 200) {
      this.safeSend(ws, {
        type: "error",
        error: "Invalid jobId",
      });
      return;
    }

    const payload = JSON.stringify({
      type: "join",
      placeId,
      jobId,
    });

    let delivered = 0;

    for (const receiver of this.ctx.getWebSockets("receiver")) {
      try {
        receiver.send(payload);
        delivered += 1;
      } catch {
        // Ignore sockets that closed between getWebSockets() and send().
      }
    }

    this.safeSend(ws, {
      type: "sent",
      receivers: delivered,
    });
  }

  async webSocketClose() {
    // Cloudflare automatically completes close handshakes for this
    // compatibility date, so no manual cleanup is required.
  }

  async webSocketError() {
    // Disconnected sockets are automatically omitted by getWebSockets().
  }

  safeSend(ws, data) {
    try {
      ws.send(JSON.stringify(data));
    } catch {
      // Socket closed before the reply could be written.
    }
  }
}
