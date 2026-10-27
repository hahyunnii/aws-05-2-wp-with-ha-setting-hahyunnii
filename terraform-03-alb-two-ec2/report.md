# Report — terraform-03-alb-two-ec2

## 1. 실습 개요

두 EC2 인스턴스 앞에 Application Load Balancer(ALB)를 배치하여
트래픽을 분산하는 High Availability 구성을 Terraform으로 구현했다.
ALB와 EC2 간의 보안 경계 설계와 로드밸런싱 동작 확인이 목표다.

---

## 2. 아키텍처

```
Browser
   │
   │ HTTP/80
   ▼
ALB (ccaws-tf03-alb)              ← ALB SG: HTTP/80 from 0.0.0.0/0
   │
   ├── HTTP/8080 ──▶ EC2 web-a   ← EC2 SG: 8080 from ALB SG only
   └── HTTP/8080 ──▶ EC2 web-b   ← EC2 SG: 8080 from ALB SG only
      (us-east-1a)   (us-east-1b)
```

---

## 3. 생성된 리소스

| 리소스 | 이름 | 설명 |
|--------|------|------|
| aws_lb | ccaws-tf03-alb | Application Load Balancer |
| aws_lb_target_group | ccaws-tf03-tg | EC2 대상 그룹 (포트 8080) |
| aws_lb_listener | - | ALB 포트 80 → EC2 포트 8080 포워딩 |
| aws_lb_target_group_attachment x2 | - | EC2 2개를 Target Group에 등록 |
| aws_instance | ccaws-tf03-web-a | Nginx 웹서버 (us-east-1a) |
| aws_instance | ccaws-tf03-web-b | Nginx 웹서버 (us-east-1b) |
| aws_security_group | ccaws-tf03-alb-sg | ALB SG: HTTP/80 전체 허용 |
| aws_security_group | ccaws-tf03-ec2-sg | EC2 SG: ALB SG에서만 8080 허용 |

---

## 4. 보안 설계

EC2 Security Group은 ALB Security Group ID에서 오는 포트 8080 트래픽만 허용한다.
EC2의 Public IP로 직접 접근해도 포트가 막혀 있어 반드시 ALB DNS를 통해서만
접근 가능하다. 이것이 ALB와 EC2 간의 보안 경계(Security Boundary)다.

```hcl
# EC2 SG — ALB SG에서만 8080 허용
ingress {
  from_port       = var.app_port          # 8080
  to_port         = var.app_port          # 8080
  protocol        = "tcp"
  security_groups = [aws_security_group.alb.id]  # ALB SG ID만 허용
}
```

---

## 5. 로드밸런싱 검증

ALB DNS로 10회 반복 요청 결과:
- web-a 응답: 5회
- web-b 응답: 5회
- 알고리즘: Round Robin (기본값)

ALB가 두 EC2에 트래픽을 균등하게 분산함을 확인했다.
한 EC2가 장애가 나면 ALB Health Check가 감지하여 나머지 EC2에만 트래픽을 보낸다.

---

## 6. 검증 결과

| 항목 | 결과 |
|------|------|
| terraform validate | ✅ Success! The configuration is valid. |
| terraform apply | ✅ Resources: 9 added |
| ALB HTTP 응답 | ✅ web-a / web-b 번갈아 응답 확인 |
| Round Robin 동작 | ✅ 10회 중 web-a 5회, web-b 5회 |
| EC2 직접 접근 차단 | ✅ EC2 SG가 ALB SG에서만 허용 |
| terraform destroy | ✅ Resources: 9 destroyed |

---

## 7. 결론

ALB를 통해 단일 DNS로 여러 EC2에 트래픽을 분산하는 High Availability 패턴을
구현했다. EC2가 직접 노출되지 않고 ALB SG를 통해서만 접근 가능한 보안 설계도
확인했다. 다음 실습에서는 데이터베이스를 EC2에서 분리하여 RDS로 이전한다.
