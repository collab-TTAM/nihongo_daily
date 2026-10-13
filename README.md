# Nihongo Daily – Tiếng Nhật Mỗi Ngày

> Personal-first Japanese learning app for JLPT N5 + N4, designed for a 120-minute daily study routine and parallel development across multiple ChatGPT workstreams.

See `docs/` for product, architecture, security and automation contracts.

The Flutter UI preview is in `apps/flutter_app`; see its README for running on
web/Windows, routes, tests and explicit integration limitations. This is a demo
shell; real study, auth, sync and AI remain tracked in GitHub issues.

Frozen models/API are in `contracts/v0.1/`; see `docs/CONTRACT_BASELINE.md` for decisions/dependencies and `docs/PROJECT_STATUS.md` for the handoff.

Contract checks:
```bash
python3 -m pip install -r contracts/requirements.txt
python3 contracts/validate.py
python3 -m unittest discover -s contracts -p 'test_*.py' -v
```

Database migrations and reproducible role/RLS tests are in `supabase/`;
see `supabase/README.md`. No live Supabase integration is claimed.

The pure versioned SRS core and backend parity handoff are documented in
`docs/SRS_ALGORITHM.md`; authoritative review persistence is still #22.

Original N5 seed exports are in `data/`; see `data/README.md` for exact coverage,
linguistic notes and unavailable assets. Validate with
`python3 -m contracts.validate_content`. This seed is not a complete curriculum.

Provider-neutral server AI interfaces and receipt-claim helpers are in `backend/ai`;
see `docs/AI_BOUNDARY.md` for tests, limits and unconfigured integration boundaries.
