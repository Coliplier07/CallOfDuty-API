# COD Stats

A full-stack Call of Duty statistics application.

The project is designed as a monorepo containing:

- **Mobile:** Expo / React Native / TypeScript
- **API:** Node.js / Express / TypeScript
- **Database:** PostgreSQL
- **Infrastructure:** Docker Compose
- **CI:** GitHub Actions

The mobile application will allow a user to enter a Call of Duty username and view available player statistics, match history, and other game information through the API.

## Project Structure

```text
cod-stats/
├── apps/
│   ├── api/                 # REST API
│   │   ├── src/
│   │   ├── tests/
│   │   └── migrations/
│   └── mobile/              # Expo / React Native application
├── docs/                    # Project documentation
├── .github/
│   └── workflows/           # GitHub Actions
├── AI_USAGE.md              # AI-assisted development log
├── .env.example             # Environment variable template
├── .gitignore
├── docker-compose.yml
└── README.md
```

## Development Principles

- TypeScript for application code
- PostgreSQL for persistent data
- REST API between the mobile client and database
- Environment variables for secrets and configuration
- Conventional Commits
- Pull requests for feature work
- Automated CI checks before merging to `main`
- AI-assisted work documented in `AI_USAGE.md`

## Database

The initial PostgreSQL schema is located in `apps/api/migrations`.

Core tables:

- `games` — supported Call of Duty titles
- `platforms` — normalized player platforms
- `players` — player identities
- `player_stats` — aggregate statistics per player and game
- `maps` and `game_modes` — game-specific lookup data
- `matches` — match-level metadata
- `match_players` — each participant's match performance

The schema evolves through numbered SQL migrations. Migration `003_normalize_database.sql` upgrades the original player-centric match design to the normalized structure while preserving existing records. See [Project Check-in 2: Normalization](./docs/check-in-2-normalization.md) for the ER diagram, 1NF-to-3NF walkthrough, functional dependencies, anomalies, and design reflection.

## Getting Started

### Prerequisites

Install:

- Node.js 20+
- npm
- Git
- Docker Desktop
- Expo Go (when mobile development begins)

### Clone

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd cod-stats
```

### Environment

Copy the example environment file:

```bash
cp .env.example .env
```

On Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

### Start PostgreSQL

```bash
docker compose up -d
```

### API

The API will be developed under:

```text
apps/api
```

### Mobile

The Expo application will be developed under:

```text
apps/mobile
```



## AI-Assisted Development

AI assistance is allowed and documented in [`AI_USAGE.md`](./AI_USAGE.md).

The log records:

- Date
- Area of the project
- AI tool used
- Prompt/task
- What was generated or changed
- Human review/testing
- Final decision

AI-generated code must be reviewed and tested before merging.

## Current Status

### Phase 1 — Repository foundation

- [x] Monorepo structure
- [x] README
- [x] AI usage log
- [x] Environment template
- [x] Git ignore rules
- [x] CI pipeline
- [ ] PostgreSQL schema
- [ ] API implementation
- [ ] Expo mobile application

### Phase 2 — API

- [ ] Player lookup
- [ ] Player statistics
- [ ] Match history
- [ ] API validation
- [ ] API tests
- [ ] COD data provider integration

### Phase 3 — Mobile

- [ ] Expo project initialization
- [ ] Navigation
- [ ] Username search
- [ ] Player overview
- [ ] Detailed statistics
- [ ] Match history
- [ ] Loading/error states

### Phase 4 — Deployment

- [ ] Production API hosting
- [ ] Production PostgreSQL
- [ ] Mobile production configuration
- [ ] Monitoring

## License

MIT
