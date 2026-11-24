class_name NetSession
extends Node
## 真人對戰的連線。掛在場景樹的根部,換場景(選角 → 對戰)時連線不會斷。
##
## 兩條路:
##   中繼:和中繼伺服器(server/src/index.js)之間的 WebSocket。開房間、加入房間、互傳選角這類
##         一定要送到的訊息都走這裡;直連不通時,對戰的按鍵也走這裡。
##   直連:雙方瀏覽器之間的 WebRTC 資料通道(只有網頁版有)。兩個人到齊之後,透過中繼互換連線資訊,
##         打得通就改用它傳對戰的按鍵,延遲比繞去中繼伺服器低很多;打不通就繼續用中繼。
##         直連刻意設成「不重送、不保證順序」,掉了的資料由對戰那邊每一格重送(見 main.gd)。
##
## 用法(都是輪詢,沒有訊號,這樣換場景時不會漏接):
##   var net := NetSession.get_session()
##   net.create_room() / net.join_room("1234") / net.leave()
##   net.status、net.code、net.role、net.direct、net.rtt_ms
##   net.send_message({...}) / net.take_messages()   一定送達、照順序的訊息(字典)
##   net.send_packet(bytes) / net.take_packets()      對戰用的小封包,可能掉、可能亂序
## take_messages() 裡除了對方送來的訊息,還有連線本身的事件(帶 "sys"):
##   {"sys":"room","code":"1234"}  房間開好了      {"sys":"joined"}  兩個人到齊
##   {"sys":"left"}                對方離開        {"sys":"closed"}  和伺服器斷線
##   {"sys":"error","reason":...}  no_room / full / bad_code / busy / offline(連不上伺服器)

enum Status { OFFLINE, CONNECTING, WAITING, PAIRED }

const STUN_SERVERS := ["stun:stun.l.google.com:19302", "stun:stun.cloudflare.com:3478"]
const PING_INTERVAL := 1.0
const CONNECT_TIMEOUT := 12.0
# 這兩種封包是連線層自己量延遲用的,不會交給遊戲
const PACKET_PING := 250
const PACKET_PONG := 251

static var _instance_id := 0

var status := Status.OFFLINE
var role := 0            # 1 = 開房間的人,2 = 加入的人
var code := ""
var direct := false      # 對戰的封包現在是不是走直連
var rtt_ms := -1.0       # 和對方之間來回一趟的時間;還沒量到是 -1
var relay_url: String = GameState.RELAY_URL
## 除錯用的計數:走中繼送出、收到幾個封包,送出失敗幾次。
var stats := {"sent": 0, "received": 0, "send_errors": 0}

var _socket: WebSocketPeer
var _connect_started := 0  # 開始連線的時間(毫秒)。這裡的計時都用真實時間,不受遊戲速度影響
var _messages: Array = []
var _packets: Array[PackedByteArray] = []
var _rtc: WebRTCPeerConnection
var _channel: WebRTCDataChannel
var _ping_at := 0  # 下一次量延遲的時間(毫秒)


## 取得掛在場景樹根部的連線;第一次呼叫時建立。
static func get_session() -> NetSession:
	var session := instance_from_id(_instance_id) as NetSession if _instance_id != 0 else null
	if session == null:
		session = NetSession.new()
		session.name = "NetSession"
		_instance_id = session.get_instance_id()
		# 場景還在建立時不能直接加到根節點,延後到這一幀結束
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(session)
	return session


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func create_room() -> void:
	_open("/create", 1)


func join_room(room_code: String) -> void:
	_open("/join?code=%s" % room_code.uri_encode(), 2)
	code = room_code


## 離開房間、切斷所有連線。
func leave() -> void:
	_close_direct()
	if _socket != null:
		_socket.close()
	_socket = null
	status = Status.OFFLINE
	role = 0
	code = ""
	rtt_ms = -1.0
	_messages.clear()
	_packets.clear()


## 送一則一定會到、照順序的訊息給對方(走中繼)。
func send_message(data: Dictionary) -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(data))


## 送一個對戰用的小封包:直連通了就走直連,否則走中繼。
func send_packet(bytes: PackedByteArray) -> void:
	if direct and _channel != null and _channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		_channel.put_packet(bytes)
	elif _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		stats.sent += 1
		if _socket.send(bytes) != OK:
			stats.send_errors += 1


## 取走目前收到的訊息與事件(字典),照收到的順序。
func take_messages() -> Array:
	var taken := _messages
	_messages = []
	return taken


## 把還沒處理的訊息放回去,留給下一個來拿的人(換場景時用)。
func put_back(messages: Array) -> void:
	_messages = messages + _messages


func take_packets() -> Array[PackedByteArray]:
	var taken := _packets
	_packets = []
	return taken


## 顯示用:現在走哪一條路、延遲多少。
func describe() -> String:
	var route := "直連" if direct else "中繼"
	return "%s %d ms" % [route, roundi(rtt_ms)] if rtt_ms >= 0.0 else route


func _open(path: String, as_role: int) -> void:
	leave()
	role = as_role
	status = Status.CONNECTING
	_connect_started = Time.get_ticks_msec()
	_socket = WebSocketPeer.new()
	if _socket.connect_to_url(relay_url + path) != OK:
		_fail("offline")


