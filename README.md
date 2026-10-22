# PHP2Shell — Community Security Guide & Toolkit

> **PHUONGIT | Defensive Security · PHP Core**  
> **CVE-2026-109618 · CVE-2026-109619 · Critical (CVSS v4.0 9.2 theo advisory)**  
> **Cập nhật:** 22/10/2026 · **Phạm vi:** Hướng dẫn phòng vệ, kiểm kê runtime và khắc phục có kiểm soát; không cung cấp mã khai thác.

**PHP2Shell** là tên gọi chung cho hai lỗ hổng an toàn bộ nhớ trong PHP Core, được công bố ngày 21/10/2026. Trong những điều kiện thích hợp, kẻ tấn công không cần xác thực có thể dẫn tới thực thi mã từ xa (RCE) hoặc truy cập dữ liệu trong bộ nhớ PHP. Đây **không phải lỗi riêng** của WordPress, Laravel hay bất kỳ CMS cụ thể nào.

> **Ưu tiên thực hiện:** Kiểm tra các PHP Runtime thực sự phục vụ HTTP → đối chiếu bản vá từ PHP Group hoặc vendor OS → cập nhật → restart worker → nghiệm thu và giám sát. Cấu hình giảm thiểu tạm thời **không thay thế bản vá**.

## Nội dung

