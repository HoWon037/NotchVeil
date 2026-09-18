# NotchVeil

NotchVeil은 노치가 있는 Mac의 메뉴 막대 뒤에 정적인 검은 배경을 놓는 작은 macOS 앱입니다.

- 노치 안전 영역을 시스템 API로 측정합니다.
- 다른 앱보다 뒤, 배경화면보다 앞에 검은 패널을 둡니다.
- 홈 화면에서는 노치 높이에서 끝나고, 양끝만 앱 모서리에 맞는 곡선으로 이어집니다.
- 클릭과 키보드 포커스를 가로채지 않습니다.
- 데스크탑 보기 애니메이션에도 검은 배경은 제자리에 유지됩니다.
- Mission Control에서는 시스템의 상단 공간 UI 뒤에 배치됩니다.
- 노치가 없는 외장 디스플레이에는 아무것도 표시하지 않습니다.
- 설정 창에서 검은 배경을 즉시 켜거나 끌 수 있습니다.
- 로그인 자동 실행과 메뉴 막대 아이콘 표시 여부를 선택할 수 있습니다.
- 설정 창을 닫아도 검은 배경과 앱은 계속 유지됩니다.
- 설정 창이 열려 있을 때는 Dock과 AltTab에 표시되고, 닫으면 백그라운드 앱으로 돌아갑니다.
- 로그인 자동 실행 시에는 설정 창 없이 저장된 노치 가리기 상태로 시작합니다.
- 앱을 업데이트해도 로그인 자동 실행 등록이 스스로 복구됩니다.

## 요구 사항

- macOS 12 이상 (노치가 있는 Mac). 노치가 없는 디스플레이에서는 아무것도 그리지 않습니다.
- 로그인 자동 실행은 macOS 13 이상에서만 사용할 수 있고, 그 아래에서는 설정 창의 토글이 비활성으로 표시됩니다.

## 실행

```sh
./scripts/run.sh
```

## 빌드와 서명

```sh
./scripts/build-app.sh
```

기본값은 애드혹 서명(`-`)입니다. 이 상태로도 앱은 실행되지만 macOS가 `SMAppService` 로그인 항목 등록을
거부하는 경우가 많아 "로그인할 때 자동 실행"이 실패할 수 있습니다. 자동 실행까지 확인하려면 Developer ID로
서명하십시오.

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh
```

## 설치

```sh
./scripts/install.sh
```

`/Applications`에 설치한 뒤 로그인 항목을 다시 등록합니다.

애드혹 서명에는 고정된 신원이 없어서, launchd는 로그인 항목을 등록 당시의 code identity(cdhash)에 묶어
둡니다. 앱을 새 빌드로 교체하면 이 값이 달라져 로그인 때 런처가 `EX_CONFIG`(78)로 실패하는데,
`SMAppService`는 계속 `.enabled`를 보고하기 때문에 겉으로는 멀쩡해 보입니다. 로그인해도 아무 일이 일어나지
않는 것이 유일한 증상입니다.

macOS 27에서 측정한 결과, 재등록이 반영되려면 두 조건이 모두 필요합니다.

- 번들이 바뀐 뒤 1분 남짓 지날 것
- 실행 중인 앱의 자손이 아닌 프로세스에서 등록할 것

그래서 앱은 이 상태를 감지해 로그로 알리기만 하고, 실제 재등록은 설치 스크립트가 맡습니다. `SMAppService`가
보고하는 상태도, launchd의 `needs LWCR update` 플래그도 재등록이 반영됐는지 알려주지 않기 때문에,
스크립트는 로그인 항목을 실제로 띄워보고 성공할 때까지 반복합니다.

수동으로는 다음과 같이 복구합니다. 한 번에 반영되지 않으면 1분쯤 뒤 다시 실행하십시오.

```sh
/Applications/NotchVeil.app/Contents/MacOS/NotchVeil --register-login-item
```

로그인 항목이 실제로 동작하는지는 다음으로 확인할 수 있습니다. `last exit code = 0`이면 정상,
`78: EX_CONFIG`이면 재등록이 필요합니다.

```sh
launchctl print gui/$(id -u)/com.limdy.NotchVeil.LoginLauncher | grep 'last exit'
```

Developer ID로 서명하면 제약이 팀 식별자 기준으로 걸려 이 문제 자체가 사라집니다.

## 종료

```sh
./scripts/stop.sh
```

## 테스트

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

현재 버전은 macOS 12를 최소 지원 버전으로 두고 macOS Golden Gate 27 베타에서 검증 중인 프로토타입입니다. 로그인 자동 실행과 메뉴 막대 아이콘은 기본적으로 꺼져 있습니다.
