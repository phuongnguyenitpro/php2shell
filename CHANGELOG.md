## Unreleased (main) — Interactive Multi-Distro Menu (2026-10-23)

- New `menu` command with 1–6 choices and 0 Exit on the Multi-Distro dispatcher, available automatically for no-arg interactive terminals.
- Safe selection flow: read-only inspection by default; gated remediation requires explicit confirmation. Existing explicit subcommands and noninteractive no-argument `check` remain supported.
- Top-of-README quick start, menu table, supported OS matrix, and test coverage for menu navigation.
- This `main` change **postdates the published `v3.0.0` tag**; tagged source is not rewritten.

## v3.0.0 – Multi-Distro pre-release (2026-10-23)

- New Bash entrypoint: `scripts/php2shell-multidistro.sh` for local inventory and package plan on APT, DNF, APK, Zypper, Pacman families.
- Introduced shared `os-family.sh`, conservative vendor/backport checks and guarded RHEL-family DNF remediation. Ubuntu/Debian helper remains unchanged.
- Added conservative OS version guard (Ubuntu 22.04/24.04/26.04, Debian 12/13 for APT remediation), 18 OS tests, CI and operational docs. **Pre-release:** DNF remediation is not production-certified; publish only after CI success on main.

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
