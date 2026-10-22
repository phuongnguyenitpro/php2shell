# 04 — WordPress và PHP2Shell

**Lỗi thuộc PHP engine, không phải riêng WordPress.** Cập nhật WordPress core, theme hay plugin không thay thế được PHP security patch.

1. Kiểm tra PHP thực tế phục vụ WordPress trên panel, PHP-FPM pool, container image và cấu hình vhost.
2. Sao lưu database, `wp-content`, cấu hình và xác nhận restore.
3. Nâng PHP từ bản chính thức có vá hoặc package backport đã xác nhận, kiểm thử theme/plugin trên DEV/UAT.
4. Xác nhận site, admin login, upload, cache, cron, mail và plugin quan trọng chạy bình thường.
5. Hardening: nguyên tắc least privilege, file permission chặt, hạn chế sửa file trong Dashboard khi phù hợp, bật WAF/monitoring, loại bỏ plugin không dùng, bật backup độc lập.
6. Nếu nghi xâm nhập: bảo toàn log/chứng cứ, tìm file PHP bất thường, rà soát user quản trị và credentials, phục hồi từ bản sạch; chỉ cập nhật PHP là chưa đủ.

Không đưa `wp-config.php` hay secret thật lên GitHub.
