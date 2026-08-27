## 1. Documentation Service

- [x] 1.1 Create `lib/services/docs_service.dart` with SKILLS file loader
- [x] 1.2 Implement `loadSkills(String skillsDir)` that reads all `*/SKILL.md` files and caches name, description, content
- [x] 1.3 Extract frontmatter metadata (name, description) from each SKILL.md
- [x] 1.4 Add `getSkillsIndex()` method returning list of `{name, description, path}`
- [x] 1.5 Add `getSkillContent(String name)` method returning full markdown content
- [x] 1.6 Add `getApiSchema()` method that introspects the router and returns route definitions as JSON

## 2. API Routes

- [x] 2.1 Register `GET /api/docs` route in `RemoteAccessService.start()`
- [x] 2.2 Register `GET /api/docs/<skill>` route
- [x] 2.3 Register `GET /api/docs/api-schema` route
- [x] 2.4 Implement `_handleDocsIndex` handler — returns skills list JSON
- [x] 2.5 Implement `_handleDocsSkill` handler — returns individual skill content
- [x] 2.6 Implement `_handleDocsSchema` handler — returns API schema JSON
- [x] 2.7 Add 404 handling for non-existent skill names

## 3. Provider Integration

- [x] 3.1 Add `DocsService` constructor parameter to `RemoteAccessService`
- [x] 3.2 Instantiate `DocsService` in `RemoteAccessProvider` with path to SKILLS/
- [x] 3.3 Pass `DocsService` to `RemoteAccessService` constructor

## 4. Testing

- [x] 4.1 Test `GET /api/docs` returns correct skill count and metadata
- [x] 4.2 Test `GET /api/docs/radiokit-firmware` returns full markdown content
- [x] 4.3 Test `GET /api/docs/nonexistent` returns 404
- [x] 4.4 Test `GET /api/docs/api-schema` returns valid route definitions
