# 02 — Phiên bản PHP bị ảnh hưởng và cách kiểm tra

## Bảng phiên bản PHP upstream đã vá

| Nhánh | Bản vá upstream tối thiểu |
|---|---|
| PHP 8.5 | **8.5.12** |
| PHP 8.4 | **8.4.27** |
| PHP 8.3 | **8.3.36** |
| PHP 8.2 | **8.2.35** |
| PHP 8.1 trở xuống | Không có bản upstream mới trong bảng; kiểm tra chính sách vendor hoặc nâng nhánh |

> **Vendor backport:** Gói Ubuntu/Debian/RHEL có thể được vá mà vẫn mang upstream version thấp hơn. Phải đối chiếu USN/DSA/RHSA, package changelog và PHP runtime thực sự phục vụ website. Không kết luận chỉ từ `php -v`.

## Trước tiên: kiểm tra toàn bộ phiên bản bằng script read-only

```bash
git clone https://github.com/phuongnguyenitpro/php2shell.git
cd php2shell
bash scripts/php2shell-check.sh
bash scripts/php2shell-verify.sh
```

Script liệt kê PHP CLI/FPM/CGI ở những vị trí thông dụng, các gói PHP, PHP-FPM service và thông tin pool. Bản PHP chạy web có thể **khác** bản PHP CLI.

## Kiểm tra thủ công (không mặc định PHP 8.4)

```bash
cat /etc/os-release
command -v php >/dev/null 2>&1 && php -v || true

for bin in /usr/bin/php[0-9]* /usr/bin/php-cgi[0-9]* \
           /usr/sbin/php-fpm[0-9]* /usr/local/bin/php[0-9]* \
           /usr/local/sbin/php-fpm[0-9]*; do
  [ -x "$bin" ] || continue
  printf '%s: ' "$bin"
  "$bin" -v 2>/dev/null | head -n 1
done

if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${binary:Package} ${Version}\n' 'php*' 2>/dev/null || true
fi
if command -v systemctl >/dev/null 2>&1; then
  systemctl list-units --all --type=service 'php*-fpm.service' --no-pager
fi
```

**Bắt buộc đối chiếu:** PHP-FPM socket/pool mà Nginx vhost dùng, Apache PHP handler hoặc PHP runtime trong container. Các lệnh trên không tự xác minh được mọi container, custom build hoặc bản vá backport.

## Cách hiểu kết quả

- **PASS:** đạt baseline phiên bản PHP upstream được phát hiện; chưa chứng minh website thực sự chạy bản đã vá.
- **WARN:** phiên bản thấp hơn, EOL, không tìm thấy bản tương ứng hoặc chưa xác minh vendor backport.
- **FAIL:** chỉ ở chế độ `--upstream-only` khi runtime chắc chắn không nhận backport mà không đạt baseline.

Nguồn: [PHP Releases](https://www.php.net/downloads.php) · [Ubuntu Security Notices](https://ubuntu.com/security/notices) · [README](../README.md).
