## 1. Documentation & Skill Updates

- [x] 1.1 Update `SKILLS/radiokit-firmware/SKILL.md` and `radiokit-app/assets/skills/radiokit-firmware.md` with the mandatory flash erase rule (`-erase` / `eraseAll: true`) and NVS persistence rationale.
- [x] 1.2 Update `SKILLS/radiokit-ota/SKILL.md` and `radiokit-app/assets/skills/radiokit-ota.md` to mandate `eraseAll: true` during development uploads.
- [x] 1.3 Update `SKILLS/radiokit-remote/SKILL.md` and `radiokit-app/assets/skills/radiokit-remote.md` to specify calling `/api/flasher/erase-all` or passing `eraseAll: true` when uploading firmware via flasher API.
- [x] 1.4 Update `.agents/skills/radiokit-example/SKILL.md` to include PlatformIO `--erase` flag requirements for upload.
- [x] 1.5 Update `AGENTS.md` codebase guidelines with the flash erase policy for AI coding agents.

## 2. Verification

- [x] 2.1 Verify markdown formatting across updated skills and ensure `openspec validate` passes.
