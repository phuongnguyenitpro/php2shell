## v2.0.0 development – Multi-Distro (2026-10-22)

- New Bash entrypoint: `scripts/php2shell-multidistro.sh` for local inventory and package plan on APT, DNF, APK, Zypper, Pacman families.
- Introduced shared `os-family.sh`, conservative vendor/backport checks and guarded RHEL-family DNF remediation. Ubuntu/Debian helper remains unchanged.
- New OS-detection tests, CI job and operational documentation. **Experimental: no RHEL/Alma/Rocky PROD remediation has been integration-tested; do not release as stable until distro matrix passes.**

# Changelog

## v2.0.0 — 2026-10-22

- Nâng định vị sản phẩm từ Community Security Guide lên Community Security Toolkit.
- Đưa vào README/Release Notes quy trình kiểm tra cục bộ và menu nâng cấp hoặc mitigation có xác nhận (đã có trong mã nguồn v1.1.0).
- Diễn giải đầy đủ các mục menu, hạn chế khi kiểm tra vendor backport, phạm vi Ubuntu/Debian PHP-FPM, cảnh báo rủi ro RAM/upload và giới hạn xác minh.
- Bổ sung thông tin tác giả và liên hệ theo bản README mới nhất.
- Không tuyên bố hỗ trợ cập nhật tự động trên Apache/RPM/container hoặc xác nhận không bị xâm nhập.

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
