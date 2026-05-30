# Commands Log — terraform-02-ec2-two-subnets

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
```

Interpretation: AWS Academy 자격증명이 정상 설정되었다.

---

## Init and Validation

```bash
# tfvars 파일을 예시 파일로부터 복사합니다.
cp terraform.tfvars.example terraform.tfvars

# 작업 디렉토리를 초기화하고 AWS provider를 다운로드합니다.
terraform init

# Terraform 파일 형식을 일관되게 정리합니다.
terraform fmt

# plan 전에 설정 문법을 검사합니다.
terraform validate
```

Key output:
```
Terraform has been successfully initialized!
Success! The configuration is valid.
```

Interpretation: 코드 문법 검사를 통과했다.

---

## Saved Plan

```bash
# 나중에 동일한 계획을 적용할 수 있도록 실행 계획을 파일에 저장합니다.
terraform plan -out plan.out

# 저장된 plan 파일을 사람이 읽을 수 있는 형태로 출력합니다.
terraform show plan.out
```

Key output:
```
Plan: 3 to add, 0 to change, 0 to destroy.

+ aws_security_group.web          (ccaws-tf02-web-sg)
+ aws_instance.web["web-a"]       subnet: subnet-0b325a3a157bfff42 (us-east-1a)
+ aws_instance.web["web-b"]       subnet: subnet-0907c242196e43f14 (us-east-1b)

Changes to Outputs:
+ selected_availability_zones = ["us-east-1a", "us-east-1b"]
+ selected_subnet_ids = ["subnet-0b325a3a157bfff42", "subnet-0907c242196e43f14"]

# terraform show plan.out 출력 (주요 부분)
resource "aws_instance" "web" "web-a" {
  ami           = (sensitive value)
  instance_type = "t3.micro"
  subnet_id     = "subnet-0b325a3a157bfff42"
}
resource "aws_instance" "web" "web-b" {
  ami           = (sensitive value)
  instance_type = "t3.micro"
  subnet_id     = "subnet-0907c242196e43f14"
}
```

Interpretation: EC2 2개가 서로 다른 AZ(us-east-1a, us-east-1b)에 배치될 예정이다.

---

## Apply and Outputs

```bash
# 검토한 저장된 plan을 그대로 적용합니다.
terraform apply plan.out

# selected_subnet_ids와 instance IP를 포함한 모든 output을 읽습니다.
terraform output
```

Key output:
```
aws_security_group.web: Creation complete after 3s [id=sg-0bed226c653b92d55]
aws_instance.web["web-a"]: Creation complete after 14s [id=i-030b05f531d9eb2f3]
aws_instance.web["web-b"]: Creation complete after 14s [id=i-020badb562efef813]
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

instance_ids = {
  "web-a" = "i-030b05f531d9eb2f3"
  "web-b" = "i-020badb562efef813"
}
instance_public_ips = {
  "web-a" = "44.200.239.63"
  "web-b" = "35.170.185.168"
}
selected_availability_zones = tolist(["us-east-1a", "us-east-1b"])
selected_subnet_ids = ["subnet-0b325a3a157bfff42", "subnet-0907c242196e43f14"]
```

Interpretation: EC2 2개가 서로 다른 AZ에 정상 생성되었다.

---

## State Inspection

```bash
# Terraform이 현재 state 파일에서 추적하는 모든 객체를 나열합니다.
terraform state list

# 애드혹 검사를 위해 Terraform expression 콘솔을 엽니다.
terraform console
```

Useful console expressions:
```text
local.instance_subnet_map
keys(aws_instance.web)
values(aws_instance.web)[*].public_ip
```

Key output:
```
# terraform state list
data.aws_ssm_parameter.al2023_ami
data.aws_subnet.default_vpc["subnet-0907c242196e43f14"]
data.aws_subnet.default_vpc["subnet-0b325a3a157bfff42"]
...
data.aws_subnets.default_vpc
data.aws_vpc.default
aws_instance.web["web-a"]
aws_instance.web["web-b"]
aws_security_group.web

# terraform console
> local.instance_subnet_map
{
  "web-a" = "subnet-0b325a3a157bfff42"
  "web-b" = "subnet-0907c242196e43f14"
}
> keys(aws_instance.web)
toset(["web-a", "web-b"])
> values(aws_instance.web)[*].public_ip
["44.200.239.63", "35.170.185.168"]
```

Interpretation: Terraform state에서 for_each로 생성된 리소스가 web-a, web-b 키로 관리되는 것을 확인했다.

---

## HTTP Verify

```bash
# web-a 서버 응답 확인
curl "http://44.200.239.63"

# web-b 서버 응답 확인
curl "http://35.170.185.168"
```

Key output:
```
# web-a
<h1>Terraform Example 02</h1>
<p>Server Name: web-a</p>

# web-b
<h1>Terraform Example 02</h1>
<p>Server Name: web-b</p>
```

Interpretation: 두 서버가 각각 다른 Server Name으로 응답하여 서로 다른 인스턴스임을 확인했다.

---

## Cleanup

```bash
# 검증 완료 후 이 예제의 모든 리소스를 삭제합니다.
terraform destroy
```

Key output:
```
aws_instance.web["web-a"]: Destruction complete after 20s
aws_instance.web["web-b"]: Destruction complete after 31s
aws_security_group.web: Destruction complete after 1s
Destroy complete! Resources: 3 destroyed.
```

Interpretation: EC2 2개와 SG 1개가 정상 삭제되었다.

---

## Credential Handling Note

```text
AWS Academy 임시 자격증명은 환경변수로만 저장했다.
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN은
terraform.tfvars에 절대 포함하지 않았다.
```
