// Anifight 的連線中繼伺服器(Cloudflare Workers + Durable Objects)。
//
// 每個房間是一個 Room 物件,最多兩條 WebSocket 連線:開房間的人(host)和加入的人(guest)。
// 伺服器不懂遊戲內容,只做三件事:發房間號碼、讓第二個人用號碼加入、把一方送來的訊息原封不動轉給另一方。
//
// 連線方式
//   wss://<網址>/create          開房間。連上後會收到 {"sys":"room","code":"1234"}
//   wss://<網址>/join?code=1234  加入房間。
// 伺服器自己發的訊息都是帶有 "sys" 的 JSON 文字:
//   {"sys":"room","code":"1234"}        房間開好了(只有 host 會收到)
//   {"sys":"joined"}                    兩個人都到齊了(雙方都會收到)
//   {"sys":"left"}                      對方離開了
//   {"sys":"error","reason":"no_room"}  加入失敗:no_room(沒有這個房間)、full(已經有兩個人)、
//                                       bad_code(號碼格式不對)、busy(暫時開不出房間)。送完就斷線
// 其他訊息(文字或二進位)都是玩家之間的,直接轉送。
// 送出文字 "ping" 會立刻收到 "pong":用來保持連線、量延遲,不會吵醒房間。

import { DurableObject } from "cloudflare:workers";

// 只接受從這些網頁來的連線(瀏覽器會帶 Origin)。沒有 Origin 的是非瀏覽器的程式,例如測試和桌面版遊戲。
const ALLOWED_ORIGINS = [
  /^https:\/\/tyboy0407\.github\.io$/,
  /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/,
];
const CODE_TRIES = 16; // 開房間時最多抽幾次號碼
const MAX_MESSAGE = 2048; // 單則訊息的大小上限(位元組 / 字元)
const REFUSE_LINGER = 2000; // 拒絕連線後,等客戶端自己斷線最多等幾毫秒

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/") {
      return new Response("anifight relay ok\n");
    }
    if (url.pathname !== "/create" && url.pathname !== "/join") {
      return new Response("not found\n", { status: 404 });
    }
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("expected a websocket\n", { status: 426 });
    }
    const origin = request.headers.get("Origin");
    if (origin && !ALLOWED_ORIGINS.some((pattern) => pattern.test(origin))) {
      return new Response("forbidden\n", { status: 403 });
    }

    if (url.pathname === "/join") {
      const code = url.searchParams.get("code") ?? "";
      if (!/^\d{4}$/.test(code)) {
        return refuse("bad_code");
      }
      return room(env, code).fetch(`https://room/guest?code=${code}`, request);
    }

    // 開房間:抽一個沒有人在用的四位數號碼
    for (let attempt = 0; attempt < CODE_TRIES; attempt++) {
      const code = String(1000 + Math.floor(Math.random() * 9000));
      const stub = room(env, code);
      const probe = await stub.fetch("https://room/probe");
      if ((await probe.text()) === "free") {
        return stub.fetch(`https://room/host?code=${code}`, request);
      }
    }
    return refuse("busy");
  },
};

function room(env, code) {
  return env.ROOMS.get(env.ROOMS.idFromName(code));
}

// 連線先接起來、說明原因:這樣遊戲才看得到是哪一種失敗(直接回 HTTP 錯誤的話瀏覽器什麼都不說)。
// 說完不馬上掛斷:有的客戶端(Godot)同時收到訊息和掛斷時會把訊息丟掉。正常的客戶端看到原因會自己斷線,
// 沒有斷的過一會兒再由這邊掛斷。
function refuse(reason) {
  const pair = new WebSocketPair();
  const [client, server] = Object.values(pair);
  server.accept();
  server.send(JSON.stringify({ sys: "error", reason }));
  server.addEventListener("close", () => {
    try {
      server.close(1000);
    } catch {
      // 已經關掉了
    }
  });
  setTimeout(() => {
    try {
      server.close(4000, reason);
    } catch {
      // 已經關掉了
    }
  }, REFUSE_LINGER);
  return new Response(null, { status: 101, webSocket: client });
}

export class Room extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    // "ping" 由平台直接回 "pong",不必叫醒這個物件
    this.ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/probe") {
      return new Response(this.ctx.getWebSockets().length === 0 ? "free" : "busy");
    }

    const hosts = this.ctx.getWebSockets("host");
    const guests = this.ctx.getWebSockets("guest");
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    if (url.pathname === "/host") {
      if (hosts.length + guests.length > 0) {
        return refuse("busy"); // 剛好有人同時抽到同一個號碼
      }
      this.ctx.acceptWebSocket(server, ["host"]);
      server.send(JSON.stringify({ sys: "room", code: url.searchParams.get("code") }));
    } else {
      if (hosts.length === 0) {
        return refuse("no_room");
      }
      if (guests.length > 0) {
        return refuse("full");
      }
      this.ctx.acceptWebSocket(server, ["guest"]);
      const ready = JSON.stringify({ sys: "joined" });
      server.send(ready);
      hosts[0].send(ready);
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  // 房間裡的另一個人;還沒來或已經走了就是 undefined。
  other(socket) {
    const role = this.ctx.getTags(socket)[0];
    return this.ctx.getWebSockets(role === "host" ? "guest" : "host")[0];
  }

  webSocketMessage(socket, message) {
    const size = typeof message === "string" ? message.length : message.byteLength;
    if (size > MAX_MESSAGE) {
      this.farewell(socket);
      socket.close(1009, "message too big");
      return;
    }
    const peer = this.other(socket);
    if (peer) {
      peer.send(message);
    }
  }

  webSocketClose(socket, code) {
    this.farewell(socket);
    try {
      socket.close(code === 1005 || code === 1006 ? 1000 : code);
    } catch {
      // 已經關掉了
    }
  }

  webSocketError(socket) {
    this.farewell(socket);
  }

  // 告訴留下來的人對方走了(同一條連線只說一次)。
  farewell(socket) {
    if (socket.deserializeAttachment()?.gone) {
      return;
    }
    socket.serializeAttachment({ gone: true });
    const peer = this.other(socket);
    if (peer) {
      try {
        peer.send(JSON.stringify({ sys: "left" }));
      } catch {
        // 對方也剛好斷線
      }
    }
  }
}
