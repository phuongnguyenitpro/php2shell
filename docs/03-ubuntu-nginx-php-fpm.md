# 03 — Hướng dẫn Ubuntu / Debian, Nginx và PHP-FPM

> Chỉ triển khai trên máy chủ được ủy quyền. Không chạy thay đổi production nếu chưa có backup, change approval và phương án rollback.

## A. Inventory, backup

```bash
cat /etc/os-release
php -v
systemctl list-units --type=service --all 'php*-fpm.service'
dpkg-query -W 'php*' 2>/dev/null
apt-cache policy php8.4-cli php8.4-fpm
sudo nginx -t
```

Sao lưu mã nguồn, cơ sở dữ liệu, uploads, cấu hình `/etc/php/`, `/etc/nginx/`, xác nhận có thể khôi phục. Xác định đường dẫn PHP-FPM socket từ server block Nginx và phiên bản PHP của từng pool. Không đưa `.env`, khóa bí mật hoặc credentials vào issue/log công khai.

## B. DEV → UAT → PROD

1. **DEV:** kiểm tra PHP extension, Composer platform requirements, deprecated API, PHP-FPM pool và cấu hình dự kiến.
2. **UAT:** thực hiện test đăng nhập, API, DB, uploads, media, cron/queue, session/cookie và lỗi HTTP 5xx.
3. **PROD:** lên maintenance window, sao lưu và thực hiện nâng security package từ repository tin cậy; không tùy tiện thay toàn bộ stack.

Ví dụ gói cần kiểm tra (không chạy nguyên lệnh khi package không phù hợp):

```bash
sudo apt update
apt-cache policy php8.4-cli php8.4-common php8.4-fpm
sudo apt install --only-upgrade php8.4-cli php8.4-common php8.4-fpm
sudo systemctl restart php8.4-fpm
sudo nginx -t && sudo systemctl reload nginx
php-fpm8.4 -v
```

Đối chiếu extension đang cài và nâng các package liên quan; kiểm tra repo thực tế đã có CVE fix. Không dùng `composer update` hoặc database migration trên PROD như một phần vá PHP nếu chưa phê duyệt.

## C. Xác minh

- Live web-vhost chạy PHP-FPM pool đã vá, không chỉ CLI.
- Gói và changelog vendor có đủ hai CVE; không còn worker chạy binary cũ.
- HTTP 200/301 hợp lệ; DB, API, login, upload, media và logs ổn định.
- Theo dõi error logs Nginx/PHP-FPM và application sau thay đổi.

## D. Rollback

Chỉ khôi phục trong kịch bản được phê duyệt và không đưa runtime dễ bị khai thác trở lại Internet. Có thể đưa website vào maintenance/cô lập, sửa tương thích hoặc khôi phục bằng bản PHP an toàn khác. Rollback DB chỉ khi có thay đổi DB và đã được kiểm chứng.
