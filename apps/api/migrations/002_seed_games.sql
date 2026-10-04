```sql
BEGIN;

INSERT INTO games (slug, name, release_year)
VALUES
    ('black-ops-6', 'Call of Duty: Black Ops 6', 2024),
    ('black-ops-7', 'Call of Duty: Black Ops 7', 2025)
ON CONFLICT (slug) DO NOTHING;

COMMIT;
```
