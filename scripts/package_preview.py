"""Add reproducible provenance to CI preview bundles; never a release attestation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

MANIFEST = 'preview-manifest.json'
README = 'PREVIEW_README.md'


def validate_provenance(source, checkout, run_url, attempt):
    if not all(re.fullmatch(r'[0-9a-f]{40}', sha) for sha in (source, checkout)):
        raise ValueError('Invalid commit identity')
    if not re.fullmatch(r'https://github\.com/[\w.-]+/[\w.-]+/actions/runs/[1-9][0-9]*', run_url):
        raise ValueError('Invalid CI run URL')
    if type(attempt) is not int or attempt < 1:
        raise ValueError('Invalid CI attempt')


def inventory(root):
    if root.is_symlink() or not root.is_dir():
        raise ValueError('Preview directory unavailable')
    records = []
    for path in sorted(root.rglob('*'), key=lambda p: p.relative_to(root).as_posix()):
        relative = path.relative_to(root)
        # Matches upload-artifact's default exclusion of hidden files/directories.
        if any(part.startswith('.') for part in relative.parts):
            continue
        if path.is_symlink():
            raise ValueError('Preview symlinks are not supported')
        if path.is_file() and relative.as_posix() != MANIFEST:
            digest = hashlib.sha256()
            with path.open('rb') as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(chunk)
            records.append({'path': relative.as_posix(), 'size': path.stat().st_size,
                            'sha256': digest.hexdigest()})
    return records


def verify(root):
    # Enumerate actual files; never open caller-controlled manifest paths.
    records = inventory(root)
    manifest = json.loads((root / MANIFEST).read_text(encoding='utf-8'))
    if (manifest.get('format_version') != 1 or manifest.get('preview_only') is not True
            or manifest.get('platform') not in ('web', 'windows')):
        raise ValueError('Invalid preview manifest')
    validate_provenance(manifest['source_head_sha'], manifest['checkout_sha'],
                        manifest['ci_run_url'], manifest['run_attempt'])
    if manifest['files'] != records:
        raise ValueError('Preview file inventory mismatch')
    return manifest


def package(root, platform, source, checkout, run_url, attempt):
    validate_provenance(source, checkout, run_url, attempt)
    entrypoint = {'web': 'index.html', 'windows': 'nihongo_daily.exe'}.get(platform)
    records = inventory(root)
    if entrypoint is None or entrypoint not in {item['path'] for item in records}:
        raise ValueError('Preview entrypoint unavailable')
    if (root / MANIFEST).exists() or (root / README).exists():
        raise ValueError('Preview already packaged')
    instruction = (
        'Giải nén toàn bộ gói; mở nihongo_daily.exe cùng các DLL và thư mục data. '
        'Đây là bản Windows x64 chưa ký, không phải bộ cài.'
        if platform == 'windows' else
        'Giải nén toàn bộ gói và phục vụ thư mục bằng HTTP, ví dụ: '
        'python -m http.server 8080. Mở http://localhost:8080; không mở index.html bằng file://.'
    )
    (root / README).write_text(
        '# Nihongo Daily — bản preview\n\n' + instruction + '\n\n'
        'Mặc định là preview chưa cấu hình. Auth/save/AI không được giả lập thành công. '
        'Đây không phải Personal Alpha đã nghiệm thu hay bản production.\n\n'
        f'Source head: {source}\n\nCheckout thực tế (có thể là PR merge commit): {checkout}\n\n'
        f'CI: {run_url}, attempt {attempt}. Artifact tồn tại không chứng minh toàn bộ CI đã đạt.\n\n'
        'preview-manifest.json liệt kê SHA256 của các file hiển thị trong gói, gồm tài liệu này. '
        'Checksum kiểm tra toàn vẹn, không phải chữ ký hay bằng chứng hosted learner.\n',
        encoding='utf-8',
    )
    manifest = {'format_version': 1, 'preview_only': True, 'platform': platform,
                'source_head_sha': source, 'checkout_sha': checkout,
                'ci_run_url': run_url, 'run_attempt': attempt, 'files': inventory(root)}
    (root / MANIFEST).write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n',
                               encoding='utf-8')
    return verify(root)


def verify_ci(root, platform, source, checkout, run_url, attempt):
    validate_provenance(source, checkout, run_url, attempt)
    if platform not in ('web', 'windows'):
        raise ValueError('Invalid expected platform')
    manifest = verify(root)
    expected = {'platform': platform, 'source_head_sha': source,
                'checkout_sha': checkout, 'ci_run_url': run_url, 'run_attempt': attempt}
    if any(manifest[key] != value for key, value in expected.items()):
        raise ValueError('Preview provenance mismatch')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--platform', choices=['web', 'windows'])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--verify', action='store_true')
    mode.add_argument('--verify-ci', action='store_true')
    args = parser.parse_args()
    if args.verify:
        result = verify(args.root)
    else:
        checkout = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
        operation = verify_ci if args.verify_ci else package
        result = operation(args.root, args.platform, os.environ['ND_PREVIEW_SOURCE_SHA'], checkout,
                           f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
                           int(os.environ['GITHUB_RUN_ATTEMPT']))
    print(f"Verified {result['platform']} preview inventory: {len(result['files'])} files")


if __name__ == '__main__':
    main()
