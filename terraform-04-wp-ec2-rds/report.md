# Report — terraform-04-wp-ec2-rds (Week 12 Lab)

## 1. 실습 개요

이번 실습의 목표는 기존 Week 09에서 단일 EC2에 모두 올렸던 WordPress 스택을
두 계층(Two-Tier)으로 분리하는 것이다. EC2에는 Apache, PHP, WordPress 파일만 남기고
데이터베이스는 AWS RDS MySQL로 이전하여 웹 계층과 데이터 계층을 분리하는
클라우드 아키텍처 패턴을 Terraform으로 구현했다.

---

## 2. 아키텍처

```
Browser
   │
   │ HTTP/80
   ▼
EC2 (Apache + PHP + WordPress)        ← Public Subnet
   │  Security Group: HTTP/80, SSH/22 from 0.0.0.0/0
   │
   │ TCP/3306 (VPC 내부 전용)
   ▼
RDS MySQL 8.0                         ← publicly_accessible = false
   Security Group: TCP/3306 from EC2 SG only
```

---

## 3. 생성된 리소스

| 리소스 | 이름 | 설명 |
|--------|------|------|
| aws_instance | ccaws-tf04-wordpress | WordPress 웹서버 (t3.micro, Amazon Linux 2023) |
| aws_db_instance | ccaws-tf04-rds | MySQL 8.0 (db.t3.micro, 20GiB gp2) |
| aws_security_group | ccaws-tf04-wp-sg | EC2 SG: HTTP/80, SSH/22 허용 |
| aws_security_group | ccaws-tf04-rds-sg | RDS SG: EC2 SG에서만 TCP/3306 허용 |
| aws_db_subnet_group | ccaws-tf04-db-subnet-group | RDS 서브넷 그룹 (6개 서브넷) |

---

## 4. RDS로 이동한 것 vs EC2에 남은 것

### RDS로 이동한 것
- WordPress 데이터베이스 전체
  (wp_posts, wp_users, wp_options, wp_comments 등 모든 테이블)
- MySQL 엔진 자체 (패치, 백업, 장애복구를 AWS가 자동 관리)

### EC2에 남은 것
- Apache 웹서버
- PHP 런타임
- WordPress 애플리케이션 파일 (`/var/www/html/`)
- wp-config.php (DB 연결 정보 포함)
- 미디어 업로드 파일

### 의미
EC2 인스턴스를 종료하고 새로 만들어도 RDS에 저장된 WordPress 데이터는 유지된다.
이것이 Stateless Compute(상태 없는 컴퓨팅)의 첫 단계다.
다만 WordPress 파일과 미디어 업로드는 아직 EC2에 있으므로
완전한 수평 확장을 위해서는 EFS 등 공유 스토리지가 추가로 필요하다.

---

## 5. 보안 경계 분석

### Layer 1 — No Public Route
`publicly_accessible = false` 설정으로 RDS 엔드포인트는 VPC 내부에서만
DNS 해석이 된다. 외부에서는 엔드포인트 주소를 알아도 접근할 수 없다.

### Layer 2 — Security Group Whitelist
RDS Security Group은 TCP/3306 포트를 EC2 Security Group ID에서만 허용한다.
`IpRanges`가 비어있어 0.0.0.0/0에서의 접근은 완전히 차단된다.

```
RDS SG ingress:
  Port: 3306
  Source: sg-0e73397a7413dff81 (EC2 SG) ← EC2에서만 허용
  IpRanges: [] ← 0.0.0.0/0 없음
```

### Layer 3 — MySQL Credentials
포트 3306에 도달하더라도 올바른 MySQL 사용자명과 비밀번호가 없으면 접속 거부된다.
IAM 데이터베이스 인증은 사용하지 않으며 EC2 IAM Instance Profile은 비어있다(null).

---

## 6. Week 09 vs Week 12 비교

