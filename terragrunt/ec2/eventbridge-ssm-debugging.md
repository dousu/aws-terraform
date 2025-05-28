# EventBridge SSM Automation デバッグガイド

このドキュメントは，EventBridgeからSSM Automationが自動実行されない問題のデバッグ方法をまとめています．

## 概要

EC2インスタンス起動時にEventBridgeルールでSSM Automationを自動実行する仕組みで発生した問題と，その調査・解決方法を記録しています．

## 問題の症状

- EventBridgeルールはEC2起動イベントを受信している
- SSM Automationの手動実行は成功する
- EventBridgeからの自動実行が失敗している
- CloudWatch MetricsでFailedInvocationsが発生

## デバッグ手順

### 1. EventBridge FailedInvocationsの確認

```bash
# EventBridgeルールの失敗を確認
aws cloudwatch get-metric-statistics \
  --region ap-northeast-1 \
  --namespace AWS/Events \
  --metric-name FailedInvocations \
  --dimensions Name=RuleName,Value=dousu-aws-terraform-personal-ec2-launch-rule \
  --start-time 2025-05-28T15:30:00Z \
  --end-time 2025-05-28T16:00:00Z \
  --period 300 \
  --statistics Sum \
  --output table
```

### 2. EventBridgeルールとターゲットの設定確認

```bash
# ルールの設定確認
aws events describe-rule \
  --region ap-northeast-1 \
  --name "dousu-aws-terraform-personal-ec2-launch-rule" \
  --output json

# ターゲットの設定確認
aws events list-targets-by-rule \
  --region ap-northeast-1 \
  --rule "dousu-aws-terraform-personal-ec2-launch-rule" \
  --output json
```

### 3. SSM Automation実行履歴の確認

```bash
# 最近のSSM Automation実行履歴
aws ssm describe-automation-executions \
  --region ap-northeast-1 \
  --filters "Key=StartTimeAfter,Values=2025-05-28T15:30:00Z" \
  --query 'AutomationExecutions[].[ExecutionId,DocumentName,AutomationExecutionStatus,StartTime,ExecutedBy]' \
  --output table

# 詳細情報
aws ssm describe-automation-executions \
  --region ap-northeast-1 \
  --filters "Key=StartTimeAfter,Values=2025-05-28T15:30:00Z" \
  --output json
```

### 4. SSM Documentの状態確認

```bash
# SSM Documentの基本情報
aws ssm describe-document \
  --region ap-northeast-1 \
  --name "dousu-aws-terraform-personal-install-cloudwatch-agent" \
  --output json

# SSM Documentの存在確認
aws ssm list-documents \
  --region ap-northeast-1 \
  --filters "Key=Name,Values=dousu-aws-terraform-personal-install-cloudwatch-agent" \
  --output table
```

### 5. IAM権限の確認

```bash
# EventBridge用ロールの権限確認
aws iam list-attached-role-policies \
  --region ap-northeast-1 \
  --role-name "dousu-aws-terraform-personal-eventbridge-ssm-role" \
  --output json

# IAMポリシーの内容確認
aws iam get-policy-version \
  --policy-arn "arn:aws:iam::xxxxxxxxxxxx:policy/dousu-aws-terraform-personal-eventbridge-ssm-policy" \
  --version-id v1 \
  --output json
```

### 6. 手動でSSM Automation実行テスト

```bash
# 手動実行でSSM Automationをテスト
aws ssm start-automation-execution \
  --region ap-northeast-1 \
  --document-name "dousu-aws-terraform-personal-install-cloudwatch-agent" \
  --parameters "InstanceId=i-xxxxxxxxxxxx,AutomationAssumeRole=arn:aws:iam::xxxxxxxxxxxx:role/dousu-aws-terraform-personal-ssm-automation-role" \
  --query 'AutomationExecutionId' \
  --output text

# 実行ステップの確認
aws ssm describe-automation-step-executions \
  --region ap-northeast-1 \
  --automation-execution-id "execution-id" \
  --query 'StepExecutions[].[StepName,StepStatus,FailureMessage]' \
  --output table
```

### 7. EC2インスタンスの状態確認

```bash
# インスタンスの起動時刻と状態確認
aws ec2 describe-instances \
  --region ap-northeast-1 \
  --instance-ids i-xxxxxxxxxxxx \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,LaunchTime]' \
  --output table
```

## 発見された問題と解決策

### 問題1: input_templateのパラメータ形式

**問題**: EventBridgeからSSM Automationにパラメータを渡す際の形式が間違っていた

**原因**: 
```json
// 間違った形式
{"InstanceId":"<instance>","AutomationAssumeRole":"arn:aws:iam::..."}

// 正しい形式
{"InstanceId":["<instance>"],"AutomationAssumeRole":["arn:aws:iam::..."]}
```

**解決策**: パラメータを配列形式に変更

### 問題2: EventBridgeターゲットのARN形式

**問題**: SSM AutomationのARN形式が不適切

**解決策**: 
```hcl
# 修正前
arn = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.cloudwatch_agent_install.name}"

# 修正後
arn = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.cloudwatch_agent_install.name}:$DEFAULT"
```

### 問題3: IAM権限の不足

**問題**: EventBridgeロールにSSM Automation実行とパスロール権限が不足

**解決策**: 
```hcl
# EventBridge用IAMポリシーに追加
resources = [
  "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.cloudwatch_agent_install.name}:$DEFAULT"
]

# PassRole権限の範囲を特定
resources = [
  aws_iam_role.ssm_automation_role.arn
]
```

### 問題4: SSM Automation実行用ロールの欠如

**問題**: AutomationAssumeRoleが設定されていない

**解決策**: SSM Automation実行専用のIAMロールとポリシーを作成

## 今後の改善案

1. **CloudWatch Logs統合**: EventBridgeルールのログ出力を有効化
2. **デッドレターキュー**: 失敗したイベントの詳細確認用
3. **アラート設定**: FailedInvocations発生時の通知
4. **定期的な動作確認**: 自動テストスクリプトの作成

## 参考情報

- [AWS EventBridge User Guide](https://docs.aws.amazon.com/eventbridge/)
- [AWS Systems Manager Automation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-automation.html)
- [EventBridge targets](https://docs.aws.amazon.com/eventbridge/latest/userguide/eventbridge-targets.html)
