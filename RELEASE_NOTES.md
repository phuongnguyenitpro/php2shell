# PHP2Shell Community Security Toolkit v2.0.0

**Ngày phát hành dự kiến:** 22/10/2026  
**Tác giả:** Phương Nguyễn – PhuongIT  
**Phạm vi:** Defensive Security · PHP Core · Ubuntu/Debian · PHP-FPM

> **Từ Security Guide đến Security Toolkit:** phiên bản v2.0.0 bổ sung công cụ kiểm tra PHP Runtime và menu hỗ trợ nâng cấp hoặc triển khai biện pháp giảm thiểu tạm thời, trên cơ sở tài liệu phòng vệ đã có ở v1.0.0.

## 1. Điểm mới trong v2.0.0

### PHP2Shell Check — Kiểm tra cục bộ, chỉ đọc

Script `scripts/php2shell-check.sh`:

- Nhận diện hệ điều hành và cơ chế quản lý gói (dpkg/APT, RPM nếu có).
- Thống kê PHP CLI, PHP-FPM, PHP-CGI và các phiên bản PHP phổ biến được cài.
- Đối chiếu phiên bản với baseline bản vá PHP upstream.
- Liệt kê package PHP, PHP-FPM service và những thiết lập bảo mật được khai báo trong pool config.
- Cảnh báo trường hợp cần kiểm tra **vendor backport** hoặc PHP runtime được đóng gói riêng.

**Giới hạn:** Đây là công cụ kiểm kê/cảnh báo; không khai thác lỗ hổng, không quét Internet, không xác nhận hệ thống đã hoặc chưa bị xâm nhập. PHP CLI không chứng minh được PHP web-facing đã vá.

### PHP2Shell Remediation Menu — Công cụ thao tác có xác nhận

Script `scripts/php2shell-remediate.sh` cung cấp menu:

| Mục | Chức năng |
|---|---|
| **1 — Check** | Hiển thị OS, các PHP runtime và trạng thái baseline (read-only). |
| **2 — Upgrade** | Chọn nhánh PHP-FPM đang cài và nâng package từ APT khi ứng viên đáp ứng baseline PHP upstream; có mô phỏng, xác nhận trước khi thay đổi và bước xác nhận restart. |
| **3 — Temporary Mitigation** | Chọn một PHP-FPM pool, sao lưu file cấu hình, áp dụng các thiết lập giảm thiểu tạm thời, kiểm tra cú pháp, xác nhận restart và hỗ trợ rollback. |
| **0 — Exit** | Thoát mà không thay đổi hệ thống. |

**Không ép nâng sai nhánh PHP.** Khi ứng viên APT chỉ thể hiện phiên bản upstream thấp hơn, script dừng để quản trị viên kiểm chứng bản vá backport qua advisory/changelog của nhà cung cấp. Script không tự xây PHP từ mã nguồn, không thay đổi Apache, container hoặc hệ điều hành RPM.

### Mitigations — Khi chưa kịp cập nhật PHP

Tài liệu `docs/08-temporary-mitigations.md` giải thích các biện pháp giảm thiểu theo hai CVE:

- **CVE-2026-109618 (OOM corruption):** xem xét `memory_limit=-1` **chỉ khi đã xác nhận giới hạn tài nguyên bằng container/cgroup**; giới hạn `post_max_size`, `upload_max_filesize` và request tại reverse proxy/web server theo nhu cầu ứng dụng.
- **CVE-2026-109619 (stale global state):** `session.upload_progress.enabled=0`; với **PHP 8.5** có thêm `fatal_error_backtraces=0`; đồng thời rà soát thiết lập deprecated/invalid, fatal error và timeout có thể bị kích hoạt từ ngoài.

**Quan trọng:** Các bước trên chỉ giảm một số đường khai thác đã biết, **không sửa lỗi trong PHP Core**. Đặc biệt, `memory_limit=-1` không an toàn trên môi trường thiếu giới hạn tài nguyên, có thể dẫn tới cạn RAM. Cấu hình giảm thiểu có thể làm thay đổi hoặc gián đoạn chức năng upload. Script không tự tạo cgroup, giới hạn proxy hay kiểm chứng toàn bộ PHP pools.

### Tăng cường kiểm thử và tài liệu