1. [Bắt đầu nhanh — kiểm tra tự động](#1-bắt-đầu-nhanh--kiểm-tra-tự-động)
2. [Kiểm tra thủ công — không cố định phiên bản PHP](#2-kiểm-tra-thủ-công--không-cố-định-phiên-bản-php)
3. [Hiểu đúng PHP2Shell và tác động](#3-hiểu-đúng-php2shell-và-tác-động)
4. [Phiên bản PHP và cách đọc kết quả](#4-phiên-bản-php-và-cách-đọc-kết-quả)
5. [Nâng cấp PHP bằng menu có kiểm soát](#5-nâng-cấp-php-bằng-menu-có-kiểm-soát)
6. [Chưa thể cập nhật — giảm thiểu tạm thời](#6-chưa-thể-cập-nhật--giảm-thiểu-tạm-thời)
7. [Quy trình DEV → UAT → PROD và nghiệm thu](#7-quy-trình-dev--uat--prod-và-nghiệm-thu)
8. [Lưu ý cho WordPress, Laravel và ứng dụng khác](#8-lưu-ý-cho-wordpress-laravel-và-ứng-dụng-khác)
9. [Tài liệu chuyên sâu](#9-tài-liệu-chuyên-sâu)
10. [Nguồn tham khảo](#10-nguồn-tham-khảo)
11. [Tuyên bố sử dụng và liên hệ tác giả](#11-tuyên-bố-sử-dụng-và-liên-hệ-tác-giả)

## 1. Bắt đầu nhanh — kiểm tra tự động

**Bước 1 — tải repository và chạy kiểm tra trước khi chọn phiên bản PHP.** Trên máy Linux mà bạn có quyền quản trị:

```bash
git clone https://github.com/phuongnguyenitpro/php2shell.git
cd php2shell

# Kiểm tra cục bộ, read-only, không thay đổi OS/PHP
bash scripts/php2shell-check.sh
```

`php2shell-check.sh` cố gắng thống kê các PHP binary ở đường dẫn thông dụng (CLI, FPM, CGI), OS/package manager, gói cài đặt, PHP-FPM services và cấu hình pool. **Không mặc định PHP 8.4**, không cần biết trước phiên bản và không cần `sudo` để kiểm tra cơ bản. Một máy có thể đồng thời có nhiều phiên bản PHP.

**Bước 2 — kiểm tra bổ sung hoặc đối chiếu baseline:**

```bash
bash scripts/php2shell-audit.sh
bash scripts/php2shell-verify.sh
```

Script `php2shell-verify.sh` đánh giá baseline PHP upstream, trả về exit code `0 = PASS`, `1 = WARN`, `2 = FAIL`; nếu không phải môi trường PHP upstream thuần, cần **kiểm tra vendor backport** trước khi kết luận. Chỉ dùng tùy chọn `--upstream-only` khi chắc chắn đang dùng upstream build không có bản vá backport.

> **Không hiểu nhầm:** Không tìm thấy PHP trong lệnh kiểm tra không có nghĩa máy an toàn — có thể ứng dụng chạy container, bản custom hoặc runtime ở đường dẫn khác. Kết quả PASS **không chứng minh** PHP-FPM đang phục vụ website đã vá hoặc máy chủ chưa bị xâm nhập.

## 2. Kiểm tra thủ công — không cố định phiên bản PHP

Có thể dùng các lệnh tổng quát bên dưới khi chưa tải repo hoặc cần kiểm chứng độc lập. **Chạy kiểm kê toàn bộ trước**, sau đó mới chọn đúng nhánh PHP đang hoạt động cho các bước nâng cấp.

### 2.1. Hệ điều hành và PHP CLI mặc định

```bash
cat /etc/os-release
if command -v php >/dev/null 2>&1; then
  command -v php
  php -v
else
  echo "Không tìm thấy lệnh PHP CLI mặc định trong PATH"
fi
```

Lệnh `php -v` chỉ cho biết **PHP CLI mặc định**, có thể khác hoàn toàn PHP-FPM/Apache đang phục vụ website.

### 2.2. Liệt kê phiên bản PHP-FPM/CGI/CLI theo binary có sẵn

```bash
# Không giả định máy có PHP 8.4; kiểm tra binary thông dụng của mọi nhánh đang cài
for bin in /usr/bin/php[0-9]* /usr/bin/php-cgi[0-9]* \
           /usr/sbin/php-fpm[0-9]* /usr/local/bin/php[0-9]* \
           /usr/local/bin/php-cgi[0-9]* /usr/local/sbin/php-fpm[0-9]*; do
  [ -x "$bin" ] || continue
  printf '%s: ' "$bin"
  "$bin" -v 2>/dev/null | head -n 1
done

# Liệt kê các service PHP-FPM trên hệ thống dùng systemd
if command -v systemctl >/dev/null 2>&1; then
  systemctl list-units --all --type=service 'php*-fpm.service' --no-pager
fi
```

Danh sách trên chỉ quét **đường dẫn thông dụng**, không bao phủ Docker, PHP nhúng, custom path hoặc mọi SAPI. Cần xác định `fastcgi_pass`/socket của Nginx, cấu hình Apache hoặc container thực sự nhận HTTP request để biết **runtime web-facing** nào cần vá.

### 2.3. Kiểm tra gói đã cài và candidate từ APT (Ubuntu/Debian)

```bash
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 'php*' 2>/dev/null || true

  # Chỉ xem APT candidate của các gói PHP-FPM đang cài
  if command -v apt-cache >/dev/null 2>&1; then
    dpkg-query -W -f='${binary:Package}\t${Status}\n' 'php*-fpm' 2>/dev/null |
    while IFS="$(printf '\t')" read -r pkg status; do
      [ "$status" = "install ok installed" ] || continue
      apt-cache policy "$pkg"
    done
  fi
fi
```

Với RPM/RHEL, Docker hoặc PHP custom, dùng package manager/container manifest và advisory tương ứng; **không áp dụng lệnh APT**. Không đưa output chứa thông tin nhạy cảm, cấu hình hoặc đường dẫn riêng lên issue công khai.

## 3. Hiểu đúng PHP2Shell và tác động

| Nội dung | Mô tả |
|---|---|
| Lỗ hổng | [CVE-2026-109618](https://nvd.nist.gov/vuln/detail/CVE-2026-109618), [CVE-2026-109619](https://nvd.nist.gov/vuln/detail/CVE-2026-109619) |
| Mức độ | Critical, CVSS v4.0 9.2 theo advisory |
| Thành phần | PHP Core — quản lý bộ nhớ và trạng thái trong vòng đời HTTP request |
| Nguy cơ | RCE, lộ dữ liệu trong bộ nhớ, mất toàn vẹn website và gián đoạn dịch vụ |
| Phạm vi | PHP-FPM, Apache mod_php, php-cgi và các runtime nhúng/đóng gói PHP cần được đánh giá |
| Công bố | 21/10/2026 |

- **CVE-2026-109618 — OOM corruption:** Xử lý thiếu bộ nhớ và dọn dẹp request có thể đưa tiến trình tới trạng thái bộ nhớ không nhất quán.
- **CVE-2026-109619 — stale global state / Use-After-Free:** Trạng thái toàn cục có thể giữ tham chiếu đến vùng nhớ đã được giải phóng.

Nếu khai thác thành công, kẻ tấn công **có thể** chỉnh sửa nội dung website, cài webshell, đánh cắp thông tin xác thực hoặc gây gián đoạn; trong điều kiện thích hợp có thể dẫn tới các ảnh hưởng sâu hơn như mã hóa dữ liệu. Mức độ thực tế phụ thuộc quyền PHP worker, cấu hình ứng dụng và các kiểm soát hạ tầng. **Có CVE không đồng nghĩa máy chủ đã bị tấn công.**

## 4. Phiên bản PHP và cách đọc kết quả

| Nhánh PHP | Bản vá upstream tối thiểu | Hướng xử lý |
|---|---|---|
| 8.5 | **8.5.12** | Cập nhật trong nhánh 8.5 và xác minh worker |
| 8.4 | **8.4.27** | Cập nhật trong nhánh 8.4 và xác minh worker |
| 8.3 | **8.3.36** | Cập nhật trong nhánh 8.3 và xác minh worker |
| 8.2 | **8.2.35** | Cập nhật trong nhánh 8.2 và kiểm tra vòng đời hỗ trợ |
| 8.1 trở xuống | Không có upstream security release mới trong bảng này | Lập kế hoạch nâng nhánh hoặc kiểm chứng hỗ trợ/backport của nhà cung cấp |
| Nhánh khác / custom | Chưa xác định bằng bảng trên | Xác minh advisory và build cụ thể |

**Phân biệt kết quả:**

- **PASS (upstream baseline):** version phát hiện đạt mốc upstream. Vẫn phải xác định đúng web-facing runtime, package và worker.
- **WARN:** version dưới baseline, EOL hoặc chưa xác định; không thể bỏ qua khả năng vendor OS đã **backport** bản vá.
- **FAIL:** chỉ kết luận từ script ở chế độ `--upstream-only` cho runtime được xác nhận là upstream thuần; không dùng kết quả này để thay thế bằng chứng từ vendor.

> **Vendor backport:** Ubuntu, Debian, RHEL và các nhà cung cấp LTS có thể vá CVE nhưng giữ upstream version thấp hơn, kèm package revision. Kiểm tra **USN/DSA/RHSA, package changelog và nguồn cài đặt**. Không chỉ dựa vào `php -v` hay tên package để kết luận toàn bộ hệ thống đã an toàn.

## 5. Nâng cấp PHP bằng menu có kiểm soát

**Ưu tiên cập nhật PHP Core.** Với Ubuntu/Debian cài PHP-FPM từ APT, sử dụng script hỗ trợ:

```bash
# Đã kiểm tra các phiên bản ở Mục 1 trước khi thay đổi
sudo bash scripts/php2shell-remediate.sh
```

| Menu | Chức năng | Có thay đổi hệ thống? |
|---|---|---|
| **1 — Check** | Kiểm kê OS/PHP và đánh giá baseline | **Không** |
| **2 — Upgrade** | Chọn đúng nhánh PHP-FPM đang cài (8.2/8.3/8.4/8.5), kiểm tra ứng viên APT, mô phỏng, xác nhận nâng package và xác nhận restart | **Có, khi xác nhận** |
| **3 — Temporary Mitigation** | Chọn một FPM pool, sao lưu config, giảm thiểu tạm thời, test cú pháp và xác nhận restart | **Có, khi xác nhận** |
| **0 — Exit** | Thoát | **Không** |

**Giới hạn thực tế của công cụ:**

- Script không tự chọn một bản PHP ngẫu nhiên; quản trị viên chọn trong **các nhánh PHP-FPM đã cài**. Không tự di trú từ 8.1 sang 8.2–8.5.
- APT upgrade chỉ tự tiếp tục khi candidate **đạt baseline upstream**; nếu gói vendor dùng bản vá backport nhưng version thấp hơn, script dừng để kiểm tra advisory/changelog thủ công. Không đảm bảo tự vá mọi hệ điều hành hay mọi cách cài PHP.
- Tùy chọn nâng package **không tự backup toàn bộ source/DB/VM**; quản trị viên phải làm việc này **trước** khi chọn nâng cấp. Restart có thể gây gián đoạn.
- Menu remediation chỉ hỗ trợ **Ubuntu/Debian + PHP-FPM có layout phổ biến**; không tự xử lý Apache mod_php, container, RPM hoặc custom builds.
- Không xem màn hình `PASS` là xác nhận không có webshell hoặc dấu hiệu xâm nhập.

Xem chi tiết trong [Hướng dẫn triển khai Ubuntu/Debian, Nginx và PHP-FPM](docs/03-ubuntu-nginx-php-fpm.md).

## 6. Chưa thể cập nhật — giảm thiểu tạm thời

**Các phương án sau không sửa được PHP Core và không chặn hết mọi biến thể khai thác.** Áp dụng sau khi đánh giá ảnh hưởng và ưu tiên giảm bề mặt Internet nếu rủi ro cao.

- **CVE-2026-109618 (OOM):** giới hạn `post_max_size` (tham khảo 8M khi không upload, 32M khi có upload); giữ `upload_max_filesize` nhỏ hơn; cấu hình giới hạn request tại proxy/web server. `memory_limit=-1` chỉ nên cân nhắc khi **đã xác nhận container/cgroup isolation và giới hạn bộ nhớ phù hợp**, vì có nguy cơ cạn RAM. Không dùng `RLIMIT_AS`/`RLIMIT_DATA` như thay thế.
- **CVE-2026-109619 (stale state):** dùng `session.upload_progress.enabled=0` ở cấu hình có hiệu lực trước parsing; **với PHP 8.5** có thêm `fatal_error_backtraces=0`. Restart worker và rà soát các lỗi fatal/timeout có thể bị kích hoạt từ request.
- Không dựa vào `ini_set()` hoặc `.user.ini` để áp dụng các mitigation cần có hiệu lực trước request. Đừng nhầm ẩn diagnostics với khắc phục lỗ hổng.

**Menu 3** tự áp dụng một phần biện pháp vào **một PHP-FPM pool đã chọn**, có backup file pool và kiểm tra syntax. Nó **không** cấu hình reverse proxy, không tạo cgroup và không bao quát các SAPI khác. Thay đổi kích thước upload có thể ảnh hưởng chức năng nghiệp vụ. [Xem hướng dẫn chi tiết](docs/08-temporary-mitigations.md).

## 7. Quy trình DEV → UAT → PROD và nghiệm thu

1. **Inventory:** Lập danh sách mọi PHP runtime/pool/container dùng cho website, workers và tác vụ nền; ánh xạ từng vhost tới runtime thực.
2. **Backup / rollback point:** Lưu source, database, uploads, `php.ini`, FPM pool config, proxy config, package versions và VM snapshot khi phù hợp; kiểm tra khả năng khôi phục.
3. **DEV:** Đối chiếu security package, PHP extensions, Composer platform requirements, khả năng tương thích ứng dụng.
4. **UAT:** Thử các luồng quan trọng: login, API, form, upload, session, DB, queue/cron và xử lý lỗi.
5. **PROD:** Chỉ thực hiện trong maintenance/change window đã được phê duyệt; cập nhật security packages, restart PHP-FPM/Apache và background workers cần thiết.
6. **Verification:** Xác minh vendor advisory, PHP **đang phục vụ web** đã vá, old worker đã được thay thế, HTTP/DB/upload hoạt động và error logs ổn định.
7. **Monitoring/IR:** Rà soát bất thường về process, file, WAF/access logs và tài khoản. Nếu nghi có khai thác thành công, áp dụng quy trình [Incident Response](docs/06-incident-response.md); **vá PHP không tự xóa webshell/backdoor**.

**Rollback:** Không đưa runtime đã biết chưa vá trở lại Internet công khai. Có thể cô lập dịch vụ, khắc phục vấn đề tương thích hoặc khôi phục sang bản runtime an toàn. [Checklist nghiệm thu](docs/07-verification-checklist.md).

## 8. Lưu ý cho WordPress, Laravel và ứng dụng khác

- **WordPress:** Vá PHP Runtime và kiểm thử theme/plugin. Cập nhật WordPress/plugin **không thay thế** PHP security patch. [Hướng dẫn WordPress](docs/04-wordpress-hardening.md).
- **Laravel:** Kiểm tra phiên bản PHP-FPM phục vụ web **và** PHP CLI chạy Artisan/queue, Composer dependencies, session/cache. Không tự chạy `composer update` hoặc migration trên PROD nếu chưa đánh giá ảnh hưởng. [Hướng dẫn Laravel](docs/05-laravel-hardening.md).
- **CMS/PHP khác:** Đánh giá mọi ứng dụng dùng PHP Core, kể cả không có form upload hoặc sử dụng runtime được đóng gói riêng.

## 9. Tài liệu chuyên sâu

| Tài liệu | Nội dung |
|---|---|
| [01 — Overview](docs/01-overview.md) | Cơ chế lỗi và phạm vi ảnh hưởng |
| [02 — Affected Versions](docs/02-affected-versions.md) | Bản vá theo nhánh và vendor backport |
| [03 — Ubuntu/Debian, Nginx & PHP-FPM](docs/03-ubuntu-nginx-php-fpm.md) | Quy trình kiểm kê, nâng cấp, nghiệm thu |
| [04 — WordPress](docs/04-wordpress-hardening.md) | Hardening và kiểm thử WordPress |
| [05 — Laravel](docs/05-laravel-hardening.md) | PHP-FPM, Composer, queue workers |
| [06 — Incident Response](docs/06-incident-response.md) | Khi nghi ngờ đã bị khai thác |
| [07 — Verification Checklist](docs/07-verification-checklist.md) | Tiêu chí DEV/UAT/PROD |
| [08 — Temporary Mitigations](docs/08-temporary-mitigations.md) | Mitigation theo CVE, nguy cơ và rollback |

**Các script:** [`php2shell-check.sh`](scripts/php2shell-check.sh) · [`php2shell-audit.sh`](scripts/php2shell-audit.sh) · [`php2shell-verify.sh`](scripts/php2shell-verify.sh) · [`php2shell-remediate.sh`](scripts/php2shell-remediate.sh).

## 10. Nguồn tham khảo

1. [PHP Group — Security advisory, 21/10/2026](https://www.php.net/archive/2026.php#2026-10-21-5)
2. [PHP Group — PHP Downloads](https://www.php.net/downloads.php)
3. [PHP Group — Supported Versions](https://www.php.net/supported-versions.php)
4. [GitHub Security Advisory GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w)
5. [GitHub Security Advisory GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)
6. [Ubuntu — PHP2Shell fixes available](https://ubuntu.com/blog/php2shell-vulnerability-fixes-available)
7. [Ubuntu Security Notices](https://ubuntu.com/security/notices)
8. [PHP2Shell — Upgrade PHP](https://www.php2shell.com/#upgrade-php)

## 11. Tuyên bố sử dụng và liên hệ tác giả

Tài liệu và công cụ này được chia sẻ vì mục đích **phòng vệ, đào tạo và khắc phục lỗ hổng**. Script kiểm tra là **read-only**, không khai thác hoặc quét Internet. Riêng `php2shell-remediate.sh` **có thể thay đổi gói phần mềm hoặc PHP-FPM config** sau khi quản trị viên lựa chọn, xác nhận; cần backup, DEV/UAT, phê duyệt thay đổi và kiểm thử trước khi chạy trên PROD.

Không có công cụ trong repo bảo đảm đã loại bỏ hoàn toàn nguy cơ hoặc xác nhận máy chủ không bị xâm nhập. Đối chiếu advisory của PHP Group và nhà cung cấp OS trước khi cập nhật Production.

**Tác giả/Maintainer:** **Phương Nguyễn – PhuongIT**  
**Email:** [phuongit.contact@gmail.com](mailto:phuongit.contact@gmail.com)  
**Facebook:** [facebook.com/jsisen](https://facebook.com/jsisen)  
**LinkedIn:** [linkedin.com/in/phuong-nguyen-van](https://www.linkedin.com/in/phuong-nguyen-van/)  
**License:** [MIT](LICENSE) · [Security Policy](SECURITY.md) · [Contributing](CONTRIBUTING.md)
