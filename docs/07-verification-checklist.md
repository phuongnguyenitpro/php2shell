# 07 — Checklist xác minh DEV / UAT / PROD

## DEV

- [ ] Đã xác định bản PHP upstream/vendor sẽ triển khai.
- [ ] Gói PHP sửa đủ CVE-2026-109618 và CVE-2026-109619 theo advisory.
- [ ] Kiểm tra extension, Composer và tương thích framework.
- [ ] Tất cả ứng dụng và job dùng runtime dự kiến.

## UAT

- [ ] Test HTTP, API, login, upload, DB, cache, media, scheduler, queues.
- [ ] Kiểm tra startup và error logs; không có regression nghiêm trọng.
- [ ] Backup restore/rollback được thử nghiệm.

## PROD

- [ ] Change approval và backup hợp lệ.
- [ ] Package origin, phiên bản, advisory, changelog xác nhận security fix.
- [ ] Restart/recycle đúng PHP-FPM/Apache/worker; không còn process binary cũ.
- [ ] Xác nhận ánh xạ Nginx vhost → FPM socket/pool của runtime đã vá.
- [ ] Smoke test và monitoring sau cập nhật đạt.
- [ ] Phân tích indicator of compromise theo mức độ phơi nhiễm.
- [ ] Biên bản kết thúc và rollback point lưu an toàn.

### Nhãn kết luận

**PASS:** đủ bằng chứng runtime đang phục vụ request đã vá và chức năng hoạt động. **WARN:** thiếu bằng chứng về backport/SAPI/restart. **FAIL:** xác định chưa vá hoặc kiểm thử chức năng quan trọng thất bại. Kết quả script chỉ là đầu vào, không tự chứng nhận an toàn hệ thống.
