#!/bin/bash

REGION=${1:-ap-northeast-2}

# 1. AWS 프로파일 선택 (config + credentials)
PROFILE=$( (
  grep -E "^\[profile " ~/.aws/config 2>/dev/null | sed 's/\[profile //;s/\]//' ;
  grep -E "^\[[a-zA-Z0-9_-]+\]" ~/.aws/credentials 2>/dev/null | sed 's/^\[\(.*\)\]/\1/'
  ) | sort -u | fzf --prompt="AWS 프로파일 선택 > ")

[ -z "$PROFILE" ] && echo "프로파일 선택이 취소되었습니다." && exit 1
export AWS_PROFILE="$PROFILE"

# 2. SSO 세션 확인 및 로그인
aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "SSO 세션이 없습니다. 로그인 중... ($PROFILE)"
  aws sso login
  if [ $? -ne 0 ]; then
    echo "SSO 로그인 실패. 종료합니다."
    exit 1
  fi
fi

while true; do
  # 3. 클러스터 선택
  CLUSTER=$( (echo ".. (뒤로 가기)"; aws ecs list-clusters     --region "$REGION"     --query 'clusterArns[*]'     --output text | tr '\t' '\n' | sed 's|.*/||') |     fzf --prompt="클러스터 선택 > ")
  [ -z "$CLUSTER" ] && echo "클러스터 선택이 취소되었습니다." && exit 1
  [ "$CLUSTER" = ".. (뒤로 가기)" ] && echo "이전 단계 없음. 종료합니다." && exit 0

  # 4. 서비스 선택
  SERVICE=$( (echo ".. (뒤로 가기)"; aws ecs list-services     --region "$REGION"     --cluster "$CLUSTER"     --query 'serviceArns[*]'     --output text | tr '\t' '\n' | sed 's|.*/||') |     fzf --prompt="서비스 선택 > ")
  [ -z "$SERVICE" ] && echo "서비스 선택이 취소되었습니다. 클러스터 선택으로 돌아갑니다." && continue
  [ "$SERVICE" = ".. (뒤로 가기)" ] && continue

  # 5. 태스크 목록 + IP + 상태 preview
  TASKS=$(aws ecs list-tasks     --region "$REGION"     --cluster "$CLUSTER"     --service-name "$SERVICE"     --desired-status RUNNING     --query 'taskArns[*]'     --output text)

  [ -z "$TASKS" ] && echo "실행 중인 태스크가 없습니다." && continue

  TASK_INFO_LIST=""
  for TASK_ARN in $TASKS; do
    TASK_ID=$(basename "$TASK_ARN")
    IP=$(aws ecs describe-tasks       --region "$REGION"       --cluster "$CLUSTER"       --tasks "$TASK_ID"       --query "tasks[0].attachments[?type=='ElasticNetworkInterface'].details[?name=='privateIPv4Address'].value"       --output text)
    TASK_INFO_LIST+="$TASK_ID   $IP"$'\n'
  done

  TASK_LINE=$( (echo ".. (뒤로 가기)"; echo "$TASK_INFO_LIST") |     fzf --prompt="태스크 선택 (ID + IP) > "         --preview="aws ecs describe-tasks --region $REGION --cluster $CLUSTER --tasks {1}           --query 'tasks[0].{Status:lastStatus,LaunchType:launchType,StartedAt:startedAt,IP:attachments[0].details[?name==\`privateIPv4Address\`].value | [0]}'           --output yaml" )
  TASK=$(echo "$TASK_LINE" | awk '{print $1}')
  [ -z "$TASK" ] && echo "태스크 선택이 취소되었습니다. 클러스터 선택으로 돌아갑니다." && continue
  [ "$TASK" = ".." ] && continue

  # 6. 컨테이너 선택
  CONTAINER=$( (echo ".. (뒤로 가기)"; aws ecs describe-tasks     --region "$REGION"     --cluster "$CLUSTER"     --tasks "$TASK"     --query "tasks[0].containers[*].name"     --output text) | tr '\t' '\n' |     fzf --prompt="컨테이너 선택 > ")
  [ -z "$CONTAINER" ] && echo "컨테이너 선택이 취소되었습니다. 클러스터 선택으로 돌아갑니다." && continue
  [ "$CONTAINER" = ".. (뒤로 가기)" ] && continue

  # 7. execute-command 기능 활성화 여부 확인
  IS_EXEC_ENABLED=$(aws ecs describe-tasks     --region "$REGION"     --cluster "$CLUSTER"     --tasks "$TASK"     --query 'tasks[0].enableExecuteCommand'     --output text)

  if [ "$IS_EXEC_ENABLED" != "true" ]; then
    echo ""
    echo "이 태스크는 execute-command 기능이 비활성화되어 있습니다."
    echo ""
    echo "다음 명령어로 서비스에 기능을 활성화하세요:"
    echo ""
    echo "aws ecs update-service \"
    echo "  --region $REGION \"
    echo "  --cluster $CLUSTER \"
    echo "  --service $SERVICE \"
    echo "  --enable-execute-command"
    echo ""
    echo "그 후 아래 명령어로 태스크를 재시작하세요:"
    echo ""
    echo "aws ecs update-service --region $REGION --cluster $CLUSTER --service $SERVICE --force-new-deployment"
    echo ""
    exit 1
  fi

  # 8. execute-command 실행
  echo "접속 중: [$PROFILE] $CLUSTER / $SERVICE / $TASK → $CONTAINER"

  aws ecs execute-command     --region "$REGION"     --cluster "$CLUSTER"     --task "$TASK"     --container "$CONTAINER"     --interactive     --command "/bin/sh"

  break
done
