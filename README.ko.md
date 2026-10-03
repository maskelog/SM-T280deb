# SM-T280deb — Galaxy Tab A 7.0 (2016) Wi-Fi(SM-T280)용 Debian 13

SM-T280에서 vendor 3.10 커널로 Debian 13 "trixie"(armhf)를 실행합니다. 내장 화면의
XFCE 데스크톱, 터치, Wi-Fi, SSH가 동작합니다. 비공식 프로젝트이며 Samsung이나
Debian과 관계없습니다. **사용에 따른 책임은 사용자에게 있습니다.**

## 동작 상태

| 기능 | 상태 |
|---|---|
| 부팅 (서명된 boot 이미지 + initramfs, 루트는 내장 userdata) | 동작 |
| 화면 (Xorg fbdev + XFCE, 180° 회전) | 동작, 데스크톱은 소프트웨어 렌더링 |
| GPU (Mali-400 MP, OpenGL ES 2.0) | 전체 화면 fbdev GLES 앱에서 동작 (Mali r6p2 드라이버는 직접 준비), [docs/gpu.md](docs/gpu.md) 참고 |
| 터치 | 동작 |
| Wi-Fi (SC2331) | 동작, 상단바 아이콘(wpa_gui)에서 검색·연결. 본인 기기의 Android에서 펌웨어 로더 추출 필요 |
| USB 네트워크(RNDIS) + 시리얼 콘솔(ACM) | 동작, 케이블 재연결·PC 재인식 후에도 유지 (태블릿 192.168.7.2, PC는 192.168.7.10~99) |
| 화면 키보드(onboard) | 동작: 아래쪽 고정, 입력란을 누르면 자동 표시 |
| 화면 회전 | 세로/가로, `sm-t280-rotate` 또는 XFCE 메뉴 (데스크톱이 다시 시작됨) |
| 오디오, 카메라, 블루투스, 데스크톱 가속, 절전 | 미구현 |

## 준비물

- RECOVERY에 **TWRP**가 설치된 SM-T280 (TWRP는 그대로 남으며 복구 수단입니다)
- Linux 빌드 환경 (Debian/Ubuntu, WSL2 가능)
- **본인 기기**에서 TWRP로 뜬 덤프 (저장소 밖에 보관): 원래 `boot.img`(KERNEL), `system.img`(SYSTEM)

빌드·설치·복구 명령은 [README.md](README.md)와 같습니다.

## 주의

- 설치하면 **내장 저장소(userdata)가 지워집니다.** 사진 등은 미리 백업하세요.
- 저장소에는 Samsung/Spreadtrum 바이너리, 펌웨어, 서명 키가 없습니다. 펌웨어 로더는
  본인 기기에서 추출하고, `sprd_sign`은 빌드 때 원래 기기 트리 저장소에서 내려받습니다.
- `BRINGUP=1`로 빌드하면 시리얼 자동 로그인과 비밀번호 없는 sudo가 켜집니다.
  USB 케이블만 있으면 누구나 root가 되므로 개발용으로만 쓰세요.

## 라이선스

GPL-2.0 (`LICENSE`).
