#!/bin/bash

set -e

echo "🚀 ECS Exec FZF 설치 시작..."

# 운영체제 확인
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    *)          echo "❌ 지원하지 않는 운영체제: ${OS}"; exit 1;;
esac

echo "📋 운영체제: $MACHINE"

# 필수 도구 설치 함수
install_dependencies() {
    echo ""
    echo "📦 필수 도구 설치 중..."
    
    if [[ "$MACHINE" == "Mac" ]]; then
        # Homebrew 설치 확인
        if ! command -v brew &> /dev/null; then
            echo "🍺 Homebrew 설치 중..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        # 필수 패키지 설치
        echo "📦 AWS CLI 설치 중..."
        brew install awscli
        
        echo "📦 Session Manager Plugin 설치 중..."
        brew install --cask session-manager-plugin
        
        echo "📦 FZF 설치 중..."
        brew install fzf
        
    elif [[ "$MACHINE" == "Linux" ]]; then
        # Linux 배포판 확인
        if command -v apt-get &> /dev/null; then
            # Ubuntu/Debian
            echo "📦 패키지 업데이트 중..."
            sudo apt-get update
            
            echo "📦 AWS CLI 설치 중..."
            if ! command -v aws &> /dev/null; then
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install
                rm -rf aws awscliv2.zip
            fi
            
            echo "📦 Session Manager Plugin 설치 중..."
            if ! command -v session-manager-plugin &> /dev/null; then
                curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
                sudo dpkg -i session-manager-plugin.deb
                rm session-manager-plugin.deb
            fi
            
            echo "📦 FZF 설치 중..."
            sudo apt-get install -y fzf
            
        elif command -v yum &> /dev/null; then
            # CentOS/RHEL/Amazon Linux
            echo "📦 AWS CLI 설치 중..."
            if ! command -v aws &> /dev/null; then
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install
                rm -rf aws awscliv2.zip
            fi
            
            echo "📦 Session Manager Plugin 설치 중..."
            if ! command -v session-manager-plugin &> /dev/null; then
                curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
                sudo yum install -y session-manager-plugin.rpm
                rm session-manager-plugin.rpm
            fi
            
            echo "📦 FZF 설치 중..."
            sudo yum install -y fzf
        else
            echo "❌ 지원하지 않는 Linux 배포판입니다."
            exit 1
        fi
    fi
}

# 의존성 확인 함수
check_dependencies() {
    echo ""
    echo "🔍 필수 도구 확인 중..."
    
    local missing_deps=()
    
    if ! command -v aws &> /dev/null; then
        missing_deps+=("AWS CLI")
    fi
    
    if ! command -v session-manager-plugin &> /dev/null; then
        missing_deps+=("Session Manager Plugin")
    fi
    
    if ! command -v fzf &> /dev/null; then
        missing_deps+=("FZF")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "❌ 누락된 도구: ${missing_deps[*]}"
        echo ""
        read -p "자동으로 설치하시겠습니까? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_dependencies
        else
            echo "❌ 설치가 취소되었습니다."
            exit 1
        fi
    else
        echo "✅ 모든 필수 도구가 설치되어 있습니다."
    fi
}

# 스크립트 설치 함수
install_script() {
    echo ""
    echo "📝 ECS Exec FZF 스크립트 설치 중..."
    
    # 설치 디렉토리 생성
    INSTALL_DIR="/usr/local/bin"
    if [[ "$MACHINE" == "Mac" ]]; then
        INSTALL_DIR="/opt/homebrew/bin"
        if [[ ! -d "$INSTALL_DIR" ]]; then
            INSTALL_DIR="/usr/local/bin"
        fi
    fi
    
    # 스크립트 복사
    sudo cp "$(dirname "$0")/ecs-exec-fzf.sh" "$INSTALL_DIR/ecs-exec-fzf"
    sudo chmod +x "$INSTALL_DIR/ecs-exec-fzf"
    
    echo "✅ 스크립트가 $INSTALL_DIR/ecs-exec-fzf 에 설치되었습니다."
}

# 설정 확인 함수
check_aws_config() {
    echo ""
    echo "🔧 AWS 설정 확인 중..."
    
    if [[ ! -f ~/.aws/config ]] && [[ ! -f ~/.aws/credentials ]]; then
        echo "⚠️  AWS 설정이 없습니다."
        echo ""
        echo "다음 중 하나를 선택하여 AWS를 설정하세요:"
        echo "1. AWS SSO 설정: aws configure sso"
        echo "2. AWS 자격증명 설정: aws configure"
        echo "3. 환경변수 설정"
        echo ""
        read -p "지금 AWS SSO를 설정하시겠습니까? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            aws configure sso
        fi
    else
        echo "✅ AWS 설정이 확인되었습니다."
    fi
}

# 메인 실행
main() {
    check_dependencies
    install_script
    check_aws_config
    
    echo ""
    echo "🎉 설치가 완료되었습니다!"
    echo ""
    echo "사용법:"
    echo "  ecs-exec-fzf [region]"
    echo ""
    echo "예시:"
    echo "  ecs-exec-fzf                    # ap-northeast-2 (기본값)"
    echo "  ecs-exec-fzf us-west-2          # us-west-2 리전"
    echo ""
    echo "첫 실행 시 AWS SSO 로그인이 필요할 수 있습니다."
}

main "$@"