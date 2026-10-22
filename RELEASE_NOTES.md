# PHP2Shell Community Guide v1.0.0

Bản tài liệu cộng đồng PHUONGIT về PHP2Shell (CVE-2026-109618, CVE-2026-109619).

**Nội dung:** Phân tích tác động, bảng PHP upstream security releases, quy trình DEV/UAT/PROD, script kiểm kê và xác minh chỉ đọc, hardening WordPress/Laravel và Incident Response.

**An toàn:** Không chứa exploit, không quét từ xa, không tự cập nhật package. Mặc định runtime dưới phiên bản upstream được đánh dấu WARN vì nhà cung cấp hệ điều hành có thể đã backport bản vá. Luôn xác minh live PHP SAPI và package advisory trước khi kết luận.

Nguồn: https://www.php.net/downloads.php · https://ubuntu.com/security/notices · https://www.php2shell.com/#upgrade-php
