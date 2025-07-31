#!/bin/bash
set -euo pipefail

REGION=${1:-ap-northeast-2}

# 필수 도구 확인
check_requirements() {
  local missing=()
  command -v aws >/dev/null || missing+=("AWS CLI")
  command -v fzf >/dev/null || missing+=("FZF")
  command -v session-manager-plugin >/dev/null || missing+=("Session Manager Plugin")
  
  if [ ${#missing[@]} -gt 0 ]; then
    echo "❌ 누락된 도구: ${missing[*]}"
    echo ""
    echo "설치 방법:"
    echo "  brew install awscli session-manager-plugin fzf"
    echo ""
    echo "또는 자동 설치:"
    echo "  curl -fsSL https://raw.githubusercontent.com/newstars/ecs-exec-fzf/main/install.sh | bash"
    exit 1
  fi
}

# 스피너 애니메이션
show_spinner() {
  local pid=$1 msg="$2" spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
  while kill -0 $pid 2>/dev/null; do
    printf "\r%s %s" "${spin:$i:1}" "$msg"
    i=$(( (i+1) % ${#spin} ))
    sleep 0.1
  done
  printf "\r"
}

# 진행률 표시
show_progress() {
  local current=$1 total=$2 msg="$3"
  local percent=$((current * 100 / total)) filled=$((percent / 5)) empty=$((20 - filled))
  printf "\r%s [%*s%*s] %d%% (%d/%d)" "$msg" $filled "" $empty "" $percent $current $total | 
    tr ' ' '█' | sed 's/█/ /g; s/^\([^[]\+\[\)\([█]*\)/\1\2/; s/\([█]*\)\([^]]*\]\)/\1░\2/g'
}

# AWS 명령어 실행 (에러 처리 포함)
aws_exec() {
  local output
  if ! output=$("$@" 2>&1); then
    echo "❌ AWS 명령어 실행 실패: $*" >&2
    echo "$output" >&2
    return 1
  fi
  echo "$output"
}

# exec 권한 테스트
test_exec_permission() {
  aws ecs execute-command --region "$REGION" --cluster "$1" --task "$2" --container "$3" \
    --interactive --command "echo test" >/dev/null 2>&1
}

# 초기화
check_requirements

# AWS 프로파일 선택
select_profile() {
  local profiles
  profiles=$( ( \
    grep -E "^\[profile " ~/.aws/config 2>/dev/null | sed 's/\[profile //;s/\]//' ; \
    grep -E "^\[[a-zA-Z0-9_-]+\]" ~/.aws/credentials 2>/dev/null | sed 's/^\[\(.*\)\]/\1/' \
    ) | sort -u )
  
  [ -z "$profiles" ] && { echo "❌ AWS 프로파일이 없습니다. ~/.aws/config 또는 ~/.aws/credentials를 확인하세요."; exit 1; }
  
  echo "$profiles" | fzf --prompt="AWS 프로파일 선택 > " || { echo "프로파일 선택이 취소되었습니다."; exit 1; }
}

# SSO 로그인 확인
check_aws_auth() {
  if ! aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1; then
    echo "SSO 세션이 없습니다. 로그인 중... ($AWS_PROFILE)"
    aws sso login || { echo "SSO 로그인 실패. 종료합니다."; exit 1; }
  fi
}

AWS_PROFILE=$(select_profile)
export AWS_PROFILE
check_aws_auth

while true; do
  # 클러스터 선택
  CLUSTER=$( (echo ".. (뒤로 가기)"; aws ecs list-clusters \
    --region "$REGION" \
    --query 'clusterArns[*]' \
    --output text | tr '\t' '\n' | sed 's|.*/||') | \
    fzf --prompt="클러스터 선택 > ")
  [ -z "$CLUSTER" ] && echo "클러스터 선택이 취소되었습니다." && exit 1
  [ "$CLUSTER" = ".. (뒤로 가기)" ] && echo "이전 단계 없음. 종료합니다." && exit 0

  while true; do
    # 서비스 선택
    SERVICE=$( (echo ".. (뒤로 가기)"; aws ecs list-services \
      --region "$REGION" \
      --cluster "$CLUSTER" \
      --query 'serviceArns[*]' \
      --output text | tr '\t' '\n' | sed 's|.*/||') | \
      fzf --prompt="서비스 선택 > ")
    [ -z "$SERVICE" ] && echo "서비스 선택이 취소되었습니다. 클러스터 선택으로 돌아갑니다." && break
    [ "$SERVICE" = ".. (뒤로 가기)" ] && break

    while true; do
      # 태스크 선택
      TASK_ARN_LIST=$(aws ecs list-tasks \
        --region "$REGION" \
        --cluster "$CLUSTER" \
        --service-name "$SERVICE" \
        --desired-status RUNNING \
        --query 'taskArns[*]' \
        --output text)

      [ -z "$TASK_ARN_LIST" ] && echo "실행 중인 태스크가 없습니다." && break

      TASK_INFO_LIST=$(aws ecs describe-tasks \
        --region "$REGION" \
        --cluster "$CLUSTER" \
        --tasks $TASK_ARN_LIST \
        --query "tasks[*].{ID:taskArn, IP:attachments[0].details[?name=='privateIPv4Address'].value | [0]}" \
        --output text | awk '{ split($1, idParts, "/"); print idParts[length(idParts)], $2 }')

      TASK_LINE=$( (echo ".. (뒤로 가기)"; echo "$TASK_INFO_LIST") | \
        fzf --prompt="태스크 선택 (ID + IP) > " \
            --preview="aws ecs describe-tasks --region $REGION --cluster $CLUSTER --tasks {1} \
              --query 'tasks[0].{Status:lastStatus,LaunchType:launchType,StartedAt:startedAt,IP:attachments[0].details[?name==\`privateIPv4Address\`].value | [0]}' \
              --output yaml" )
      TASK=$(echo "$TASK_LINE" | awk '{print $1}')
      [ -z "$TASK" ] && echo "태스크 선택이 취소되었습니다. 서비스 선택으로 돌아갑니다." && break
      [ "$TASK" = ".." ] && break

      # 컨테이너 선택
      CONTAINER=$( (echo ".. (뒤로 가기)"; aws ecs describe-tasks \
        --region "$REGION" \
        --cluster "$CLUSTER" \
        --tasks "$TASK" \
        --query "tasks[0].containers[*].name" \
        --output text) | tr '\t' '\n' | \
        fzf --prompt="컨테이너 선택 > ")
      [ -z "$CONTAINER" ] && echo "컨테이너 선택이 취소되었습니다. 서비스 선택으로 돌아갑니다." && continue
      [ "$CONTAINER" = ".. (뒤로 가기)" ] && continue

      # 실행 가능 여부 확인
      aws ecs execute-command \
        --region "$REGION" \
        --cluster "$CLUSTER" \
        --task "$TASK" \
        --container "$CONTAINER" \
        --interactive \
        --command "echo test" >/dev/null 2>&1

      if [ $? -ne 0 ]; then
        echo ""
        echo "⚠️  이 태스크는 execute-command 기능이 비활성화되어 있습니다."
        echo ""
        echo "자동으로 권한을 활성화하고 재배포하시겠습니까?"
        echo "1) 예 - 자동 활성화 및 재배포"
        echo "2) 아니오 - 수동 명령어 표시"
        echo "3) 취소 - 태스크 선택으로 돌아가기"
        echo ""
        read -p "선택하세요 (1-3): " choice
        
        case $choice in
          1)
            echo ""
            printf "🔧 서비스 업데이트 중..."
            
            # 자동 권한 활성화 및 재배포
            enable_exec_and_redeploy() {
              printf "🔧 서비스 업데이트 중..."
              aws ecs update-service --region "$REGION" --cluster "$CLUSTER" --service "$SERVICE" \
                --enable-execute-command >/dev/null 2>&1 &
              show_spinner $! "🔧 execute-command 기능 활성화 중..."
              wait $! || { echo "❌ 서비스 업데이트 실패. 권한을 확인해주세요."; return 1; }
              
              echo "✅ execute-command 기능이 활성화되었습니다."
              printf "🚀 새로운 태스크 배포 중..."
              aws ecs update-service --region "$REGION" --cluster "$CLUSTER" --service "$SERVICE" \
                --force-new-deployment >/dev/null 2>&1 &
              show_spinner $! "🚀 새 태스크 배포 시작 중..."
              wait $! || { echo "❌ 재배포 실패. 수동으로 실행해주세요."; return 1; }
              
              echo "✅ 재배포가 시작되었습니다."
              echo "⏳ 새 태스크 준비 상태 확인 중..."
              
              for i in {1..30}; do
                show_progress $i 30 "대기 중"
                sleep 10
                
                local new_tasks first_task test_container
                new_tasks=$(aws ecs list-tasks --region "$REGION" --cluster "$CLUSTER" \
                  --service-name "$SERVICE" --desired-status RUNNING --query 'taskArns' --output text 2>/dev/null)
                
                if [ -n "$new_tasks" ] && [ "$new_tasks" != "None" ]; then
                  first_task=$(echo $new_tasks | awk '{print $1}' | sed 's|.*/||')
                  test_container=$(aws ecs describe-tasks --region "$REGION" --cluster "$CLUSTER" \
                    --tasks "$first_task" --query "tasks[0].containers[0].name" --output text 2>/dev/null)
                  
                  if [ -n "$test_container" ] && [ "$test_container" != "None" ] && \
                     test_exec_permission "$CLUSTER" "$first_task" "$test_container"; then
                    printf "\r✅ 새 태스크가 준비되었습니다! (exec 권한 확인됨)\n\n"
                    return 0
                  fi
                fi
                
                [ $i -eq 30 ] && { printf "\r⚠️  시간 초과. 수동으로 확인해주세요.\n"; return 1; }
              done
            }
            
            enable_exec_and_redeploy
            ;;
          2)
            echo ""
            echo "다음 명령어로 서비스에 기능을 활성화하세요:"
            echo ""
            echo "aws ecs update-service \\"
            echo "  --region $REGION \\"
            echo "  --cluster $CLUSTER \\"
            echo "  --service $SERVICE \\"
            echo "  --enable-execute-command \\"
            echo "  --profile $PROFILE"
            echo ""
            echo "그 후 아래 명령어로 태스크를 재시작하세요:"
            echo ""
            echo "aws ecs update-service \\"
            echo "  --region $REGION \\"
            echo "  --cluster $CLUSTER \\"
            echo "  --service $SERVICE \\"
            echo "  --force-new-deployment \\"
            echo "  --profile $PROFILE"
            echo ""
            ;;
          3|*)
            echo "취소되었습니다."
            ;;
        esac
        continue
      fi

      echo "접속 중: [$PROFILE] $CLUSTER / $SERVICE / $TASK → $CONTAINER"

      aws ecs execute-command \
        --region "$REGION" \
        --cluster "$CLUSTER" \
        --task "$TASK" \
        --container "$CONTAINER" \
        --interactive \
        --command "/bin/sh"

      echo ""
      echo "세션이 종료되었습니다. 다시 선택 화면으로 돌아갑니다."
      echo ""
    done
  done

done
