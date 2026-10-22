# Đóng góp

Chào mừng pull request cải tiến tài liệu, link advisory, kiểm thử và script đọc thông tin cục bộ.

- Mỗi khẳng định về CVE/bản vá phải có nguồn PHP Group hoặc nhà cung cấp OS.
- Không thêm PoC khai thác, webshell, mã thực thi từ xa, host/domain/IP thực tế hoặc dữ liệu định danh.
- Không đưa các thao tác thay đổi PROD vào script audit/verify.
- Kiểm tra: `bash -n scripts/*.sh scripts/lib/*.sh tests/*.sh` và `bash tests/run-tests.sh`.
- Mô tả giả định, giới hạn, tác động và cách rollback rõ ràng trong pull request.
