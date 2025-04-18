# ecs-exec-fzf

`aws ecs execute-command` 기능을 더 편리하게 사용할 수 있도록 만든 `fzf` 기반 CLI 도구입니다.  
ECS 클러스터 / 서비스 / 태스크 / 컨테이너를 터미널에서 인터랙티브하게 선택하고 바로 셸 접속할 수 있습니다.

## 주요 기능

- `~/.aws/config` 및 `~/.aws/credentials`에서 AWS 프로파일 자동 추출
- `fzf`로 클러스터, 서비스, 태스크, 컨테이너 순서대로 선택
- 태스크 IP 및 상태 실시간 미리보기 지원 (`fzf --preview`)
- SSO 세션 자동 확인 및 필요 시 로그인
- `execute-command` 비활성화 시 안내 및 활성화 방법 출력
- 뒤로 가기 옵션 지원

## 사용 방법

```bash
chmod +x ecs-exec-fzf.sh

./ecs-exec-fzf.sh               # 기본 리전은 ap-northeast-2
./ecs-exec-fzf.sh us-west-2     # 다른 리전 지정
```

## 필요 도구

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [fzf](https://github.com/junegunn/fzf)
- [session-manager-plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- jq (선택사항, 미리보기 출력용)

## 프로젝트 구조

```
ecs-exec-fzf/
├── ecs-exec-fzf.sh    # 메인 실행 스크립트
├── LICENSE            # MIT 라이선스
└── README.md          # 사용 설명서
```

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. 자유롭게 사용, 복제, 수정 및 배포할 수 있으며,  
단 저작권 고지 및 라이선스 원문을 반드시 포함해야 합니다.

자세한 내용은 [LICENSE](LICENSE) 파일을 참고하세요.