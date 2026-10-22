# 03 — Hướng dẫn cập nhật PHP trên Ubuntu/Debian, Nginx & PHP-FPM

> Chỉ thực hiện trên hệ thống có quyền quản trị. Không thay đổi PROD nếu chưa backup, change approval, kiểm tra vendor package và phương án rollback.

## A. Kiểm kê trước khi chọn bản PHP

**Không mặc định hệ thống đang chạy PHP 8.4.** Trước tiên chạy script liệt kê toàn bộ PHP Runtime ở các đường dẫn phổ biến:

```bash
bash scripts/php2shell-check.sh
```

Nếu không có repo, có thể chạy lệnh tổng quát:

```bash
cat /etc/os-release
command -v php >/dev/null 2>&1 && php -v || true
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 'php*' 2>/dev/null || true
fi
if command -v systemctl >/dev/null 2>&1; then
  systemctl list-units --all --type=service 'php*-fpm.service' --no-pager
fi
```

Xác định chính xác `fastcgi_pass` trong Nginx vhost, socket và PHP-FPM pool đang xử lý HTTP request. PHP CLI có thể khác PHP-FPM. Container/custom build cần kiểm tra riêng.

## B. Backup và đánh giá candidate package

- Backup source, database, uploads, `/etc/php/`, Nginx config, package manifest và VM snapshot (nếu có). Kiểm thử khả năng restore.
- Chọn **đúng PHP branch đang phục vụ web**, chẳng hạn 8.2, 8.3, 8.4 hoặc 8.5. Không tự thay đổi nhánh đang dùng.
- Kiểm tra gói PHP-FPM/CLI/extensions ở cùng nhánh, nguồn APT, package changelog và advisory.
- **Nếu vendor backport phiên bản thấp hơn upstream**, dừng cập nhật tự động và xác minh USN/DSA tương ứng; không ép nâng nhánh chỉ để đổi version string.

Sử dụng menu tương tác có mô phỏng APT, xác nhận trước khi thay đổi:

```bash
sudo bash scripts/php2shell-remediate.sh
# Chọn 1 để kiểm tra, 2 để chọn nhánh nâng package
```

Script chỉ hỗ trợ update qua APT cho Ubuntu/Debian và PHP-FPM layout thông dụng, khi APT candidate đáp ứng baseline upstream. Nó không tự sao lưu toàn bộ DB/source/VM trước khi nâng package. Không dùng `composer update` hay migration DB như biện pháp vá PHP nếu chưa phê duyệt.

## C. DEV → UAT → PROD

1. **DEV:** test PHP extensions, Composer platform requirements, PHP-FPM pool, plugin/framework.
2. **UAT:** test đăng nhập, API, database, uploads, media, session/cookie, cron/queue, PHP logs.
3. **PROD:** maintenance window, backup/rollback point đã xác minh; cập nhật package qua repository tin cậy và restart PHP-FPM/web workers sau khi được phê duyệt.

## D. Xác minh sau cập nhật

- Gói đang cài đã chứa bản vá **cả hai CVE** theo advisory từ vendor.
- PHP-FPM pool thực sự phục vụ website chạy bản đã vá và không còn worker binary cũ.
- Ứng dụng đáp ứng HTTP 200/301 hợp lệ; chức năng DB, API, login, upload/media hoạt động.
- Kiểm tra logs PHP-FPM, Nginx và ứng dụng; giám sát lỗi mới.
- Nếu nghi compromise: xem [Incident Response](06-incident-response.md).

## E. Khi chưa thể cập nhật và rollback

Các mitigation như giới hạn upload, vô hiệu hóa session upload progress và giới hạn bộ nhớ phù hợp chỉ giảm rủi ro tạm thời; **không sửa lỗi PHP Core**. [Hướng dẫn mitigation chi tiết](08-temporary-mitigations.md).

Không rollback về một bản PHP dễ bị khai thác trên Internet. Khi xảy ra lỗi, cân nhắc cô lập service, sửa tương thích hoặc phục hồi sang phiên bản runtime an toàn khác.