- Bổ sung baseline tests cho phiên bản vá và cú pháp script mới.
- Cập nhật GitHub Actions để chạy kiểm tra tương ứng.
- Thêm tài liệu giải thích rủi ro, phạm vi hỗ trợ, các bước DEV/UAT/PROD và rollback.
- Bổ sung thông tin liên hệ tác giả trong README.

## 2. Phiên bản PHP cần đối chiếu

| Nhánh PHP | Bản vá upstream tối thiểu |
|---|---|
| PHP 8.2 | **8.2.35** |
| PHP 8.3 | **8.3.36** |
| PHP 8.4 | **8.4.27** |
| PHP 8.5 | **8.5.12** |

**Chú ý:** Bản vá được nhà cung cấp hệ điều hành **backport** có thể giữ upstream version thấp hơn. Cần đối chiếu security advisory, package changelog và PHP runtime thực sự phục vụ web. PHP 8.1 trở xuống cần xem xét nâng nhánh hoặc hỗ trợ bảo mật riêng từ nhà cung cấp.

## 3. Cài đặt và sử dụng

```bash
git clone https://github.com/phuongnguyenitpro/php2shell.git
cd php2shell

# Kiểm tra cục bộ — không thay đổi hệ thống
bash scripts/php2shell-check.sh

# Chạy menu tương tác (chỉ khi được phép quản trị máy)
sudo bash scripts/php2shell-remediate.sh
```

**Đối với Production:** kiểm tra code trước khi chạy, backup và thử restore, thực hiện DEV → UAT → PROD có change approval, xác minh PHP-FPM pool đang phục vụ website và smoke test sau cập nhật. Menu nâng package có thể tác động dịch vụ; tính năng sao lưu file pool thuộc **lựa chọn mitigation**, không thay thế backup đầy đủ trước khi nâng package.

## 4. Phạm vi hỗ trợ và giới hạn

- **Có hỗ trợ tự động:** Ubuntu/Debian với APT và PHP-FPM layout thông dụng cho nhánh 8.2–8.5.
- **Cần kiểm tra/thao tác thủ công:** vendor backport, Apache mod_php, các bản PHP custom, Docker/container, RHEL/RPM, multiple vhosts/pools, web-facing SAPI mapping, WAF/reverse-proxy limits.
- **Không có:** mã khai thác RCE, quét Internet, bằng chứng pháp chứng rằng máy chủ an toàn hay chưa bị xâm nhập.
- **Không bảo đảm:** khả năng tương thích mọi website hoặc zero downtime. Cần thử trong môi trường được ủy quyền.

## 5. Tài liệu liên quan

- [README.md](https://github.com/phuongnguyenitpro/php2shell/blob/main/README.md)
- [Hướng dẫn giảm thiểu tạm thời](https://github.com/phuongnguyenitpro/php2shell/blob/main/docs/08-temporary-mitigations.md)
- [Kiểm tra & nghiệm thu](https://github.com/phuongnguyenitpro/php2shell/blob/main/docs/07-verification-checklist.md)
- [Incident Response](https://github.com/phuongnguyenitpro/php2shell/blob/main/docs/06-incident-response.md)
- [PHP2Shell – Upgrade PHP](https://www.php2shell.com/#upgrade-php)
- [PHP Group](https://www.php.net/downloads.php)
- [Ubuntu Security Notices](https://ubuntu.com/security/notices)

## 6. Tác giả & liên hệ

**Phương Nguyễn – PhuongIT**  
**Email:** [phuongit.contact@gmail.com](mailto:phuongit.contact@gmail.com)  
**Facebook:** [facebook.com/jsisen](https://facebook.com/jsisen)  
**LinkedIn:** [linkedin.com/in/phuong-nguyen-van](https://www.linkedin.com/in/phuong-nguyen-van/)

**License:** MIT · **Mục đích:** Phòng vệ, kiểm tra và chia sẻ kiến thức bảo mật.

> **Disclaimer:** Công cụ và tài liệu được cung cấp *as-is*; hãy kiểm chứng advisory mới nhất và tự đánh giá tác động trước khi thay đổi hệ thống. Ưu tiên vá PHP Core bằng bản đã được nhà cung cấp xác nhận. Mitigation chỉ là giải pháp tạm thời.
