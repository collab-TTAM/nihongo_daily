# Work / Codex setup — one ChatGPT account

Use the same GitHub repository for separate tasks:
1. Lead / Integration
2. Flutter
3. Backend
4. Learning/SRS
5. Content
6. Kanji
7. AI
8. QA

Start with Lead, Flutter, Backend, Learning and Content. Add Kanji, AI and QA after the baseline contracts/build are stable.

For each task in Work/Codex:
- select repository `collab-TTAM/nihongo_daily`
- read README and docs before coding
- use matching prompt in `prompts/auto/`
- work on branches and open PRs into main
- do not paste GitHub passwords, Supabase service-role keys, AI provider keys or Apple credentials into chat

A normal chat is not a persistent daemon; unattended development requires an actual Work/Codex task or external automation configured in the product UI.
