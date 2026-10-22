# 05 — Laravel và PHP2Shell

**PHP2Shell là lỗi PHP Core.** Khắc phục bằng runtime có security fix, không chỉ `composer update` hay nâng Laravel.

- Kiểm tra PHP CLI, PHP-FPM phục vụ Nginx/Apache, Supervisor queue workers, scheduler/cron và container runtime riêng.
- Xác minh `composer check-platform-reqs` trên runtime mục tiêu và extension tương thích.
- Backup source/DB/storage/config; không xuất bản `.env` hay `APP_KEY`.
- Triển khai DEV/UAT, kiểm tra routing, API, auth, session, DB transaction, uploads, worker/job và các tác vụ tích hợp.
- PROD: cập nhật package có CVE fix, restart PHP-FPM, queue workers đúng quy trình; `php artisan optimize:clear` chỉ khi phù hợp kế hoạch thay đổi.
- Xác minh `APP_DEBUG=false`, không lộ stack trace, HTTP/DB/storage/logs hoạt động bình thường.

Nếu nghi xâm nhập, điều tra thay đổi source, jobs, webroot, file upload và tokens; chuẩn bị khôi phục sạch và rotate credentials theo quy trình sự cố.
