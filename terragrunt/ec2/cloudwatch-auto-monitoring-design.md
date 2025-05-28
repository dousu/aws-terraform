# EC2 起動時 CloudWatch 監視自動化設計資料

## 概要

EC2 インスタンスが起動された際に，自動的に CloudWatch Agent をインストールし，メモリやストレージ容量のメトリクス収集を開始する仕組みを構築します．EventBridge と SSM Automation を組み合わせた完全自動化システムの設計を以下に示します．

## アーキテクチャ概要

```
EC2 起動 → EventBridge Rule → SSM Automation → CloudWatch Agent インストール・設定 → メトリクス収集開始
```

## 詳細設計

### 1. EventBridge Rule

#### 目的
EC2 インスタンスの起動イベントを検知し，自動的に後続処理をトリガーします．

#### イベントパターン
```json
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": {
    "state": ["running"]
  }
}
```

#### ターゲット
- SSM Automation Document の実行

### 2. SSM Automation Document

#### 目的
CloudWatch Agent のインストールと設定を自動化します．

#### 実行ステップ
1. **前提条件チェック**
   - インスタンスの状態確認
   - SSM Agent の動作確認
   - 必要な IAM ロールの確認

2. **CloudWatch Agent インストール**
   - OS タイプの判定（Linux/Windows）
   - パッケージマネージャーを使用したインストール
   - インストール結果の検証

3. **設定ファイル適用**
   - SSM Parameter Store から設定を取得
   - CloudWatch Agent 設定ファイルの配置
   - 設定の検証

4. **サービス起動**
   - CloudWatch Agent サービスの開始
   - 自動起動設定の有効化
   - 動作確認

### 3. SSM Parameter Store 設定

#### CloudWatch Agent 設定
パラメータ名: `/cloudwatch/agent/config`

#### 設定内容
```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_time_wait"
        ],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
```

### 4. IAM ロール・ポリシー設計

#### EventBridge 用ロール
必要な権限:
- SSM Automation の実行権限

#### 前提条件
EC2 インスタンスには既存の IAM ロールが適用されており，以下の権限が付与されていることを前提とします:
- `CloudWatchAgentServerPolicy`（AWS 管理ポリシー）
- `AmazonSSMManagedInstanceCore`（AWS 管理ポリシー）
- Parameter Store 読み取り権限

#### カスタムポリシー例
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/cloudwatch/agent/*"
    }
  ]
}
```

## Terraform リソース構成

### 必要なリソース

1. **EventBridge Rule**
   - `aws_cloudwatch_event_rule`
   - `aws_cloudwatch_event_target`

2. **SSM Automation Document**
   - `aws_ssm_document`

3. **SSM Parameter**
   - `aws_ssm_parameter`（CloudWatch Agent 設定）

4. **IAM リソース**
   - `aws_iam_role`（EventBridge 用）
   - `aws_iam_role_policy_attachment`
   - `aws_iam_policy`（EventBridge 用カスタムポリシー）

5. **CloudWatch Log Group**
   - `aws_cloudwatch_log_group`（Agent ログ用）

## 運用考慮事項

### 監視項目
- CloudWatch Agent のインストール成功率
- メトリクス収集の開始確認
- エラーログの監視

### トラブルシューティング
- SSM Automation の実行ログ確認
- CloudWatch Agent のステータス確認
- IAM ロールの権限確認

### セキュリティ
- 最小権限の原則に基づいた IAM ポリシー設計
- Parameter Store での設定の暗号化
- CloudWatch Logs の適切な保持期間設定

## 拡張可能性

### カスタムメトリクス
追加のメトリクス収集が必要な場合，Parameter Store の設定を更新することで対応可能です．

### マルチリージョン対応
各リージョンに同様の構成をデプロイすることで，グローバルな監視システムを構築できます．

### アラート連携
収集されたメトリクスを基に CloudWatch Alarms を設定し，SNS 等との連携が可能です．

## 実装順序

1. EventBridge 用 IAM ロール・ポリシーの作成
2. SSM Parameter Store への設定保存
3. SSM Automation Document の作成
4. EventBridge Rule とターゲットの設定
5. テスト用 EC2 インスタンスでの動作確認
6. 本番環境への適用

この設計により，EC2 インスタンスの起動と同時に完全自動でメトリクス収集が開始され，運用負荷を大幅に削減できます．
