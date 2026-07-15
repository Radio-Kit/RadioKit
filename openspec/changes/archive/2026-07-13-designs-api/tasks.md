## 1. API Routes

- [x] 1.1 Register `GET /api/designs/<id>/json` route
- [x] 1.2 Register `GET /api/designs/<id>/header` route
- [x] 1.3 Implement `_handleDesignJson` handler — returns design JSON by ID
- [x] 1.4 Implement `_handleDesignHeader` handler — generates .h file using JsonArduinoGenerator
- [x] 1.5 Add 404 handling for nonexistent design IDs
- [x] 1.6 Add 400 handling for designs with null jsonContent

## 2. Documentation

- [x] 2.1 Update `llms.txt` with design endpoint docs
- [x] 2.2 Update `GET /api/docs/api-schema` to include new endpoints

## 3. Testing

- [x] 3.1 Test `GET /api/designs/<id>/json` returns valid JSON
- [x] 3.2 Test `GET /api/designs/<id>/header` returns RADIOKIT.h content
- [x] 3.3 Test 404 for nonexistent design
