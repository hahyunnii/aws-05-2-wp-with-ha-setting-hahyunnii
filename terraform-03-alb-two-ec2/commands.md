# Commands Log — terraform-03-alb-two-ec2

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

## Init, Plan, and Apply

```bash
# tfvars 파일을 예시 파일로부터 복사합니다.
cp terraform.tfvars.example terraform.tfvars

# 작업 디렉토리를 초기화하고 AWS provider를 설치합니다.
terraform init

# validation과 planning 전에 형식을 정규화합니다.
terraform fmt

# 문법과 provider/resource 참조를 검사합니다.
terraform validate

# 검토된 실행 계획을 파일에 저장합니다.
terraform plan -out plan.out

# 검토한 plan을 그대로 적용합니다.
terraform apply plan.out
```

Key output:
```
Terraform has been successfully initialized!
Success! The configuration is valid.

Plan: 9 to add, 0 to change, 0 to destroy.

aws_security_group.alb: Creation complete after 3s [id=sg-0df23627f15e75ba2]
aws_lb_target_group.web: Creation complete after 1s
aws_security_group.ec2: Creation complete after 3s [id=sg-0ec973bbaca922192]
aws_instance.web["web-a"]: Creation complete after 14s [id=i-0f0d80742feda6be7]
aws_instance.web["web-b"]: Creation complete after 13s [id=i-0459cb191cacb21f6]
aws_lb_target_group_attachment.web["web-a"]: Creation complete after 0s
aws_lb_target_group_attachment.web["web-b"]: Creation complete after 0s
aws_lb.web: Creation complete after 2m53s
aws_lb_listener.http: Creation complete after 0s
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
```

Interpretation: EC2 2개, ALB, Target Group, Listener, SG 2개 총 9개 리소스가 정상 생성됐다.

---

## Outputs and Service Test

```bash
# ALB DNS 이름과 instance ID를 포함한 모든 output을 출력합니다.
terraform output

# 셸 재사용을 위해 ALB DNS 값만 따옴표 없이 출력합니다.
terraform output -raw alb_dns_name

# 로드밸런서를 통해 반복 요청을 보내 두 대상이 응답하는지 확인합니다.
ALB_DNS=$(terraform output -raw alb_dns_name)
for i in $(seq 1 10); do curl -s "http://${ALB_DNS}"; echo; done
```

Key output:
```
alb_dns_name   = "ccaws-tf03-alb-662789696.us-east-1.elb.amazonaws.com"
alb_name       = "ccaws-tf03-alb"
target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:980808829165:targetgroup/ccaws-tf03-tg/d92548037be4b161"
instance_ids = {
  "web-a" = "i-0f0d80742feda6be7"
  "web-b" = "i-0459cb191cacb21f6"
}
instance_public_ips = {
  "web-a" = "100.31.202.154"
  "web-b" = "100.54.239.103"
}
selected_availability_zones = ["us-east-1a", "us-east-1b"]
selected_subnet_ids = ["subnet-0b325a3a157bfff42", "subnet-0907c242196e43f14"]

ccaws-tf03-alb-662789696.us-east-1.elb.amazonaws.com

# 10회 반복 요청 결과 (Round Robin 확인)
<p>Server Name: web-a</p>
<p>Server Name: web-b</p>
<p>Server Name: web-a</p>
<p>Server Name: web-b</p>
<p>Server Name: web-a</p>
<p>Server Name: web-b</p>
<p>Server Name: web-a</p>
<p>Server Name: web-b</p>
<p>Server Name: web-b</p>
<p>Server Name: web-a</p>
```

Interpretation: ALB가 web-a와 web-b에 트래픽을 번갈아 분산하는 Round Robin 로드밸런싱이 동작했다.

---

## State Inspection

```bash
# Terraform state에서 ALB 리소스 하나를 상세하게 조회합니다.
terraform state show aws_lb.web

# Terraform state에 저장된 Target Group 설정을 조회합니다.
terraform state show aws_lb_target_group.web
```

Key output:
```
# terraform state show aws_lb.web
resource "aws_lb" "web" {
    arn                        = "arn:aws:elasticloadbalancing:us-east-1:980808829165:loadbalancer/app/ccaws-tf03-alb/1dbd623d03a83c4a"
    dns_name                   = "ccaws-tf03-alb-662789696.us-east-1.elb.amazonaws.com"
    internal                   = false
    load_balancer_type         = "application"
    name                       = "ccaws-tf03-alb"
    security_groups            = ["sg-0df23627f15e75ba2"]
    subnets                    = ["subnet-0907c242196e43f14", "subnet-0b325a3a157bfff42"]
}

# terraform state show aws_lb_target_group.web
resource "aws_lb_target_group" "web" {
    name        = "ccaws-tf03-tg"
    port        = 8080
    protocol    = "HTTP"
    target_type = "instance"
    vpc_id      = "vpc-099a13dbc423e5700"
    health_check {
        enabled             = true
        healthy_threshold   = 2
        interval            = 15
        path                = "/"
        port                = "traffic-port"
    }
}
```

Interpretation: ALB가 두 서브넷에 걸쳐 배포되었고 Target Group이 포트 8080으로 헬스체크를 수행하는 것을 확인했다.

---

## AWS Verification

```bash
# Terraform이 반환한 이름을 사용하여 AWS API에서 로드밸런서를 확인합니다.
aws elbv2 describe-load-balancers \
  --names "$(terraform output -raw alb_name)"

# Terraform이 반환한 Target Group ARN으로 AWS API에서 타겟 상태를 확인합니다.
aws elbv2 describe-target-health \
  --target-group-arn "$(terraform output -raw target_group_arn)"
```

Key output:
```
# describe-load-balancers
{
    "LoadBalancers": [{
        "LoadBalancerName": "ccaws-tf03-alb",
        "DNSName": "ccaws-tf03-alb-662789696.us-east-1.elb.amazonaws.com",
        "State": {"Code": "active"},
        "Type": "application",
        "Scheme": "internet-facing"
    }]
}

# describe-target-health
{
    "TargetHealthDescriptions": [
        {
            "Target": {"Id": "i-0f0d80742feda6be7", "Port": 8080},
            "TargetHealth": {"State": "healthy"}
        },
        {
            "Target": {"Id": "i-0459cb191cacb21f6", "Port": 8080},
            "TargetHealth": {"State": "healthy"}
        }
    ]
}
```

Interpretation: ALB가 active 상태이고 web-a, web-b 두 EC2 타겟이 모두 healthy 상태임을 확인했다.

---

## Cleanup

```bash
# ALB, EC2 인스턴스, 지원 리소스를 삭제합니다.
terraform destroy
```

Key output:
```
aws_lb_listener.http: Destruction complete after 0s
aws_lb.web: Destruction complete after 17s
aws_instance.web["web-a"]: Destruction complete after 31s
aws_instance.web["web-b"]: Destruction complete after 31s
aws_security_group.ec2: Destruction complete after 1s
aws_security_group.alb: Destruction complete after 0s
Destroy complete! Resources: 9 destroyed.
```

Interpretation: 9개 리소스가 모두 정상 삭제되었다.

---

## Credential Handling Note

```text
AWS Academy 임시 자격증명은 환경변수로만 저장했다.
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN은
terraform.tfvars에 절대 포함하지 않았다.
```
