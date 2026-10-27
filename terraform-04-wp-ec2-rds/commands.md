# Commands Log — terraform-04-wp-ec2-rds (Week 12 Lab)

## Preflight

```bash
test -n "$AWS_ACCESS_KEY_ID"         && echo "AWS_ACCESS_KEY_ID is set"
test -n "$AWS_SECRET_ACCESS_KEY"     && echo "AWS_SECRET_ACCESS_KEY is set"
test -n "$AWS_SESSION_TOKEN"         && echo "AWS_SESSION_TOKEN is set"
test -n "$TF_VAR_db_master_password" && echo "TF_VAR_db_master_password is set"
aws sts get-caller-identity
aws configure get region
terraform version
```

Key output:
```
AWS_ACCESS_KEY_ID is set
AWS_SECRET_ACCESS_KEY is set
AWS_SESSION_TOKEN is set
TF_VAR_db_master_password is set
{
    "UserId": "AROA6IXGDBDW3VDSMGKJG:user4886845=_________",
    "Account": "980808829165",
    "Arn": "arn:aws:sts::980808829165:assumed-role/voclabs/user4886845=_________"
}
us-east-1
Terraform v1.7.5
```

Interpretation: AWS Academy 자격증명과 RDS 비밀번호가 모두 정상 설정되었다.

---

## Init and Format

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt
terraform validate
```

Key output:
```
Terraform has been successfully initialized!
Success! The configuration is valid.
```

Interpretation: AWS provider v5.100.0이 설치되었고 코드 문법 검사를 통과했다.

---

## Plan

```bash
terraform plan -out plan.out
```

Key output:
```
Plan: 5 to add, 0 to change, 0 to destroy.

+ aws_db_subnet_group.wordpress   (ccaws-tf04-db-subnet-group)
+ aws_security_group.wordpress    (ccaws-tf04-wp-sg)
+ aws_security_group.rds          (ccaws-tf04-rds-sg)
+ aws_db_instance.wordpress       (ccaws-tf04-rds, mysql 8.0, db.t3.micro)
+ aws_instance.wordpress          (ccaws-tf04-wordpress, t3.micro)

Changes to Outputs:
+ db_check_url        = (known after apply)
+ db_name             = "wordpress"
+ health_check_url    = (known after apply)
+ instance_id         = (known after apply)
+ rds_endpoint        = (known after apply)
+ rds_instance_id     = "ccaws-tf04-rds"
+ security_group_ids  = (known after apply)
+ selected_subnet_ids = [6개 서브넷]
+ wordpress_url       = (known after apply)
```

Interpretation: EC2 1개, RDS MySQL 1개, SG 2개, DB Subnet Group 1개 총 5개 리소스가 생성될 예정이다.

---

## Apply

```bash
terraform apply plan.out
```

Key output:
```
aws_db_subnet_group.wordpress: Creation complete after 2s
aws_security_group.wordpress: Creation complete after 4s
aws_security_group.rds: Creation complete after 3s
aws_db_instance.wordpress: Still creating... [4m57s elapsed]
aws_db_instance.wordpress: Creation complete after 4m57s [id=db-N7Z4ZDKC4EO7KF7VYF6FEV2I7M]
aws_instance.wordpress: Creation complete after 13s [id=i-09f7337d3e22d247e]
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:
db_check_url        = "http://18.205.192.69/db-health.php"
db_name             = "wordpress"
health_check_url    = "http://18.205.192.69/health.html"
instance_id         = "i-09f7337d3e22d247e"
rds_endpoint        = "ccaws-tf04-rds.cdc6m8c42ir8.us-east-1.rds.amazonaws.com:3306"
rds_instance_id     = "ccaws-tf04-rds"
security_group_ids  = {
  "rds"           = "sg-0de1226564e8f422a"
  "wordpress_ec2" = "sg-0e73397a7413dff81"
}
selected_subnet_ids = [
  "subnet-063f9ccf5facc7d21",
  "subnet-0907c242196e43f14",
  "subnet-090b0320b9f8cd3d8",
  "subnet-0b325a3a157bfff42",
  "subnet-0ce5188ddee11adfe",
  "subnet-0eb7510f45442d602",
]
wordpress_url = "http://18.205.192.69"
```

Interpretation: RDS 생성에 약 5분 소요됐으며 모든 리소스가 정상 생성되었다.

---

## Terraform & Infrastructure Evidence

| 항목 | 값 |
|------|-----|
| EC2 Instance ID | i-09f7337d3e22d247e |
| RDS Endpoint | ccaws-tf04-rds.cdc6m8c42ir8.us-east-1.rds.amazonaws.com:3306 |
| RDS Instance ID | ccaws-tf04-rds |
| RDS PubliclyAccessible | false |
| DB Name | wordpress |
| Selected Subnet IDs | subnet-063f9ccf5facc7d21, subnet-0907c242196e43f14, subnet-090b0320b9f8cd3d8, subnet-0b325a3a157bfff42, subnet-0ce5188ddee11adfe, subnet-0eb7510f45442d602 |
| EC2 Security Group ID | sg-0e73397a7413dff81 |
| RDS Security Group ID | sg-0de1226564e8f422a |

---

## Verify EC2 and RDS

```bash
# 1. EC2 부트스트랩 확인
curl "$(terraform output -raw health_check_url)"

