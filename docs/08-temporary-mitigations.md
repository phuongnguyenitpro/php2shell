# 08 — Biện pháp giảm thiểu PHP2Shell khi CHƯA cập nhật kịp

> **CẢNH BÁO:** Đây chỉ là các biện pháp giảm bề mặt khai thác đã được xác nhận. **Không sửa được lỗ hổng PHP Core**. PHP Group khẳng định cập nhật bản PHP đã vá là giải pháp hoàn chỉnh. Nếu hệ thống có rủi ro cao và chưa vá được, cân nhắc hạn chế Internet hoặc tạm ngừng dịch vụ.

## CVE-2026-109618 — OOM corruption

1. Đặt `memory_limit=-1` thông qua cấu hình mà ứng dụng không ghi đè được, ví dụ `php_admin_value[memory_limit] = -1` tại PHP-FPM pool hoặc Apache server. **Nguy cơ:** ứng dụng runaway có thể dùng hết RAM vật lý. Chỉ triển khai sau khi đã thiết kế giới hạn tài nguyên ở mức container/cgroup và kiểm tra ảnh hưởng vận hành. Dù bỏ giới hạn PHP, allocation failure cấp thấp vẫn có thể chạm đường lỗi.
2. Đặt `post_max_size=8M` nếu không cần uploads; `32M` nếu có uploads, và `upload_max_filesize` thấp hơn. Test chức năng; site xử lý tệp lớn có thể không dùng được mức mặc định.
3. Giới hạn request body đã giải mã, field count, multipart part count, header count và nesting depth ở proxy/web server (kể cả request không có `Content-Length`). Những giới hạn này tùy web stack nên script **không tự thêm rule Nginx/Apache**.
4. Dùng container/cgroup làm ranh giới khả dụng, ưu tiên cô lập từng worker. **Không thay bằng `RLIMIT_AS` hoặc `RLIMIT_DATA`** vì có thể kích hoạt allocation failure dễ khai thác.

## CVE-2026-109619 — stale global state

1. Đặt `session.upload_progress.enabled=0` ở `php.ini` hoặc FPM pool/server config được nạp **trước request parsing**; **restart mọi worker**. Chỉ chặn những đường tấn công session đã xác nhận.
2. Riêng **PHP 8.5**, đặt `fatal_error_backtraces=0` và restart mọi worker. Chỉ giảm đường fatal-error backtrace đã xác nhận.
3. Loại bỏ các cài đặt sai hoặc deprecated áp dụng theo từng request gây diagnostic trước khi hoàn tất khởi tạo. Chỉ tắt `error_reporting` hoặc `display_errors` không khắc phục.
4. Sửa fatal errors và timeouts do người ngoài có thể kích hoạt trong callbacks, upload/import, cleanup.

**Không dùng `ini_set()` hoặc FPM `.user.ini` cho các mitigation phải có hiệu lực trước khi PHP xử lý request.**

## Ví dụ PHP-FPM pool (thử DEV/UAT trước)

```ini
; Session path (partial mitigation)
php_admin_value[session.upload_progress.enabled] = 0
; Site without file uploads
php_admin_value[post_max_size] = 8M
php_admin_value[upload_max_filesize] = 6M
; PHP 8.5 only:
php_admin_value[fatal_error_backtraces] = 0
; Only if a verified isolation/memory policy exists:
; php_admin_value[memory_limit] = -1
```

## Script dành cho Ubuntu/Debian PHP-FPM

```bash
# Kiểm tra phiên bản và các pool (không thay đổi hệ thống):
bash scripts/php2shell-check.sh

# Menu tương tác:
sudo bash scripts/php2shell-remediate.sh
```

| Menu | Hành động | Giới hạn |
|---|---|---|
| 1 | Kiểm tra OS, PHP CLI/FPM, packages, tên pool | Không xác định đã bị khai thác, không chứng thực live web SAPI |
| 2 | Cập nhật **cùng nhánh** PHP 8.2/8.3/8.4/8.5 bằng candidate từ APT | Chỉ khi candidate thể hiện baseline upstream đã vá; vendor backport cần xác minh thủ công |
| 3 | Giảm thiểu tạm thời tại **một** FPM pool được chọn, sao lưu trước, test `php-fpm -t`, hỏi xác nhận restart | Không tự thay cấu hình Apache/mod_php, không bảo đảm mọi pool và container đã có cùng cấu hình |

### Nâng cấp theo đúng nhánh

| Đang chạy | Phiên bản vá ít nhất |
|---|---|
| 8.2.x | **8.2.35** |
| 8.3.x | **8.3.36** |
| 8.4.x | **8.4.27** |
| 8.5.x | **8.5.12** |

Không có target **8.3.27**. Script không ép hạ phiên bản, không tải binary bên ngoài và không tự di trú PHP 8.1 hoặc cũ hơn. Không được coi **PASS của CLI** là bằng chứng ứng dụng đang dùng bản PHP đã vá. Gói Ubuntu/Debian backport cần đối chiếu USN/DSA và package changelog.

### Kiểm thử và khôi phục

- Trước khi dùng: snapshot/backup source, DB, PHP config, ghi nhận live FPM vhost mapping. Chạy DEV → UAT → PROD theo change window.
- Sau update: xem PHP-FPM đã restart, theo dõi logs, kiểm thử API, login, uploads, PHP extensions, DB và worker nền.
- Sau mitigation: xác minh setting từ **web-serving pool** bằng phương pháp nội bộ an toàn; không tạo trang public `phpinfo()`.
- Script sao lưu cấu hình tại `/var/backups/php2shell-community/<timestamp>/php<version>/<file>.conf`. Nếu lỗi syntax hoặc restart, script cố khôi phục file ban đầu. Khôi phục thủ công từ backup nếu test ứng dụng lỗi.
- Nếu có indicator of compromise: áp dụng Incident Response; cập nhật gói PHP không loại bỏ webshell/backdoor đã tồn tại.

Nguồn: [PHP Group advisory](https://www.php.net/archive/2026.php#2026-10-21-5) · [PHP2Shell](https://www.php2shell.com/#upgrade-php) · [GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) · [GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)
