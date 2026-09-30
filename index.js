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
    return env.TP_RELAY.get(id).fetch(request);
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

    server.send(JSON.stringify({
      type: "connected",
      role,
    }));

    return new Response(null, {
      status: 101,
      webSocket: client,
    });
  }

  async webSocketMessage(ws, message) {
    if (typeof message !== "string") {
      this.safeSend(ws, { type: "error", error: "Text JSON messages only" });
      return;
    }

    let data;
    try {
      data = JSON.parse(message);
    } catch {
      this.safeSend(ws, { type: "error", error: "Invalid JSON" });
      return;
    }

    const attachment = ws.deserializeAttachment() || {};
    const role = attachment.role;

    if (role === "receiver") {
      if (data?.type !== "register" && data?.type !== "update") {
        return;
      }

      const username = this.cleanText(data.username, 40);
      const displayName = this.cleanText(data.displayName || data.username, 60);
      const items = this.cleanItems(data.items);

      if (!username) {
        this.safeSend(ws, { type: "error", error: "Missing username" });
        return;
      }

      ws.serializeAttachment({
        role: "receiver",
        username,
        usernameLower: username.toLowerCase(),
        displayName,
        items,
      });

      this.safeSend(ws, {
        type: "registered",
        username,
        items: items.length,
      });

      this.broadcastPlayers();
      return;
    }

    if (role !== "sender") {
      return;
    }

    if (data?.type === "list") {
      this.sendPlayers(ws);
      return;
    }

    if (data?.type !== "join") {
      this.safeSend(ws, { type: "error", error: "Expected type=list or type=join" });
      return;
    }

    const placeId = Number(data.placeId);
    const jobId = String(data.jobId ?? "").trim();
    const target = this.cleanText(data.target, 40).toLowerCase();

    if (!Number.isSafeInteger(placeId) || placeId <= 0) {
      this.safeSend(ws, { type: "error", error: "Invalid placeId" });
      return;
    }

    if (!jobId || jobId.length > 200) {
      this.safeSend(ws, { type: "error", error: "Invalid jobId" });
      return;
    }

    const payload = JSON.stringify({
      type: "join",
      placeId,
      jobId,
      target: target || null,
    });

    let delivered = 0;

    for (const receiver of this.ctx.getWebSockets("receiver")) {
      const info = receiver.deserializeAttachment() || {};

      if (target && info.usernameLower !== target) {
        continue;
      }

      try {
        receiver.send(payload);
        delivered += 1;
      } catch {
        // Socket closed before send.
      }
    }

    this.safeSend(ws, {
      type: "sent",
      receivers: delivered,
      target: target || null,
    });
  }

  async webSocketClose(ws) {
    const info = ws.deserializeAttachment() || {};
    if (info.role === "receiver") {
      this.broadcastPlayers();
    }
  }

  async webSocketError(ws) {
    const info = ws.deserializeAttachment() || {};
    if (info.role === "receiver") {
      this.broadcastPlayers();
    }
  }

  cleanText(value, maxLength) {
    if (typeof value !== "string") return "";
    return value.trim().slice(0, maxLength);
  }

  cleanItems(value) {
    if (!Array.isArray(value)) return [];

    const out = [];
    const seen = new Set();

    for (const raw of value) {
      let name = "";
      let extra = "";

      if (typeof raw === "string") {
        name = raw.trim();
      } else if (raw && typeof raw === "object") {
        name = String(raw.name ?? "").trim();
        extra = String(raw.extra ?? "").trim();
      }

      if (!name) continue;

      name = name.slice(0, 80);
      extra = extra.slice(0, 120);

      const key = (name + "\0" + extra).toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);

      out.push(extra ? { name, extra } : { name });
      if (out.length >= 100) break;
    }

    return out;
  }

  playerList() {
    const players = [];

    for (const receiver of this.ctx.getWebSockets("receiver")) {
      const info = receiver.deserializeAttachment() || {};
      if (!info.username) continue;

      players.push({
        username: info.username,
        displayName: info.displayName || info.username,
        items: Array.isArray(info.items) ? info.items : [],
      });
    }

    players.sort((a, b) =>
      a.username.toLowerCase().localeCompare(b.username.toLowerCase())
    );

    return players;
  }

  sendPlayers(ws) {
    this.safeSend(ws, {
      type: "players",
      players: this.playerList(),
    });
  }

  broadcastPlayers() {
    const payload = JSON.stringify({
      type: "players",
      players: this.playerList(),
    });

    for (const sender of this.ctx.getWebSockets("sender")) {
      try {
        sender.send(payload);
      } catch {
        // Socket closed before update.
      }
    }
  }

  safeSend(ws, data) {
    try {
      ws.send(JSON.stringify(data));
    } catch {
      // Socket closed before reply.
    }
  }
}