# 2. PHP → RDS 연결 확인
curl "$(terraform output -raw db_check_url)"

# 3. RDS PubliclyAccessible 확인
aws rds describe-db-instances \
  --db-instance-identifier "$(terraform output -raw rds_instance_id)" \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Public:PubliclyAccessible,Engine:Engine}'

# 4. RDS SG 인그레스 규칙 확인
aws ec2 describe-security-groups \
  --group-ids "$(terraform output -json security_group_ids | python3 -c "import sys,json; print(json.load(sys.stdin)['rds'])")" \
  --query 'SecurityGroups[0].IpPermissions'

# 5. EC2 IAM 인스턴스 프로파일 확인
aws ec2 describe-instances \
  --instance-ids "$(terraform output -raw instance_id)" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'
```

Key output:
```
# 1. health_check_url
<!DOCTYPE html>
<html><body>
<h1>EC2 Bootstrap OK</h1>
<p>Apache is running and user_data completed successfully.</p>
</body></html>

# 2. db_check_url
{"status":"ok","db_host":"ccaws-tf04-rds.cdc6m8c42ir8.us-east-1.rds.amazonaws.com","db_name":"wordpress","db_ok":1,"message":"PHP successfully connected to RDS MySQL"}

# 3. RDS 상태
{
    "Status": "available",
    "Endpoint": "ccaws-tf04-rds.cdc6m8c42ir8.us-east-1.rds.amazonaws.com",
    "Public": false,
    "Engine": "mysql"
}

# 4. RDS SG 인그레스
[
    {
        "FromPort": 3306,
        "IpProtocol": "tcp",
        "IpRanges": [],
        "UserIdGroupPairs": [
            {
                "Description": "Allow MySQL from the WordPress EC2 SG only - no public access",
                "GroupId": "sg-0e73397a7413dff81",
                "UserId": "980808829165"
            }
        ]
    }
]

# 5. EC2 IAM Profile
null
```

### Connectivity & Evidence Summary

| 항목 | 결과 | 상태 |
|------|------|------|
| health_check_url HTTP 응답 | EC2 Bootstrap OK | ✅ |
| db_check_url PHP-to-RDS 결과 | {"status":"ok","db_ok":1} | ✅ |
| RDS PubliclyAccessible | false | ✅ |
| RDS SG ingress source | EC2 SG만 허용 (IpRanges 비어있음) | ✅ |
| EC2 IAM Instance Profile | null (비어있음) | ✅ |

---

## WordPress Browser Setup

```bash
terraform output -raw wordpress_url
# http://18.205.192.69
```

브라우저에서 `http://18.205.192.69` 접속 후 WordPress 설치 마법사 완료.
WordPress 블로그 메인 페이지 및 예제 페이지 정상 접속 확인.

---

## Cleanup

```bash
terraform destroy
```

Key output:
```
aws_instance.wordpress: Destruction complete after 20s
aws_db_instance.wordpress: Still destroying... [1m52s elapsed]
aws_db_instance.wordpress: Destruction complete after 1m52s
aws_db_subnet_group.wordpress: Destruction complete after 0s
aws_security_group.rds: Destruction complete after 1s
aws_security_group.wordpress: Destruction complete after 1s
Destroy complete! Resources: 5 destroyed.
```

Interpretation: 모든 리소스가 정상 삭제되었다. RDS 삭제에 약 2분 소요됐다.

---

## Credential Handling Note

```text
AWS Academy 임시 자격증명은 환경변수로만 전달했다.
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN,
TF_VAR_db_master_password 는 terraform.tfvars 또는 커밋된 파일에 절대 포함하지 않았다.
terraform.tfvars, terraform.tfstate, .pem 파일은 .gitignore로 커밋에서 제외했다.
```
