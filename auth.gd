extends Node

# ───────────────────── 기본적으로 필요한 값들 ───────────────────── #
@export var clientId: String			#클라이언트 ID
@export var clientSecret: String		#클라이언트 시크릿
@export var tokenCode: String			#토큰 발급용 인증코드
@export var stateCode: String			#상태 코드 (랜덤 문자열)
@export var accessToken: String			#액세스 토큰
@export var refreshToken: String		#갱신 토큰
@export var socketUrl: String			#Socket.IO 엔드포인트 (프록시가 이곳으로 연결합니다)
@export var sessionKey: String			#소켓으로부터 받은 세션 키 (이벤트 구족 시 필요)
@export var redirectUrl: String = "https://localhost:8080"

# ───────────────────── 엔드포인트 ───────────────────── #
var authBody: String = "https://chzzk.naver.com/account-interlock"
var tokenBody: String = "https://openapi.chzzk.naver.com/auth/v1/token"
var revokeBody: String = "https://openapi.chzzk.naver.com/auth/v1/token/revoke"
var sessionBody: String = "https://openapi.chzzk.naver.com/open/v1/sessions/auth"
var eventBody: String = "https://openapi.chzzk.naver.com/open/v1/sessions/events"


# ───────────────────── 기타 변수들 ───────────────────── #
@onready var headers = ["User-Agent: Mozilla/5.0","Content-Type: application/json", "Authorization: Bearer CLIENT_SECRET"]
@onready var msgBox = $"../Control/TextEdit"

var proxyClient: ProxyWSClient		#프록시 클라이언트 (웹소켓 클라이언트)
var chzzkHandler: ChzzkEventHandler			#치지직 이벤트 핸들러

# ──────────────────────────────────────────────────────────────────────────────────── #
func _ready() -> void:
	#────────── 프록시 클리이언트 초기화 ───────────#
	proxyClient = ProxyWSClient.new()
	add_child(proxyClient)
	
	proxyClient.connected.connect(_on_proxy_connected)
	proxyClient.disconnected.connect(_on_proxy_disconnected)
	proxyClient.message_received.connect(_on_proxy_message)
	proxyClient.error_occurred.connect(_on_proxy_error)
	
	#─────────── 치지직 이벤트 핸들러 초기화 ───────────#
	chzzkHandler = ChzzkEventHandler.new()
	add_child(chzzkHandler)
	
	chzzkHandler.on_system_message.connect(_on_system_message)
	chzzkHandler.on_chat_received.connect(_on_chat_received)
	chzzkHandler.on_donation_received.connect(_on_cheese_received)
	chzzkHandler.on_subscription_received.connect(_on_subscription_received)
	
# ───────────────────── 인증 기능 함수 ───────────────────── #

# 인증코드 발급 URL을 만들고 해당 링크를 반환하는 함수
# 아래의 randomState() 함수를 STATE로 사용하면 됩니다
func getAuthUrl(CLIENT_ID: String, STATE: String) -> String:
	var completedUrl: String = str(authBody) + "?response_type=code" + "&clientId=" + CLIENT_ID + "&redirectUri=" + redirectUrl + "&state=" + STATE
	return completedUrl

