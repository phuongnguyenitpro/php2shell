# 06 — Incident Response khi nghi PHP2Shell bị khai thác

> Không có dấu hiệu bất thường không có nghĩa đã an toàn; có CVE cũng không đồng nghĩa đã bị khai thác. Chỉ tiến hành trên hệ thống có quyền quản trị.

## 1. Triage

- Xác định PHP SAPI/pool, bản vá, thời gian phơi nhiễm, mức độ public exposure.
- Lưu timeline từ web access logs, WAF, Nginx/Apache, PHP-FPM, ứng dụng, EDR/SIEM.
- Tìm HTTP 5xx/crashes bất thường, child process lạ, kết nối outbound bất thường, file webroot mới/sửa không rõ lý do, tài khoản ứng dụng mới.

## 2. Containment

Hạn chế truy cập qua reverse proxy/WAF, cô lập instance có dấu hiệu nguy hiểm, giữ nguyên chứng cứ. Không xóa file đáng ngờ trước khi tạo image/backup pháp chứng theo quy trình.

## 3. Investigation

Rà soát checksum mã nguồn, plugins, PHP upload directory, cron/systemd, scheduled jobs và quyền ghi PHP worker. Kiểm tra credentials/tokens có nguy cơ bị đọc. Đánh giá phạm vi xâm nhập và rò rỉ dữ liệu dựa trên bằng chứng.

## 4. Eradication và recovery

Vá PHP, khôi phục từ image/source sạch nếu bị compromise, rotate credentials bị ảnh hưởng, tăng phân đoạn mạng/least privilege. Nghiệm thu chức năng và giám sát sau phục hồi.

## 5. Lessons learned

Lưu báo cáo timeline, root cause, blast radius, control gap và corrective actions. Không đăng log, IP hoặc thông tin định danh khách hàng lên issue công khai.
