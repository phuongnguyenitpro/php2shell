# Changelog

## v1.1.0 — 2026-10-22

- Bổ sung mitigation tạm thời cho hai CVE, nêu rõ giới hạn và nguy cơ hết RAM.
- Thêm `php2shell-check.sh` kiểm kê cục bộ read-only và `php2shell-remediate.sh` với menu tương tác có sao lưu/xác nhận.
- Nâng cấp APT theo đúng nhánh PHP; cảnh báo về vendor backport và không tự quyết định gói chưa kiểm chứng.
- Thêm baseline checks và CI validation cho script mới.

## v1.0.0 — 2026-10-22

- Bổ sung README Community Security Guide cho CVE-2026-109618 và CVE-2026-109619.
- Tài liệu phiên bản, triển khai Ubuntu/Debian, WordPress, Laravel, Incident Response và Verification.
- Script local read-only audit và verify với nhận biết khả năng vendor backport.
- CI kiểm tra cú pháp Bash và version baseline tests.

**Lưu ý:** PASS theo version baseline không phải xác nhận hết dấu hiệu bị xâm nhập.