| 항목 | Week 09 (Single EC2) | Week 12 (EC2 + RDS) |
|------|----------------------|---------------------|
| 데이터베이스 위치 | EC2 내부 (MariaDB) | 별도 RDS MySQL |
| DB_HOST | localhost | RDS 엔드포인트 |
| EC2 종료 시 데이터 | 영구 손실 | RDS에 보존 |
| 수평 확장 | 불가 (split-brain) | 가능 (RDS 공유) |
| DB 패치/백업 | 직접 관리 | AWS 자동 관리 |
| 포트 3306 공개 | EC2 내부만 | 완전 차단 |

---

## 7. user_data 부트스트랩 동작 과정

1. `dnf update` 및 패키지 설치 (Apache, PHP, MariaDB 클라이언트만 — DB 서버 없음)
2. `/var/www/html/health.html` 생성 (부트스트랩 완료 확인용)
3. RDS가 연결을 받을 때까지 10초 간격으로 최대 60회 대기
4. `/var/www/html/db-health.php` 생성 (PHP → RDS 연결 확인용 JSON 응답)
5. WordPress 다운로드 및 `/var/www/html/`에 설치
6. `wp-config.php`에 `DB_HOST = RDS 엔드포인트` 설정 (localhost 아님)
7. Apache 시작

---

## 8. 트러블슈팅

### 문제 1 — description 특수문자 오류
`aws_security_group` description에 em-dash(`—`) 문자가 포함되어 AWS API가 거부했다.

**오류 메시지:**
```
"ingress.0.description" doesn't comply with restrictions
("^[0-9A-Za-z_ .:/()#,@\\[\\]+=&;{}!$*-]*$")
```

**원인:** AWS Security Group description은 특정 ASCII 문자만 허용한다.

**해결:** `sed -i 's/—/-/g' main.tf` 명령어로 모든 em-dash를 일반 하이픈으로 교체했다.

### 문제 2 — curl 패키지 충돌
Amazon Linux 2023에 이미 `curl`이 설치되어 있는데 user-data.sh에서 `curl`을
다시 설치하려다 `curl-minimal`과 충돌이 발생하여 dnf install이 실패했다.

**오류 메시지:**
```
package curl-minimal conflicts with curl provided by curl-x.x.x
(try to add '--allowerasing' to command line)
```

**원인:** Amazon Linux 2023은 기본적으로 `curl-minimal`이 설치되어 있어
`curl` 풀 패키지와 충돌한다.

**해결:** user-data.sh의 dnf install 목록에서 `curl`을 제거했다.

---

## 9. 검증 결과

| 검증 항목 | 결과 |
|-----------|------|
| EC2 Bootstrap (health.html) | ✅ "EC2 Bootstrap OK" 응답 확인 |
| PHP → RDS 연결 (db-health.php) | ✅ `{"status":"ok","db_ok":1}` 응답 확인 |
| RDS PubliclyAccessible | ✅ false 확인 |
| RDS SG ingress | ✅ EC2 SG에서만 3306 허용, IpRanges 비어있음 |
| EC2 IAM Instance Profile | ✅ null (MySQL 비밀번호 인증 사용 확인) |
| WordPress 브라우저 접속 | ✅ 블로그 메인 페이지 및 예제 페이지 정상 확인 |
| terraform destroy | ✅ Resources: 5 destroyed |

---

## 10. 결론

이번 실습을 통해 단일 EC2에 모든 것을 올리는 방식의 한계
(단일 장애점, 수평 확장 불가, 수동 운영 부담)를 이해하고,
웹 계층과 데이터 계층을 분리하는 Two-Tier 아키텍처를 Terraform으로 구현했다.

RDS의 `publicly_accessible = false`와 Security Group을 이용한 다층 보안 경계가
프로덕션 클라우드 아키텍처의 기본임을 확인했다.

또한 Terraform의 `templatefile()`로 RDS 엔드포인트를 EC2 user_data에 동적으로
주입하는 패턴을 익혔으며, `depends_on`으로 RDS가 완전히 준비된 후 EC2가
생성되도록 리소스 의존성을 명시하는 방법도 학습했다.
