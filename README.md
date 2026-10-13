# Nihongo Daily – Tiếng Nhật Mỗi Ngày

> Personal-first Japanese learning app for JLPT N5 + N4, designed for a 120-minute daily study routine and parallel development across multiple ChatGPT workstreams.

See `docs/` for product, architecture, security and automation contracts.

Frozen models/API are in `contracts/v0.1/`; see `docs/CONTRACT_BASELINE.md` for decisions/dependencies and `docs/PROJECT_STATUS.md` for the handoff.

Contract checks:
```bash
python3 -m pip install -r contracts/requirements.txt
python3 contracts/validate.py
python3 -m unittest discover -s contracts -p 'test_*.py' -v
```
