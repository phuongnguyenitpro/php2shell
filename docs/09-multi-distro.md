# PHP2Shell v3.0.0: Multi-Distro (pre-release)

**Mục đích:** kiểm kê, lập kế hoạch, hỗ trợ cập nhật có phê duyệt. Không quét Internet, không thử khai thác, không chứng minh host đã sạch mã độc.

## Menu tương tác đa nền tảng

```bash
# Dùng nhánh main để có menu mới
git clone https://github.com/phuongnguyenitpro/php2shell.git
cd php2shell
bash scripts/php2shell-multidistro.sh menu
```

Menu 1 Check (inventory), 2 Audit, 3 Verify, 4 Plan (APT candidate/DNF advisory), 5 Remediate (chỉ Ubuntu/Debian hoặc DNF4 thử nghiệm khi OS được phép), 6 Support, 0 Exit. Menu 5 yêu cầu gõ **REMEDIATE** trước khi vào luồng xác nhận riêng của từng OS. Khi chọn 1–4, cảnh báo hay exit-code bất thường sẽ được thông báo rồi trở về menu; không tự nâng cấp. Các hệ Alpine/SUSE/Arch chỉ hỗ trợ kiểm kê và hướng dẫn plan, không tự khắc phục.

**Không dùng `sudo` cho check/audit/verify/plan nếu không cần.** Chỉ dùng `sudo bash scripts/php2shell-multidistro.sh menu` trong DEV/UAT khi thực sự cần vào menu Remediate; kiểm tra backup, repository và maintenance window trước thay đổi. Nhánh `main` cập nhật sau tag `v3.0.0`.

## Quick Start

~~~bash
git clone https://github.com/phuongnguyenitpro/php2shell.git
cd php2shell
bash scripts/php2shell-multidistro.sh check
bash scripts/php2shell-multidistro.sh audit
bash scripts/php2shell-multidistro.sh plan
bash scripts/php2shell-multidistro.sh verify
# Chỉ trên host được phép thay đổi, sau DEV/UAT và backup:
sudo bash scripts/php2shell-multidistro.sh remediate
~~~

`check`, `audit`, `verify`: kiểm kê cục bộ, không thay đổi package/service. `plan`: không chủ ý thay đổi packages nhưng package manager có thể làm mới metadata cache. `remediate` yêu cầu xác nhận và có thể thay đổi packages; restart PHP-FPM phải được phê duyệt riêng. Không chạy remediation trực tiếp trên PROD khi chưa có kết quả DEV/UAT.

## Support Matrix

| Hệ | OS Detection | Inventory | Patch plan | Automated patch |
| --- | --- | --- | --- | --- |
| Ubuntu 22.04/24.04/26.04, Debian 12/13 (APT packages) | Có | Có | Candidate | Helper hiện hữu, có xác nhận, PHP-FPM tiêu chuẩn |
| RHEL / Rocky / AlmaLinux / Oracle Linux 8/9 | Có | Có | Vendor `dnf updateinfo` | **Thử nghiệm**: standard PHP RPM, có advisory liên quan cả hai CVE, xác nhận 2 bước |
| CentOS Stream 9 | Có | Có | Vendor advisory | **Thử nghiệm** như RHEL 9 |
| Ubuntu/Debian cũ, CentOS Linux 7/8, CentOS Stream 8 | Có | Có | Thủ công | Không (EOL/kiểm chứng hỗ trợ) |
| RHEL family 10 (DNF5), Fedora, Amazon Linux 2023 | Có | Có | DNF advisory | Không trong P0 |
| Alpine | Có | Có qua APK | Lệnh hướng dẫn | Không |
| SLES/openSUSE | Có | Có qua RPM | Lệnh hướng dẫn | Không |
| Arch/Manjaro | Có | Có qua Pacman | Lệnh hướng dẫn | Không |
| Containers/custom PHP/CPanel/CloudLinux/Remi parallel packages | Một phần | Một phần | Manual | Không |

**Lưu ý quan trọng:** việc phát hiện chỉ giới hạn những lệnh hệ thống và đường dẫn phổ biến. Họ RHEL có thể backport CVE mà không thay upstream version. Không coi `php -v` là bằng chứng đã vá. Khi metadata `updateinfo` không hiển thị cả hai CVE gắn với PHP, module DNF từ chối nâng cấp. Đây là cơ chế fail-closed; có thể chặn cả bản vá hợp lệ mà vendor không gắn metadata phù hợp.

## Quy trình trước khi sửa Production

1. Inventory: ánh xạ vhost Nginx/Apache → PHP-FPM socket/handler thực tế; kiểm tra container, đường dẫn custom.
2. Vendor evidence: đối chiếu advisory, package NEVRA/changelog/repo origin và kiểm tra PHP-FPM worker.
3. Backup: source, database, uploads, cấu hình web/FPM, snapshot nếu phù hợp; kiểm tra rollback.
4. DEV → UAT: PHP extensions/Composer, login, session, DB, API, upload, cron/queues.
5. PROD: change window và duyệt transaction plan. Script không chủ động đổi repo/module stream, nhưng vẫn cần xem xét dependencies và những thay đổi DNF có thể đề xuất trước khi xác nhận.
6. Verification: restart worker theo duyệt riêng, kiểm tra process/pool, smoke test HTTP/DB/upload, log/WAF và trạng thái CVE từ vendor.
7. Incident Response: nếu nghi có khai thác, cập nhật package không thay thế điều tra/cleanup webshell.

### Kiểm tra thủ công trên RPM/RHEL

~~~bash
cat /etc/os-release
rpm -qa | grep '^php'
dnf module list php                   # Chỉ có trên một số phiên bản RHEL/DNF4
dnf updateinfo info --cve CVE-2026-109618
dnf updateinfo info --cve CVE-2026-109619
dnf list installed 'php*'
~~~

### Giới hạn kiểm thử hiện tại

`bash tests/test-multidistro.sh` xác nhận 18 tình huống nhận diện OS, cú pháp và tham số. **Chưa** có integration test giao dịch package thực tế trên Rocky/Alma/RHEL/Debian VM. GitHub CI trên Ubuntu runner không chứng minh DNF remediation đã an toàn trên từng distro. Trước khi phát hành stable phải thực hiện E2E VM matrix, thu thập evidence và ký nghiệm thu.

Nguồn: [DNF reference](https://dnf.readthedocs.io/en/stable/command_ref.html) · [Rocky Errata](https://docs.rockylinux.org/latest/teams/rel_eng/errata/) · [Alma Errata](https://wiki.almalinux.org/documentation/errata.html) · [PHP Alpine](https://www.php.net/manual/en/install.unix.alpine.php)
