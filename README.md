# tincanOpener - 캔따개
### Godot-CHZZK 연동 플러그인 & WebSocket-CHZZK Socket.IO 프록시 

**캔따개**는 Godot 프로젝트에서 CHZZK의 Session API에 접속할 수 있는 핸들러를 제공하는 플러그인이자,
<br> Godot 및 여타 다른 WebSocket 지원 프로그램에서 치지직의 Socket.IO 서버에 접근할 수 있는 프록시 프로그램입니다.


> ### 왜 레포지트리 이름이 캔따개에요?
> 기존에 방송에 직접 사용하기 위해 제작하던 프로그램에서 관련 코드만 따온 거라,
<br> 방송 캐릭터인 '캔냥이' 의 꼬리라는 의미로 원래는 '캔꼬리' 로 하려고 했지만...
<br>  생각해보니 **캔 꼬리 = 캔따개**라서 이렇게 이름을 지었습니다!

## Godot 플러그인 사용하기
1. 해당 GitHub 저장소를 ZIP 파일로 내려받은 후, Godot 프로젝트 폴더에 ``/addon`` 폴더를 드래그 앤 드롭합니다.
2. Godot 프로젝트 설정에서 tincanOpener 애드온을 활성화합니다.
3. 씬에 직접 ``ProxyWebSocketClient``와 ``ChzzkEventHandler``를 추가하거나, 메인 스크립트에 아래와 같이 추가합니다:
```gdscript
var proxyClient: ProxyWebSocketClient		#프록시 클라이언트 (웹소켓 클라이언트)
var chzzkHandler: ChzzkEventHandler			#치지직 이벤트 핸들러

# ... 중략 ... #

func _ready() -> void:
  proxyClient = ProxyWebSocketClient.new()
  chzzkHandler = ChzzkEventHandler.new()
  add_child(proxyClient)
  add_child(chzzkHandler)
```
---
## 웹소켓 프록시만 사용하기
해당 레포지트리의 Release 탭에서 최신 버전을 내려받거나, `/proxy` 폴더에서 파이썬 파일을 내려받으실 수 있습니다.
<br> 파이썬 소스 설명의 경우에는 Wiki 페이지를 참고해주세요.
