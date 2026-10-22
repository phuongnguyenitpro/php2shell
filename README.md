# PHP2Shell — Hướng dẫn kiểm tra và khắc phục lỗ hổng PHP Core

> **PHUONGIT | Community Security Guide**  
> **CVE-2026-109618 · CVE-2026-109619 · Critical (CVSS v4.0 9.2)**  
> Cập nhật nội dung: **22/10/2026** · Nội dung phòng vệ, không cung cấp mã khai thác.

PHP2Shell là tên gọi chung của hai lỗ hổng **an toàn bộ nhớ trong PHP Core**, được công bố ngày **21/10/2026**. Trong những điều kiện thích hợp, kẻ tấn công **không cần xác thực** có thể khai thác để thực thi mã từ xa (RCE) hoặc truy cập dữ liệu trong bộ nhớ tiến trình PHP. Đây **không phải lỗi riêng** của WordPress, Laravel hay bất kỳ CMS nào.

**Việc cần làm ngay:** kiểm kê tất cả PHP runtime đang phục vụ HTTP, cập nhật bản vá từ PHP Group hoặc nhà cung cấp hệ điều hành, khởi động lại worker và xác minh ứng dụng hoạt động bình thường. **Không có biện pháp giảm thiểu nào thay thế hoàn toàn bản vá.**

## 1. Tổng quan

