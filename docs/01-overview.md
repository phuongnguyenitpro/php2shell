# 01 — Tổng quan PHP2Shell

PHP2Shell là tên chung cho CVE-2026-109618 và CVE-2026-109619, hai lỗ hổng quản lý bộ nhớ PHP Core được công bố 21/10/2026. Trong một số điều kiện khai thác, lỗi có thể dẫn đến Remote Code Execution (RCE) không cần xác thực hoặc truy cập dữ liệu trong bộ nhớ worker.

## Cơ chế

- **CVE-2026-109618:** xử lý Out-of-Memory và cleanup request không nhất quán có nguy cơ dẫn tới memory corruption.
- **CVE-2026-109619:** trạng thái toàn cục còn lưu tham chiếu đến vùng nhớ đã giải phóng, liên quan đến Use-After-Free.

## Phạm vi

Lỗi thuộc PHP runtime; WordPress, Laravel hay CMS khác không phải nguyên nhân gốc. Phải xác định runtime thật sự phục vụ HTTP (FPM, CGI, Apache module, container). Phiên bản CLI riêng lẻ không đủ.

## Tác động có thể xảy ra

Thực thi mã trong quyền PHP worker, thay đổi nội dung trang, đánh cắp dữ liệu cấu hình, webshell, gián đoạn dịch vụ, lan sang hệ thống khác nếu phân quyền/mạng cho phép. Không suy luận mọi máy chủ có CVE đã bị chiếm quyền.

## Ưu tiên

Internet-facing services → hệ thống nhạy cảm → ứng dụng nội bộ. Ưu tiên vá bản chính thức; WAF/hardening chỉ giảm rủi ro tạm thời.

Nguồn: [PHP Group](https://www.php.net/downloads.php) · [PHP2Shell](https://www.php2shell.com/#upgrade-php).
