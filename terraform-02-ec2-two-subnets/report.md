# Report — terraform-02-ec2-two-subnets

## 1. 실습 개요

두 개의 EC2 인스턴스를 서로 다른 Availability Zone의 서브넷에 배치하는
멀티 서브넷 구성을 Terraform의 `for_each`를 사용해 구현했다.
코드 중복 없이 여러 리소스를 생성하는 Terraform 반복 패턴을 익히는 것이 목표다.

---

## 2. 아키텍처

```
Browser          Browser
   │                │
   │ HTTP/80        │ HTTP/80
   ▼                ▼
EC2 web-a        EC2 web-b
(us-east-1a)    (us-east-1b)
subnet-0b325a   subnet-0907c2
```

---

## 3. 생성된 리소스

| 리소스 | 이름 | AZ | Subnet |
|--------|------|----|--------|
| aws_instance | ccaws-tf02-web-a | us-east-1a | subnet-0b325a3a157bfff42 |
| aws_instance | ccaws-tf02-web-b | us-east-1b | subnet-0907c242196e43f14 |
| aws_security_group | ccaws-tf02-web-sg | - | - |

---

## 4. 주요 학습 내용

- `for_each`로 여러 EC2 인스턴스를 코드 중복 없이 생성하는 방법
- `subnets_by_az`로 AZ별 서브넷을 그룹화하는 방법
- `slice(sort(keys(...)), 0, 2)`로 첫 두 AZ를 선택하는 방법
- `zipmap()`으로 인스턴스 이름(web-a, web-b)과 서브넷 ID를 매핑하는 방법
- `each.key`, `each.value`로 for_each 내에서 키/값을 사용하는 방법

---

## 5. 서브넷 선택 로직

```hcl
subnets_by_az = {
  for _, subnet in data.aws_subnet.default_vpc :
  subnet.availability_zone => subnet.id...
}
# 결과: {"us-east-1a": ["subnet-xxx"], "us-east-1b": ["subnet-yyy"], ...}

selected_azs = slice(sort(keys(local.subnets_by_az)), 0, 2)
# 결과: ["us-east-1a", "us-east-1b"]

instance_subnet_map = zipmap(["web-a", "web-b"], local.selected_subnet_ids)
# 결과: {"web-a": "subnet-xxx", "web-b": "subnet-yyy"}
```

---

## 6. 검증 결과

| 항목 | 결과 |
|------|------|
| terraform validate | ✅ Success! The configuration is valid. |
| terraform apply | ✅ Resources: 3 added |
| web-a HTTP 응답 | ✅ Server Name: web-a 확인 |
| web-b HTTP 응답 | ✅ Server Name: web-b 확인 |
| 서로 다른 AZ 배치 | ✅ us-east-1a / us-east-1b 확인 |
| terraform destroy | ✅ Resources: 3 destroyed |

---

## 7. 결론

`for_each`를 활용해 코드 중복 없이 여러 리소스를 생성하는 방법을 익혔다.
두 EC2가 서로 다른 AZ에 배치되었지만 클라이언트가 두 IP를 직접 알아야 하는
문제가 있다. 다음 실습에서 ALB를 추가하여 단일 DNS로 트래픽을 분산한다.
