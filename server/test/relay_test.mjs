// 中繼伺服器的測試:模擬兩個玩家開房間、加入、互傳訊息、離開。
// 用法:node test/relay_test.mjs [網址]     網址預設是本機的 ws://127.0.0.1:8787
// 需要 Node.js 22 以上(用內建的 WebSocket)。

const base = (process.argv[2] ?? "ws://127.0.0.1:8787").replace(/^http/, "ws").replace(/\/$/, "");
let problems = 0;

function check(label, ok, detail = "") {
  if (!ok) problems += 1;
  console.log(`${ok ? "ok  " : "FAIL"} ${label} ${detail}`);
}

// 連上去,把收到的訊息排進佇列;next() 等下一則(逾時回傳 null)。
function connect(path) {
  const socket = new WebSocket(base + path);
  socket.binaryType = "arraybuffer";
  const queue = [];
  const waiting = [];
  const push = (item) => (waiting.length ? waiting.shift()(item) : queue.push(item));
  socket.addEventListener("message", (event) => push({ data: event.data }));
  socket.addEventListener("close", (event) => push({ closed: event.code, reason: event.reason }));
  socket.addEventListener("error", () => push({ error: true }));
  return {
    socket,
    opened: new Promise((resolve) => socket.addEventListener("open", resolve, { once: true })),
    next(timeout = 5000) {
      if (queue.length) return Promise.resolve(queue.shift());
      return new Promise((resolve) => {
        const timer = setTimeout(() => {
          waiting.splice(waiting.indexOf(done), 1);
          resolve(null);
        }, timeout);
        const done = (item) => {
          clearTimeout(timer);
          resolve(item);
        };
        waiting.push(done);
      });
    },
  };
}

const sys = (item) => (item && typeof item.data === "string" && item.data.startsWith("{") ? JSON.parse(item.data) : null);

const host = connect("/create");
const room = sys(await host.next());
check("create: host gets a 4-digit room code", room?.sys === "room" && /^\d{4}$/.test(room.code), JSON.stringify(room));
const code = room?.code ?? "0000";

const wrong = connect(`/join?code=${code === "1000" ? "1001" : "1000"}`);
const wrongReply = sys(await wrong.next());
// 另一個號碼幾乎一定沒人在用;萬一真的有人在用,會是 full 而不是 no_room
check("join: unknown room is refused", wrongReply?.sys === "error" && ["no_room", "full"].includes(wrongReply.reason), JSON.stringify(wrongReply));
check("join: refused connection is closed after a moment", (await wrong.next())?.closed === 4000);

const bad = connect("/join?code=12ab");
check("join: malformed code is refused", sys(await bad.next())?.reason === "bad_code");

const guest = connect(`/join?code=${code}`);
check("join: guest is told the room is ready", sys(await guest.next())?.sys === "joined");
check("join: host is told the guest arrived", sys(await host.next())?.sys === "joined");

const third = connect(`/join?code=${code}`);
check("join: a third player is refused", sys(await third.next())?.reason === "full");

host.socket.send("hello from host");
check("relay: text host -> guest", (await guest.next())?.data === "hello from host");
guest.socket.send(JSON.stringify({ t: "pick", character: 8 }));
check("relay: text guest -> host", (await host.next())?.data === '{"t":"pick","character":8}');
guest.socket.send(new Uint8Array([1, 2, 3, 250]).buffer);
const binary = (await host.next())?.data;
check("relay: binary guest -> host", binary instanceof ArrayBuffer && [...new Uint8Array(binary)].join() === "1,2,3,250");

// 連發 120 則(兩秒份的按鍵),順序和數量都要對
for (let frame = 0; frame < 120; frame++) host.socket.send(new Uint8Array([frame, frame >> 8, 7]).buffer);
let inOrder = true;
for (let frame = 0; frame < 120; frame++) {
  const item = await guest.next();
  inOrder = inOrder && item?.data instanceof ArrayBuffer && new Uint8Array(item.data)[0] === frame;
}
check("relay: 120 input frames arrive in order", inOrder);

const pings = [];
for (let i = 0; i < 5; i++) {
  const sent = performance.now();
  host.socket.send("ping");
  const reply = await host.next();
  if (reply?.data === "pong") pings.push(performance.now() - sent);
}
check("ping: answered with pong", pings.length === 5, `round trip ${pings.map((ms) => ms.toFixed(0)).join(" ")} ms`);
check("ping: not forwarded to the other player", (await guest.next(400)) === null);

guest.socket.send("x".repeat(3000));
check("limit: oversized message closes the sender", (await guest.next())?.closed === 1009);
check("leave: host is told the guest left", sys(await host.next())?.sys === "left");

const again = connect(`/join?code=${code}`);
check("rejoin: the seat is free again", sys(await again.next())?.sys === "joined");
check("rejoin: host is told", sys(await host.next())?.sys === "joined");
host.socket.close();
check("leave: guest is told the host left", sys(await again.next())?.sys === "left");
again.socket.close();
await new Promise((resolve) => setTimeout(resolve, 500));

const late = connect(`/join?code=${code}`);
check("empty room is gone", sys(await late.next())?.reason === "no_room");

console.log(`problems: ${problems}`);
for (const peer of [host, wrong, bad, guest, third, again, late]) {
  try {
    peer.socket.close();
  } catch {}
}
setTimeout(() => process.exit(problems ? 1 : 0), 200);
