# Report — terraform-01-ec2-webserver

## 1. 실습 개요

단일 EC2 인스턴스에 Nginx 웹서버를 설치하고 HTTP로 접근하는 가장 기본적인
AWS 인프라를 Terraform으로 구성했다. Terraform의 기본 워크플로우인
init → fmt → validate → plan → apply → destroy 를 익히는 것이 목표다.

---

## 2. 아키텍처

```
Browser
   │
   │ HTTP/80
   ▼
EC2 (Nginx)  ← Public Subnet, Public IP
   └── Security Group: HTTP/80 from 0.0.0.0/0
```

---

## 3. 생성된 리소스

| 리소스 | 이름 | 설명 |
|--------|------|------|
| aws_instance | ccaws-tf01-web | Nginx 웹서버 (t3.micro, Amazon Linux 2023) |
| aws_security_group | ccaws-tf01-web-sg | HTTP/80 인바운드 전체 허용 |

---

## 4. 주요 학습 내용

- `data` 소스로 기존 AWS 인프라(default VPC, Subnet, AMI) 조회 방법
- SSM Parameter Store에서 최신 Amazon Linux 2023 AMI ID를 동적으로 읽는 방법
- `templatefile()`로 user_data 스크립트에 변수를 주입하는 방법
- Security Group ingress/egress 규칙 설정 방법
- `terraform output`으로 생성된 리소스 정보를 확인하는 방법

---

## 5. 검증 결과

| 항목 | 결과 |
|------|------|
| terraform validate | ✅ Success! The configuration is valid. |
| terraform apply | ✅ Resources: 2 added |
| Nginx HTTP 응답 | ✅ curl로 HTML 페이지 응답 확인 |
| terraform destroy | ✅ Resources: 2 destroyed |

---

## 6. 결론

Terraform의 기본 워크플로우(init → plan → apply → destroy)를 익혔다.
단일 EC2로는 장애 발생 시 서비스가 중단되는 단일 장애점(Single Point of Failure)
문제가 있어 다음 실습에서 멀티 서브넷 구성으로 확장한다.