| Trường | Nội dung |
|---|---|
| CVE | [CVE-2026-109618](https://nvd.nist.gov/vuln/detail/CVE-2026-109618), [CVE-2026-109619](https://nvd.nist.gov/vuln/detail/CVE-2026-109619) |
| Mức độ | Critical — **CVSS 4.0: 9.2** cho từng CVE, theo advisory |
| Thành phần | PHP Core (quản lý bộ nhớ / xử lý và kết thúc request) |
| Tác động | Remote Code Execution (RCE), nguy cơ truy cập bộ nhớ nhạy cảm |
| Điều kiện | Phụ thuộc cách triển khai, SAPI, trạng thái và luồng xử lý request |
| Phạm vi | PHP-FPM, Apache mod_php, php-cgi và các runtime nhúng/đóng gói PHP có thể bị ảnh hưởng |
| Ngày công bố | 21/10/2026 |

### Hai cơ chế lỗi

- **CVE-2026-109618 — Out-of-Memory (OOM) corruption:** PHP thoát xử lý bằng `longjmp()` trong tình huống thiếu bộ nhớ; dữ liệu request có thể ở trạng thái chưa được khởi tạo đầy đủ, nhưng giai đoạn cleanup vẫn truy cập dữ liệu đó.
- **CVE-2026-109619 — stale global state / Use-After-Free:** một số biến trạng thái toàn cục có thể tiếp tục trỏ đến bộ nhớ của request đã giải phóng và bị sử dụng lại trong request khác.

Không nên suy luận rằng một website chỉ an toàn vì đã cập nhật WordPress/plugin, hoặc vì chức năng upload không công khai. Phải đánh giá **PHP engine thực sự xử lý request**.

## 2. Phiên bản và hướng xử lý

| Nhánh PHP | Bản vá PHP upstream tối thiểu | Ghi chú |
|---|---|---|
| 8.5 | **8.5.12** | Bản vá phát hành 21/10/2026 |
| 8.4 | **8.4.27** | Bản vá phát hành 21/10/2026 |
| 8.3 | **8.3.36** | Bản vá phát hành 21/10/2026 |
| 8.2 | **8.2.35** | Hỗ trợ bảo mật đến 31/12/2026 |
| 8.1 trở xuống | **Không có bản vá upstream mới** | Nâng cấp hoặc xác thực gói backport từ vendor |
| Nhánh khác / development build | **Chưa xác định bằng bảng này** | Đối chiếu advisory/vendor cụ thể |

> **Quan trọng về vendor backport:** Ubuntu, Debian, RHEL và các nhà cung cấp LTS có thể vá CVE nhưng giữ số phiên bản PHP gốc (có thêm revision). Không kết luận “chưa vá” chỉ vì `php -v` thấp hơn bản phát hành upstream. Phải kiểm tra **USN/DSA/RHSA**, package changelog và nguồn repository. Ngược lại, kiểm tra PHP CLI không đủ để chứng minh PHP-FPM, container hoặc web worker đã vá.

## 3. Kiểm tra nhanh (read-only)

```bash
php -v
command -v php
# Nếu đã cài PHP-FPM cho nhánh tương ứng:
php-fpm8.4 -v
# Với Ubuntu/Debian:
dpkg-query -W 'php*' 2>/dev/null
apt-cache policy php8.4-fpm php8.4-cli
# Trạng thái dịch vụ:
systemctl status php8.4-fpm --no-pager
```

Chạy hai script đi kèm trên **máy chủ do bạn có quyền quản trị**:

```bash
bash scripts/php2shell-audit.sh
bash scripts/php2shell-verify.sh
```

- `audit.sh`: thống kê phiên bản CLI/FPM/CGI phổ biến, gói PHP và dịch vụ; **không thay đổi hệ thống**.
- `verify.sh`: đánh giá theo baseline upstream với nhãn **PASS / WARN / FAIL**; `WARN` bắt buộc xác minh backport/vendor và web-serving SAPI. **PASS không phải chứng nhận hệ thống không bị xâm nhập.** Mặc định kết quả thấp hơn baseline là `WARN` để tránh bỏ qua khả năng vendor backport; chỉ dùng `--upstream-only` khi đã xác nhận chắc chắn runtime là upstream build không có backport (khi đó kết quả có thể là `FAIL`). Exit code: `0=PASS`, `1=WARN`, `2=FAIL`.

Chi tiết: [Affected Versions](docs/02-affected-versions.md) · [Verification](docs/07-verification-checklist.md)

## 4. Quy trình vá lỗi (không tự thực thi trên PROD)

1. **Inventory:** xác định mọi phiên bản PHP được cài, CLI/FPM/Apache/CGI, PHP container/embedded runtime, virtual host và pool thực tế.
2. **Backup + rollback point:** mã nguồn, DB, file cấu hình, package version, snapshot/backup VM; **kiểm tra restore**. Không đưa secret vào báo cáo.
3. **DEV:** kiểm thử tương thích Composer và các extension với bản PHP đã vá.
4. **UAT:** kiểm thử chức năng website, đăng nhập, form, upload, API, DB, queue, cron, media; quan sát lỗi/log.
5. **PROD:** thực hiện trong change window đã duyệt, cài package security update từ nguồn tin cậy, restart PHP-FPM/Apache/workers.
6. **Verify:** kiểm tra phiên bản runtime thực, nguồn gói, thay thế worker cũ; xác minh HTTP, error logs và các chức năng trọng yếu.
7. **Theo dõi:** rà soát WAF/web access logs, anomalous PHP processes, file lạ và bất thường tài khoản. Nếu nghi đã bị xâm nhập, chuyển sang Incident Response; **vá lỗi không tự loại bỏ webshell**.

Xem hướng dẫn: [Ubuntu/Debian + Nginx/PHP-FPM](docs/03-ubuntu-nginx-php-fpm.md).

## 5. Tác hại nếu không cập nhật

Khai thác thành công có **khả năng** dẫn tới: sửa hoặc thay nội dung website, chèn mã độc/webshell, đánh cắp dữ liệu hoặc credentials ứng dụng, gián đoạn dịch vụ, ransomware/mã hóa dữ liệu khi kẻ tấn công có đủ quyền và điều kiện. Mức độ thực tế tùy quyền PHP worker, kiểm soát mạng, phân quyền file, cấu hình ứng dụng và khả năng di chuyển ngang. **Không đồng nhất “có CVE” với “đã bị xâm nhập”.**

## 6. Ứng dụng thường gặp

- **WordPress:** cập nhật PHP engine và kiểm thử theme/plugin; chỉ cập nhật WordPress/plugin là **chưa đủ**. [Chi tiết](docs/04-wordpress-hardening.md).
- **Laravel:** kiểm tra PHP-FPM, CLI chạy Artisan, Composer platform requirements, worker/queue, cache; không tùy tiện `composer update` hoặc migrate DB trên PROD. [Chi tiết](docs/05-laravel-hardening.md).
- **CMS/PHP khác:** các ứng dụng chạy runtime bị ảnh hưởng đều cần được đánh giá, kể cả không có chức năng upload.

## 7. Khi chưa thể cập nhật

Các biện pháp giảm bề mặt tấn công (WAF, hạn chế public access khi phù hợp, giới hạn request/upload, vô hiệu hóa tính năng rủi ro theo hướng dẫn PHP, theo dõi log, recycle worker) **chỉ là biện pháp tạm thời và không khắc phục hoàn toàn các CVE**. Ưu tiên cô lập dịch vụ nhạy cảm cho đến khi cập nhật an toàn. Tham khảo [Hướng dẫn giảm thiểu tạm thời và menu kiểm tra/cập nhật](docs/08-temporary-mitigations.md) và [Incident Response](docs/06-incident-response.md).

## 8. Tài liệu hướng dẫn

| Tài liệu | Nội dung |
|---|---|
| [01 — Tổng quan](docs/01-overview.md) | Cơ chế lỗi, mô hình ảnh hưởng |
| [02 — Affected Versions](docs/02-affected-versions.md) | Bảng phiên bản, backport, inventory |
| [03 — Ubuntu / Nginx / PHP-FPM](docs/03-ubuntu-nginx-php-fpm.md) | Lộ trình cập nhật có backup, UAT, rollback |
| [04 — WordPress](docs/04-wordpress-hardening.md) | Hướng dẫn ứng dụng và hardening |
| [05 — Laravel](docs/05-laravel-hardening.md) | Runtime, Composer, worker, logs |
| [06 — Incident Response](docs/06-incident-response.md) | Điều tra và ứng phó nghi xâm nhập |
| [07 — Verification](docs/07-verification-checklist.md) | Checklist nghiệm thu DEV/UAT/PROD |
| [08 — Temporary Mitigations](docs/08-temporary-mitigations.md) | Biện pháp giảm thiểu tạm thời, giới hạn và rủi ro |


## 9. Nguồn chính thức

1. [PHP Group — Security advisory ngày 21/10/2026](https://www.php.net/archive/2026.php#2026-10-21-5)
2. [PHP Group — Download security releases](https://www.php.net/downloads.php)
3. [PHP Group — Supported versions](https://www.php.net/supported-versions.php)
4. [GitHub Security Advisory GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w)
5. [GitHub Security Advisory GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)
6. [Ubuntu — PHP2Shell fixes available](https://ubuntu.com/blog/php2shell-vulnerability-fixes-available)
7. [Ubuntu Security Notices](https://ubuntu.com/security/notices)
8. [PHP2Shell — Community landing page](https://www.php2shell.com/#upgrade-php)

## 10. Tuyên bố sử dụng

Đây là tài liệu cộng đồng, dùng cho mục đích **phòng vệ, đào tạo và khắc phục lỗ hổng**. Các script kiểm tra chỉ đọc và không khai thác/quét Internet. Riêng `php2shell-remediate.sh` có thể cập nhật package hoặc thay đổi PHP-FPM pool sau các bước xác nhận rõ ràng; cần backup, DEV/UAT và change approval trước khi dùng trên PROD. Nội dung cập nhật theo bằng chứng đã công bố vào **22/10/2026**; cần đối chiếu advisory mới nhất trước khi thay đổi Production.

**Maintainer:** PHUONGIT · **License:** [MIT](LICENSE) · [Security Policy](SECURITY.md)

## 11. Script kiểm tra và menu khắc phục

```bash
# Kiểm tra chỉ đọc, không yêu cầu root
bash scripts/php2shell-check.sh

# Menu tương tác; các hành động thay đổi yêu cầu sudo và xác nhận
sudo bash scripts/php2shell-remediate.sh
```

Menu có chức năng kiểm tra OS/PHP, đề xuất nâng đúng nhánh `8.2 → 8.2.35`, `8.3 → 8.3.36`, `8.4 → 8.4.27`, `8.5 → 8.5.12` và giảm thiểu PHP-FPM tạm thời khi chưa cập nhật được. **Không hỗ trợ ép version đúng từng số trên mọi repository**; cập nhật các gói ứng viên đã vá do APT cung cấp và không tự chạy nếu chỉ thấy phiên bản upstream thấp hơn mà chưa xác minh vendor backport. Giảm thiểu tạm thời không thay thế bản vá, có thể ảnh hưởng uploads/RAM và cần kiểm thử. [Chi tiết](docs/08-temporary-mitigations.md).
