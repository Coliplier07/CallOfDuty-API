import "dotenv/config";
import express, { type Request, type Response } from "express";
import { pool } from "./db/client.js";

const app = express();
const port = Number(process.env.API_PORT ?? 3000);

app.use(express.json());

app.get("/health", async (_request: Request, response: Response) => {
  try {
    await pool.query("SELECT 1");
    response.json({
      status: "ok",
      database: "connected",
    });
  } catch {
    response.status(503).json({
      status: "error",
      database: "disconnected",
    });
  }
});

app.get("/api/games", async (_request: Request, response: Response) => {
  const result = await pool.query(`
    SELECT id, slug, name, release_year
    FROM games
    ORDER BY release_year DESC NULLS LAST, name ASC
  `);

  response.json(result.rows);
});

app.get("/api/players/:username", async (request: Request, response: Response) => {
  const rawUsername = request.params.username;

  const username = Array.isArray(rawUsername)
    ? rawUsername[0]?.trim()
    : rawUsername?.trim();

  if (!username) {
    response.status(400).json({
      error: "Username is required.",
    });
    return;
  }

  const result = await pool.query(
    `
      SELECT
        p.id,
        p.username,
        pl.code AS platform,
        ps.game_id,
        g.slug AS game_slug,
        g.name AS game_name,
        ps.kills,
        ps.deaths,
        ps.assists,
        ps.wins,
        ps.losses,
        ps.games_played,
        ps.score
      FROM players p
      LEFT JOIN platforms pl ON pl.id = p.platform_id
      LEFT JOIN player_stats ps ON ps.player_id = p.id
      LEFT JOIN games g ON g.id = ps.game_id
      WHERE p.normalized_username = LOWER($1)
      ORDER BY g.release_year DESC NULLS LAST, g.name ASC
    `,
    [username],
  );

  if (result.rows.length === 0) {
    response.status(404).json({
      error: "Player not found.",
    });
    return;
  }

  const firstRow = result.rows[0];

  response.json({
    id: firstRow.id,
    username: firstRow.username,
    platform: firstRow.platform,
    stats: result.rows
      .filter((row) => row.game_id !== null)
      .map((row) => ({
        gameId: row.game_id,
        gameSlug: row.game_slug,
        gameName: row.game_name,
        kills: row.kills,
        deaths: row.deaths,
        assists: row.assists,
        wins: row.wins,
        losses: row.losses,
        gamesPlayed: row.games_played,
        score: row.score,
      })),
  });
});

app.use((_request: Request, response: Response) => {
  response.status(404).json({
    error: "Route not found.",
  });
});

app.listen(port, () => {
  console.log(`COD Stats API listening on http://localhost:${port}`);
});
