# 02 — Phiên bản bị ảnh hưởng

| Nhánh PHP | Bản phát hành upstream đã vá |
|---|---|
| 8.5 | 8.5.12 |
| 8.4 | 8.4.27 |
| 8.3 | 8.3.36 |
| 8.2 | 8.2.35 |
| 8.1 trở xuống | Không có bản vá upstream mới; nâng nhánh hoặc kiểm tra backport vendor |

**Không kết luận sai:** package Ubuntu/Debian/RHEL có thể backport bản vá dưới cùng upstream version và suffix package riêng. Kiểm tra chính xác USN/DSA/RHSA, `apt-cache policy`, `apt changelog` và bản PHP thực sự phục vụ website.

```bash
cat /etc/os-release
command -v php && php -v
dpkg-query -W -f='${binary:Package} ${Version}\n' 'php*' 2>/dev/null
apt-cache policy php8.4-cli php8.4-fpm
systemctl list-units --type=service --all 'php*-fpm.service'
ps -eo pid,comm | grep -E 'php-fpm|php-cgi|apache2|httpd' || true
```

Đánh giá container và custom source build riêng; kiểm tra lại live PHP-FPM worker sau khi vá. Nếu không xác định được backport hoặc SAPI, ghi nhận WARN, không đánh dấu PASS chung.

Nguồn: [PHP releases](https://www.php.net/downloads.php), [Ubuntu notices](https://ubuntu.com/security/notices).
