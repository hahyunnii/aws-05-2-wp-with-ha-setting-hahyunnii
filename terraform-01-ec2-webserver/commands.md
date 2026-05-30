# Commands Log — terraform-01-ec2-webserver

## Preflight

```bash
# AWS Academy 임시 자격증명이 환경변수로 설정되어 있는지 확인합니다.
test -n "$AWS_ACCESS_KEY_ID"     && echo "AWS_ACCESS_KEY_ID is set"
test -n "$AWS_SECRET_ACCESS_KEY" && echo "AWS_SECRET_ACCESS_KEY is set"
test -n "$AWS_SESSION_TOKEN"     && echo "AWS_SESSION_TOKEN is set"

# AWS 자격증명이 현재 셸에서 활성화되어 있는지 확인합니다.
aws sts get-caller-identity

# Terraform이 사용할 기본 AWS 리전을 확인합니다.
aws configure get region

# Terraform이 설치되어 있는지 확인합니다.
terraform version
```

Key output:
```
AWS_ACCESS_KEY_ID is set
AWS_SECRET_ACCESS_KEY is set
AWS_SESSION_TOKEN is set
{
    "UserId": "AROA6IXGDBDW3VDSMGKJG:user4886845=_________",
    "Account": "980808829165",
    "Arn": "arn:aws:sts::980808829165:assumed-role/voclabs/user4886845=_________"
}
us-east-1
Terraform v1.7.5
```

Interpretation: AWS Academy 자격증명이 정상 설정되었고 us-east-1 리전에서 Terraform이 동작한다.

---

## Init and Format

```bash
# tfvars 파일을 예시 파일로부터 복사합니다.
cp terraform.tfvars.example terraform.tfvars

# AWS provider 플러그인을 .terraform 디렉토리에 다운로드합니다.
terraform init

# Terraform 파일을 정규 형식으로 재작성합니다.
terraform fmt
```

Key output:
```
Terraform has been successfully initialized!

main.tf
```

Interpretation: AWS provider v5.100.0이 설치되었고 main.tf 파일이 fmt로 정리되었다.

---

## Validate and Plan

```bash
# Terraform 문법과 provider/resource 참조를 검사합니다.
terraform validate

# 변경 전에 Terraform이 생성할 내용을 미리 확인합니다.
# -out plan.out 으로 계획을 파일에 저장합니다.
terraform plan -out plan.out
```

Key output:
```
Success! The configuration is valid.

Plan: 2 to add, 0 to change, 0 to destroy.

+ aws_security_group.web  (ccaws-tf01-web-sg)
  ingress: HTTP/80 from 0.0.0.0/0

+ aws_instance.web        (ccaws-tf01-web)
  instance_type: t3.micro
  subnet_id: subnet-063f9ccf5facc7d21

Changes to Outputs:
+ instance_id        = (known after apply)
+ instance_public_ip = (known after apply)
+ selected_subnet_id = "subnet-063f9ccf5facc7d21"
```

Interpretation: EC2 1개, SG 1개 총 2개 리소스가 생성될 예정이다.

---

## Apply and Verify

```bash
# EC2 인스턴스와 지원 리소스를 생성합니다.
terraform apply plan.out

# apply 완료 후 정의된 모든 output을 읽습니다.
terraform output

# 셸 명령에서 사용할 수 있도록 Public IP만 raw 형태로 출력합니다.
terraform output -raw instance_public_ip

# 인스턴스에 직접 HTTP 요청을 보냅니다.
curl "http://$(terraform output -raw instance_public_ip)"
```

Key output:
```
aws_security_group.web: Creation complete after 4s [id=sg-03fac643eec22d5dd]
aws_instance.web: Creation complete after 13s [id=i-0c2f1f55d9eb8afb2]
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

instance_id         = "i-0c2f1f55d9eb8afb2"
instance_public_ip  = "3.234.211.147"
instance_public_dns = "ec2-3-234-211-147.compute-1.amazonaws.com"
security_group_id   = "sg-03fac643eec22d5dd"
selected_subnet_id  = "subnet-063f9ccf5facc7d21"

3.234.211.147

<h1>Terraform Example 01</h1>
<p>Role: Single EC2 web server</p>
<p>Name Prefix: ccaws-tf01</p>
<p>Instance ID: </p>
<p>Availability Zone: </p>
```

Interpretation: EC2와 SG가 정상 생성되었고 Nginx 웹페이지가 HTTP로 응답했다.

---

## Cleanup

```bash
# 이 예제로 생성된 모든 리소스를 삭제합니다.
terraform destroy
```

Key output:
```
aws_instance.web: Destruction complete after 31s
aws_security_group.web: Destruction complete after 1s
Destroy complete! Resources: 2 destroyed.
```

Interpretation: EC2와 SG가 정상 삭제되었다.

---

## Credential Handling Note

```text
AWS Academy 임시 자격증명은 환경변수로만 저장했다.
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN은
terraform.tfvars에 절대 포함하지 않았다.
```
