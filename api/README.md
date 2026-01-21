# Love Tetris API

TypeScript serverless API for online multiplayer.

## Local Development

```bash
npm install
npm run dev
```

This starts Vercel dev server at `http://localhost:3000`

## Endpoints

- `POST /api/create-room` - Create a new game room
- `POST /api/join-room` - Join an existing room
- `GET /api/list-rooms` - List public rooms
- `POST /api/heartbeat` - Keep room alive

## Deployment

See main project README for full deployment instructions.

Quick deploy:
```bash
vercel --prod
```
