# ──────────────────────────────────────────────── #
#                     				Godot-프록시 웹소켓 클라이언트
#                           			Written by 블랙치이
# ──────────────────────────────────────────────── #
# 이 클래스는 Python으로 작성된 로컬 프록시 서버와 웹소켓을 통해 통신하는 클라이언트입니다.
# 프록시 서버는 치지직(Chzzk) 소켓과 연결되어 있으며, 이 클라이언트를 통해 치지직 이벤트를 수신하고 전송할 수 있습니다.
# 해당 코드를 사용하기 전 로컬 프록시 서버가 실행 중이여야 하고, proxy_url에 접속 정보를 입력해야 합니다.
# ──────────────────────────────────────────────── #

extends Node
class_name ProxyWSClient

# 시그널 정의
signal connected
signal disconnected
signal message_received(message: Dictionary)
signal error_occurred(error_message: String)

var websocket: WebSocketPeer
var proxy_url: String = "ws://127.0.0.1:8765/ws" #로컬 프록시 서버 주소입니다. 필요에 따라 변경 가능합니다.
var is_connected: bool = false



func _ready() -> void:
	websocket = WebSocketPeer.new()	# 기존에는 WebSocketClient였으나, WebSocketPeer로 변경
	set_process(true)				# 매 프레임마다 _process 함수가 호출되도록 설정 (지속적으로 폴링)

# 프록시 서버에 연결하는 함수 (반환값: 성공 여부 (bool)) ──────────────────────────────────────────
# 연결이 성공한 경우 true, 이미 연결되어 있거나 실패한 경우 false+오류 메시지를 반환합니다.
func connect_to_proxy() -> bool:
	if is_connected:
		push_error("이미 프록시 서버와 연결되어 있습니다.") # Godot 콘솔에 오류 메시지 출력 (디버거)
		return false
	
	var error = websocket.connect_to_url(proxy_url)
	
	if error != OK:
		var error_msg = "연결 중 오류 발생: " + str(error)
		print(error_msg) # 오류 발생 시 콘솔에 오류 메시지를 출력하고, 시그널로 오류 내용을 전송합니다.
		error_occurred.emit(error_msg)
		return false
	
	return true

# 프록시 서버와 연결을 종료하는 함수 ──────────────────────────────────────────
# 연결이 되어 있으면 소켓을 닫고, is_connected 플래그를 false로 설정합니다.
func disconnect_from_proxy() -> void:
	if websocket:
		websocket.close()
	is_connected = false

# 프록시 서버로 메시지를 전송하는 함수 (반환값: 성공 여부 (bool)) ──────────────────────────────────────────
# 연결이 되어 있지 않으면 false+오류 메시지를 반환합니다.
# 연결되어 있다면 message를 JSON으로 변환 후 전송하고, 성공 시 true를 반환합니다.
func send_message(message: Dictionary) -> bool:
	if not is_connected:
		var error_msg = "프록시 서버에 연결되어 있지 않습니다."
		print(error_msg)
		error_occurred.emit(error_msg)
		return false
	
	# message 딕셔너리를 JSON 문자열로 변환합니다.
	var json_message = JSON.stringify(message)
	
	
	var error = websocket.send_text(json_message)
	if error != OK:
		var error_msg = "메시지 전송 중 오류 발생: " + str(error)
		print(error_msg)
		error_occurred.emit(error_msg)
		return false
	
	return true

# 프록시에게 명령어를 전송하는 함수들 ───────────────────────────────────────────
# 각 함수는 프록시 서버로 특정 명령어를 포함한 메시지를 전송합니다.

# 액세스 토큰 및 소켓 URL 설정 
func set_token(access_token: String, socket_url: String) -> bool:
	var message = {
		"command": "set_token",
		"access_token": access_token,
		"socket_url": socket_url
	}
	return send_message(message)

# 치지직 소켓에 연결
func connect_to_chzzk() -> bool:
	var message = {
		"command": "connect"
	}
	return send_message(message)

# 치지직 소켓에서 연결 해제
func disconnect_from_chzzk() -> bool:
	var message = {
		"command": "disconnect"
	}
	return send_message(message)

# 치지직 소켓에 메시지 전송 (*사용할 일 없음)
func emit_to_chzzk(event: String, payload: Dictionary = {}) -> bool:
	var message = {
		"command": "emit",
		"event": event,
		"payload": payload
	}
	return send_message(message)

func _process(_delta: float) -> void:
	websocket.poll() # 웹소켓 상태를 계속 갱신합니다. (이게 없으면 접속이 불가능)
	var state = websocket.get_ready_state()
	
	# 웹소켓의 상태에 따라 연결/끊김 이벤트를 처리합니다.
	# STATE_OPEN(연결됨) 및 STATE_CLOSED(끊김) 상태를 감지하여 시그널을 발생시킵니다.
	match state:
		WebSocketPeer.STATE_OPEN:
			if not is_connected:
				is_connected = true
				print("✓ 프록시 서버에 연결되었습니다.")
				connected.emit()
		
		WebSocketPeer.STATE_CLOSED:
			if is_connected:
				is_connected = false
				print("✗ 프록시 서버와의 연결이 끊어졌습니다.")
				disconnected.emit()
	
	# 수신 메시지 처리
	if websocket.get_available_packet_count() > 0:
		_on_data_received()

# 수신된 데이터 처리 함수 ──────────────────────────────────────────
func _on_data_received() -> void:
	var message_text = websocket.get_packet().get_string_from_utf8()
	
	var json = JSON.new()
	var error = json.parse(message_text)
	
	if error != OK:
		var error_msg = "JSON 파싱 실패: " + message_text
		print(error_msg)
		error_occurred.emit(error_msg)
		return
	
	var message = json.data
	message_received.emit(message)