#인증 시 사용하는 랜덤 문자열을 만드는 함수
func randomState(length: int, charset: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") -> String:
	var rng = RandomNumberGenerator.new(); rng.randomize()
	
	var randomString = ""
	for i in range(length):
		var randomIndex = rng.randi_range(0, charset.length() - 1)
		randomString += charset[randomIndex]
		
	return randomString

# 아래는 콜백 함수들입니다.
# 실제 API 요청은 아래의 REST API 함수가 처리하고, 해당 처리값을 받아와서 알맞게 추출하거나 결과를 표시합니다.

# 액세스 토큰 발급
func getAccessToken(RESULT: int, RESP_CODE: int, header: PackedStringArray, BODY: PackedByteArray) -> void:
	if RESULT != HTTPRequest.RESULT_SUCCESS: print("[GET] HTTP Request Error: ", RESULT)
	var rawResponse = BODY.get_string_from_utf8()
	
	if RESP_CODE == 200:
		var response = JSON.parse_string(rawResponse)
		var respToken = response["content"]
		if response:
			accessToken = respToken["accessToken"]
			refreshToken = respToken["refreshToken"]
			$"../Control/AccToken".text = accessToken
			$"../Control/RefToken".text = refreshToken
		else:
			_add_log(str("JSON Parsing Error: ", rawResponse))
	else:
		_add_log(str("HTTP Error %d: %s", RESP_CODE, rawResponse))

# 액세스 토큰 갱신
func refreshAccessToken(RESULT: int, RESP_CODE: int, header: PackedStringArray, BODY: PackedByteArray) -> void:
	if RESULT != HTTPRequest.RESULT_SUCCESS: print("[REFRESH] HTTP Request Error: ", RESULT)
	var rawResponse = BODY.get_string_from_utf8()
	
	if RESP_CODE == 200:
		var response = JSON.parse_string(rawResponse)
		var respToken = response["content"]
		if response:
			accessToken = respToken["accessToken"]
			refreshToken = respToken["refreshToken"]
			$"../Control/AccToken".text = accessToken
			$"../Control/RefToken".text = refreshToken
		else:
			_add_log(str("JSON Parsing Error: ", rawResponse))
	else:
		_add_log(str("HTTP Error %d: %s", RESP_CODE, rawResponse))

# 액세스 토큰 회수
func revokeAccessToken(RESULT: int, RESP_CODE: int, header: PackedStringArray, BODY: PackedByteArray) -> void:
	if RESULT != HTTPRequest.RESULT_SUCCESS: print("[REFRESH] HTTP Request Error: ", RESULT)
	var rawResponse = BODY.get_string_from_utf8()
	
	if RESP_CODE == 200:
		_add_log("Token Revoked Successfully.")
		accessToken = ""; refreshToken = "";
		$"../Control/AccToken".text = accessToken
		$"../Control/RefToken".text = refreshToken
	else:
		_add_log(str("HTTP Error %d: %s", RESP_CODE, rawResponse))

# Session API 접속정보 취득
func getSessionInfo(RESULT: int, RESP_CODE: int, header: PackedStringArray, BODY: PackedByteArray) -> void:
	if RESULT != HTTPRequest.RESULT_SUCCESS: print("[REFRESH] HTTP Request Error: ", RESULT)
	var rawResponse = BODY.get_string_from_utf8()
	
	if RESP_CODE == 200:
		var response = JSON.parse_string(rawResponse)
		var respUrl = response["content"]
		if response:
			socketUrl = respUrl["url"]
			$"../Control/socketUrl".text = socketUrl
		else:
			_add_log(str("JSON Parsing Error: ", rawResponse))
	else:
		_add_log(str("HTTP Error %d: %s", RESP_CODE, rawResponse))


# ───────────────────── REST API 함수 ───────────────────── #
var _on_complete_callback: Callable

# 대부분의 REST API 처리는 해당 함수에서 처리합니다. 인자를 받아서 RESTCaller 객체로 처리합니다.
# - REQ_TO: String, 어떤 엔드포인트에 요청을 전달할지 결정합니다.
# - BODY: Dictionary, 엔드포인트에 전달할 데이터 (Body)입니다.
# - METHOD: HTTPClient.Method, 엔드포인트에 접근할 때 사용할 메서드를 결정합니다. (HTTPClient.POST, HTTPClient.GET)
# - ON_COMPLETE: Callable, 실행 후 불러올 함수 (후처리 함수)를 선택합니다.

func restAPIRequest(REQ_TO: String, BODY: Dictionary, METHOD: HTTPClient.Method, ON_COMPLETE: Callable) -> void:
	_on_complete_callback = ON_COMPLETE
	var jsonPayload = JSON.stringify(BODY)
	var request = $"../RESTCaller"
	
	var currentHeaders = [ "User-Agent: Mozilla/5.0", "Content-Type: application/json", "Authorization: Bearer " + accessToken]
	var error = request.request(REQ_TO, currentHeaders, METHOD, jsonPayload)
	
	if error != OK: print("[ERR] Token Request Failed : ", error)

# 이벤트 구독 및 구독해제 (Session API) 처리는 해당 함수에서 처리합니다.
# 구독/구독해제 엔드포인트 주소를 조합하고, sessionKey를 실어서 최종적으로 SUBCaller 객체로 처리합니다.
# - ACTION: String("sub", "unsub"), 구독/구독해제 처리를 결정합니다.
# - EVENT: String("chat"...), 어떤 이벤트를 구독/구독해제할지 결정합니다. (평문이므로 주의)

func eventSubUnsub(ACTION: String, EVENT: String) -> void:
	var request = $"../SUBCaller"
	var currentHeaders = [ "User-Agent: Mozilla/5.0", "Content-Type: application/json", "Authorization: Bearer " + accessToken]
	var subUrl: String = ""
	match ACTION:
		"sub": subUrl = eventBody + "/subscribe/" + EVENT
		"unsub": subUrl = eventBody + "/unsubscribe/" + EVENT

	subUrl = subUrl + "?sessionKey=" + sessionKey
	var error = request.request(subUrl, currentHeaders, HTTPClient.METHOD_POST)
	if error != OK: print("[PUBSUB] SUb/Unsub Request Failed : ", error)
	
# ───────────────────── 프록시 클라이언트 시그널 ───────────────────── #
func _on_proxy_connected() -> void:
	_add_log("프록시 서버와 연결되었습니다.")
	proxyClient.set_token(accessToken, socketUrl)
	
func _on_proxy_disconnected() -> void:
	_add_log("프록시 서버와 연결이 해제되었습니다.")
	
func _on_proxy_message(message: Dictionary) -> void:
	var msgType = message.get("type", "")
	#print("프록시 서버 메시지: ", msgType)
	
	match msgType:
		"token_set":
			_add_log("프록시 서버에 인증 정보가 전달되었습니다.")
		"connection_status":
			var status = message.get("status", "")
			_add_log("프록시 연결 상태: " + status)
		"session_key":
			# SessionKey 수신
			var session_key = message.get("session_key", "")
			sessionKey = session_key  # 변수에 저장
			$"../Control/sessionKey".text = session_key
			_add_log("sessionKey 획득 완료: %s" % session_key)
		"socket_event":
			var event = message.get("event", "")
			var data = message.get("data", {})
			_add_log("소켓 이벤트 발생: " + event)
			chzzkHandler.handle_socket_event(event, data)
			#print("EVENT DATA: ", data)
		"error":
			var error_msg = message.get("message", "")
			_add_log("ERROR: " + error_msg)
	
func _on_proxy_error(error_message: String) -> void:
	_add_log("Proxy ERROR: " + error_message)

# ───────────────────── 치지직 이벤트 콜백 시그널 ───────────────────── #
# 단순 로그용으로 사용 중입니다.

func _on_system_message(message_type: String, data: Dictionary) -> void:
	#print("[시스템] %s: %s" % [message_type, data])
	
	match message_type:
		"connected":
			_add_log("세션 연결 완료!")
		"subscribed":
			var event_type = data.get("eventType", "")
			_add_log("이벤트 구독 완료: %s" % event_type)
		"unsubscribed":
			var event_type = data.get("eventType", "")
			_add_log("이벤트 구독 취소: %s" % event_type)

func _on_chat_received(chat_data: Dictionary) -> void:
	var nickname = chat_data.get("nickname", "Unknown")
	var senderId = chat_data.get("sender_channel_id", "000000")
	var message = chat_data.get("message", "")
	
	#print("[채팅] %s (%s): %s" % [nickname, senderId, message])
	_add_log("%s (%s): %s" % [nickname, senderId, message])
	
func _on_cheese_received() -> void:
	pass
	
func _on_subscription_received() -> void:
	pass

# ───────────────────── 버튼 시그널 ───────────────────── #
func _on_button_1_pressed() -> void:
	$"../Control/clientId".text = clientId
	$"../Control/clinetSecret".text = clientSecret
	stateCode = randomState(8)
	
	var authUrl: String = getAuthUrl(clientId, stateCode)
	OS.shell_open(authUrl)

func _on_button_2_pressed() -> void:
	tokenCode = $"../Control/tokenCode".text
	var requestBody = {
		"grantType": "authorization_code",
		"clientId": clientId,
		"clientSecret": clientSecret,
		"code": tokenCode,
		"state": stateCode,
		"redirectUri": redirectUrl
	}
	
	restAPIRequest(tokenBody, requestBody, HTTPClient.METHOD_POST, Callable(self, "getAccessToken"))

func _on_button_4_pressed() -> void:
	var requestBody = {
		"grantType": "refresh_token",
		"refreshToken": refreshToken,
		"clientId": clientId,
		"clientSecret": clientSecret
	}
	
	restAPIRequest(tokenBody, requestBody, HTTPClient.METHOD_POST, Callable(self, "refreshAccessToken"))
	
func _on_button_3_pressed() -> void:
	var requestBody = {
		"clientId": clientId,
		"clientSecret": clientSecret,
		"token": accessToken,
		"tokenTypeHint": "access_token"
	}
	
	restAPIRequest(revokeBody, requestBody, HTTPClient.METHOD_POST, Callable(self, "revokeAccessToken"))

func _on_btnGet_pressed() -> void:
	var requestBody = {}
	restAPIRequest(sessionBody, requestBody, HTTPClient.METHOD_GET, Callable(self, "getSessionInfo"))
	
func _on_btnConnect_pressed() -> void:
	proxyClient.connect_to_proxy()
	
func _on_btnChzzk_pressed() -> void:
	proxyClient.connect_to_chzzk()
	
func _on_btnSub_pressed() -> void:
	eventSubUnsub("sub", "chat")
	
func _on_btnUnsub_pressed() -> void:
	pass
	
func _on_api_caller_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _on_complete_callback:
		_on_complete_callback.call(result, response_code, headers, body)


func _add_log(text: String) -> void:
	msgBox.text += text + "\n"  # 기존 텍스트에 추가
	# 자동 스크롤 (맨 아래로)
	await get_tree().process_frame
	msgBox.scroll_vertical = msgBox.get_line_count()
