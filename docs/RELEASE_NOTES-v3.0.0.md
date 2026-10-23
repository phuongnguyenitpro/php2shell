# PHP2Shell v3.0.0 – Multi-Distro Security Toolkit (Pre-release)

**23/10/2026 · PHUONGIT · MIT License**

## Tính năng mới
- Entry point đa nền tảng: `bash scripts/php2shell-multidistro.sh {check|audit|verify|plan|remediate}`.
- Phát hiện OS: Ubuntu, Debian, RHEL, Rocky, AlmaLinux, CentOS Stream, Oracle Linux, Fedora, Amazon Linux, Alpine, SUSE, Arch.
- Kiểm kê local PHP packages, một số PHP-FPM services và pool paths thông dụng.
- Patch plan qua APT candidate hoặc DNF updateinfo theo hai CVE PHP2Shell.
- APT: tái sử dụng helper có xác nhận hiện hữu. DNF4: remediation thử nghiệm, bắt buộc vendor advisory + xác nhận; không tự restart.
- OS gate EOL/không nằm trong scope → audit-only. 18 test cases nhận diện distro và Bash CI.

## Hướng dẫn nhanh
```bash
git clone --branch v3.0.0 https://github.com/phuongnguyenitpro/php2shell.git
cd php2shell
bash scripts/php2shell-multidistro.sh check
bash scripts/php2shell-multidistro.sh plan
bash scripts/php2shell-multidistro.sh verify
```

**Cảnh báo:** Pre-release **chưa nghiệm thu tính năng DNF/ATP thay đổi packages trên VM thật**. Không chạy `remediate` trên Production khi chưa backup, DEV/UAT, change approval, rollback và maintenance window.

## Giới hạn
- Version baseline không chứng minh runtime web-facing đã vá hoặc vendor backport đã được áp dụng.
- Không tự switch PHP streams/repos, không hỗ trợ nâng cấp PHP custom/container/Remi parallel/SCL/CloudLinux/EasyApache.
- DNF update có thể thay đổi hệ thống sau khi được xác nhận; PHP-FPM worker restart và smoke test phải xử lý có kiểm soát.
- Nếu nghi compromise, bắt buộc Incident Response riêng; vá PHP không loại bỏ webshell.
- Build được kiểm tra bởi GitHub Actions Bash syntax + baseline tests + OS detection; chưa có full distro VM integration matrix.

Chi tiết: [Hỗ trợ đa nền tảng](09-multi-distro.md) · [Verification Checklist](07-verification-checklist.md) · [Incident Response](06-incident-response.md).
