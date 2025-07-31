# ECS Exec FZF

AWS ECS 컨테이너에 대화형으로 접속할 수 있는 FZF 기반 도구입니다.

## ✨ 주요 기능

- 🎯 **대화형 선택**: FZF를 사용한 직관적인 클러스터/서비스/태스크/컨테이너 선택
- 🔧 **자동 권한 활성화**: exec 권한이 없을 때 자동으로 활성화 및 재배포
- 📊 **진행상황 표시**: 스피너와 진행률 바로 실시간 상태 확인
- 🔄 **SSO 지원**: AWS SSO 자동 로그인 처리
- 🌏 **다중 프로파일**: AWS 프로파일 선택 지원

## 🚀 설치

### 원클릭 설치 (권장)

```bash
# 모든 의존성과 함께 자동 설치
curl -fsSL https://raw.githubusercontent.com/newstars/ecs-exec-fzf/main/install.sh | bash
```

### Homebrew

```bash
# 탭 추가
brew tap newstars/ecs-exec-fzf https://github.com/newstars/ecs-exec-fzf

# 설치 (의존성 자동 설치)
brew install ecs-exec-fzf
```

### 수동 설치

```bash
# 저장소 클론
git clone https://github.com/newstars/ecs-exec-fzf.git
cd ecs-exec-fzf

# 자동 설치 스크립트 실행
chmod +x install.sh
./install.sh
```

## 📋 필수 요구사항

- **AWS CLI v2**: AWS 서비스 접근
- **Session Manager Plugin**: ECS exec 기능
- **FZF**: 대화형 선택 인터페이스
- **Bash**: 스크립트 실행 환경

## 🔧 AWS 설정

### SSO 설정 (권장)
```bash
aws configure sso
```

### 일반 자격증명 설정
```bash
aws configure
```

## 🎮 사용법

```bash
# 기본 리전 (ap-northeast-2)
ecs-exec-fzf

# 특정 리전 지정
ecs-exec-fzf us-west-2
```

## 🔐 필요한 IAM 권한

### 기본 권한 (읽기 + 접속)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:ListClusters",
        "ecs:ListServices", 
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "ecs:ExecuteCommand"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:StartSession"
      ],
      "Resource": "*"
    }
  ]
}
```

### 자동 권한 활성화 기능 사용 시 추가 권한
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService"
      ],
      "Resource": "*"
    }
  ]
}
```

> 💡 **팁**: `ecs:UpdateService` 권한이 없어도 기본 기능은 사용 가능하며, 권한이 없을 때 수동 명령어를 제공합니다.

## 🎯 사용 시나리오

### 1. 일반적인 접속
1. AWS 프로파일 선택
2. 클러스터 선택
3. 서비스 선택
4. 태스크 선택 (IP 주소 표시)
5. 컨테이너 선택
6. 자동 접속

### 2. Exec 권한이 없는 경우 (자동 해결)

권한이 없을 때 3가지 옵션을 제공합니다:

#### 옵션 1: 자동 활성화 및 재배포 ✨
```
⚠️  이 태스크는 execute-command 기능이 비활성화되어 있습니다.

자동으로 권한을 활성화하고 재배포하시겠습니까?
1) 예 - 자동 활성화 및 재배포
2) 아니오 - 수동 명령어 표시  
3) 취소 - 태스크 선택으로 돌아가기
```

**자동 처리 과정:**
1. 🔧 서비스에 `enable-execute-command` 활성화
2. 🚀 새 태스크 강제 배포 시작
3. ⏳ 새 태스크 준비 상태 실시간 확인 (진행률 바)
4. ✅ exec 권한 테스트 후 접속 가능

#### 옵션 2: 수동 명령어 제공
필요한 AWS CLI 명령어를 복사 가능한 형태로 제공

#### 옵션 3: 취소
태스크 선택 화면으로 돌아가기

## 🔧 설치 스크립트 기능

`install.sh`는 다음을 자동으로 처리합니다:

- ✅ 운영체제 감지 (macOS/Linux)
- ✅ 필수 도구 설치 확인
- ✅ 누락된 도구 자동 설치
- ✅ AWS 설정 확인 및 가이드
- ✅ 스크립트를 시스템 PATH에 설치

### 지원 플랫폼
- **macOS**: Homebrew 사용
- **Ubuntu/Debian**: apt-get 사용  
- **CentOS/RHEL/Amazon Linux**: yum 사용

## 🛠️ 개발

### 로컬 테스트
```bash
chmod +x ecs-exec-fzf.sh
./ecs-exec-fzf.sh
```

### Formula 업데이트
```bash
# SHA256 계산
shasum -a 256 ecs-exec-fzf-1.0.0.tar.gz

# Formula 파일의 sha256 값 업데이트
```

## 📝 라이선스

MIT License

## 🤝 기여

이슈와 PR을 환영합니다!

## 📞 지원

문제가 있으시면 GitHub Issues를 통해 문의해주세요.