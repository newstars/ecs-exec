class EcsExecFzf < Formula
  desc "Interactive ECS container exec tool with FZF"
  homepage "https://github.com/newstars/ecs-exec-fzf"
  url "https://github.com/newstars/ecs-exec-fzf/archive/v1.0.0.tar.gz"
  sha256 "YOUR_SHA256_HERE"
  license "MIT"

  depends_on "awscli"
  depends_on "fzf"
  depends_on "session-manager-plugin"

  def install
    bin.install "ecs-exec-fzf.sh" => "ecs-exec-fzf"
  end

  def caveats
    <<~EOS
      ECS Exec FZF가 설치되었습니다!

      사용법:
        ecs-exec-fzf [region]

      예시:
        ecs-exec-fzf                    # ap-northeast-2 (기본값)
        ecs-exec-fzf us-west-2          # us-west-2 리전

      첫 실행 전에 AWS 설정이 필요합니다:
        aws configure sso

      필요한 IAM 권한:
        - ecs:ListClusters
        - ecs:ListServices
        - ecs:ListTasks
        - ecs:DescribeTasks
        - ecs:ExecuteCommand
        - ecs:UpdateService
        - ssm:StartSession
    EOS
  end

  test do
    assert_match "#!/bin/bash", shell_output("head -1 #{bin}/ecs-exec-fzf")
  end
end