func _fail(reason: String) -> void:
	leave()
	_messages.append({"sys": "error", "reason": reason})


func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	# 先把收到的都看完再看連線狀態:伺服器拒絕加入時是「說明原因後馬上掛斷」,兩件事可能同一幀到
	while _socket != null and _socket.get_available_packet_count() > 0:
		var bytes := _socket.get_packet()
		if _socket.was_string_packet():
			_on_text(bytes.get_string_from_utf8())
		else:
			stats.received += 1
			_on_packet(bytes)
	if _socket == null:
		return
	match _socket.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			if Time.get_ticks_msec() - _connect_started > CONNECT_TIMEOUT * 1000.0:
				_fail("offline")
			return
		WebSocketPeer.STATE_CLOSED:
			# 還在連線就斷了:連不上伺服器。伺服器拒絕加入時會先說原因(見 _on_text),那時 _socket 已經清掉了
			var was_connecting := status == Status.CONNECTING
			leave()
			_messages.append({"sys": "error", "reason": "offline"} if was_connecting else {"sys": "closed"})
			return
	if _socket == null:
		return
	_tick_direct()
	if status == Status.PAIRED:
		if Time.get_ticks_msec() >= _ping_at:
			_ping_at = Time.get_ticks_msec() + int(PING_INTERVAL * 1000.0)
			var ping := PackedByteArray([PACKET_PING, 0, 0, 0, 0])
			ping.encode_u32(1, Time.get_ticks_msec() & 0xFFFFFFFF)
			send_packet(ping)


func _on_text(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	if data.has("sys"):
		match str(data.sys):
			"room":
				code = str(data.get("code", ""))
				status = Status.WAITING
			"joined":
				status = Status.PAIRED
				_ping_at = 0
				_start_direct()
			"left":
				# 對方走了:開房間的人留在房間裡等下一個人
				status = Status.WAITING
				rtt_ms = -1.0
				_close_direct()
			"error":
				_fail(str(data.get("reason", "offline")))
				return
		_messages.append(data)
	elif str(data.get("t", "")) == "rtc":
		_on_direct_signal(data)
	else:
		_messages.append(data)


func _on_packet(bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		return
	if bytes[0] == PACKET_PING and bytes.size() == 5:
		bytes[0] = PACKET_PONG
		send_packet(bytes)
	elif bytes[0] == PACKET_PONG and bytes.size() == 5:
		var sent := bytes.decode_u32(1)
		var elapsed := float(((Time.get_ticks_msec() & 0xFFFFFFFF) - sent) & 0xFFFFFFFF)
		# 取平滑過的數字,畫面上才不會一直跳
		rtt_ms = elapsed if rtt_ms < 0.0 else lerpf(rtt_ms, elapsed, 0.3)
	else:
		_packets.append(bytes)


# ---------- 直連(WebRTC) ----------

## 兩個人到齊後開始試著直連。只有網頁版做得到;桌面版(測試用)一律走中繼。
func _start_direct() -> void:
	_close_direct()
	if not OS.has_feature("web"):
		return
	_rtc = WebRTCPeerConnection.new()
	if _rtc.initialize({"iceServers": [{"urls": STUN_SERVERS}]}) != OK:
		_rtc = null
		return
	_rtc.session_description_created.connect(_on_direct_description)
	_rtc.ice_candidate_created.connect(_on_direct_candidate)
	# 雙方各自建立同一個編號的通道(不必再協商);不重送、不保證順序
	_channel = _rtc.create_data_channel("game", {"negotiated": true, "id": 1, "ordered": false, "maxRetransmits": 0})
	if _channel == null:
		_close_direct()
		return
	_channel.write_mode = WebRTCDataChannel.WRITE_MODE_BINARY
	if role == 1:
		_rtc.create_offer()


func _on_direct_description(type: String, sdp: String) -> void:
	if _rtc == null:
		return
	_rtc.set_local_description(type, sdp)
	send_message({"t": "rtc", "type": type, "sdp": sdp})


func _on_direct_candidate(media: String, index: int, candidate: String) -> void:
	send_message({"t": "rtc", "ice": [media, index, candidate]})


func _on_direct_signal(data: Dictionary) -> void:
	if _rtc == null:
		return
	if data.has("sdp"):
		_rtc.set_remote_description(str(data.get("type", "")), str(data.sdp))
	elif data.has("ice"):
		var ice: Array = data.ice
		if ice.size() == 3:
			_rtc.add_ice_candidate(str(ice[0]), int(ice[1]), str(ice[2]))


func _tick_direct() -> void:
	if _rtc == null:
		return
	_rtc.poll()
	if _channel == null:
		return
	var open := _channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN
	if open != direct:
		direct = open
		rtt_ms = -1.0  # 換了一條路,延遲重新量
		_ping_at = 0
	while open and _channel.get_available_packet_count() > 0:
		_on_packet(_channel.get_packet())


func _close_direct() -> void:
	direct = false
	if _channel != null:
		_channel.close()
	if _rtc != null:
		_rtc.close()
	_channel = null
	_rtc = null
