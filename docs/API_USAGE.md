# API Usage Examples

## Testing the API with curl

### Create a Room

```bash
curl -X POST https://your-url.vercel.app/api/create-room \
  -H "Content-Type: application/json" \
  -d '{
    "playerName": "Alice",
    "isPublic": true
  }'
```

Response:
```json
{
  "roomCode": "ABC123",
  "channelName": "tetris:room:ABC123",
  "ablyToken": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

### Join a Room

```bash
curl -X POST https://your-url.vercel.app/api/join-room \
  -H "Content-Type: application/json" \
  -d '{
    "roomCode": "ABC123",
    "playerName": "Bob"
  }'
```

Response:
```json
{
  "channelName": "tetris:room:ABC123",
  "ablyToken": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "hostName": "Alice"
}
```

### List Public Rooms

```bash
curl https://your-url.vercel.app/api/list-rooms
```

Response:
```json
{
  "rooms": [
    {
      "roomCode": "ABC123",
      "hostName": "Alice",
      "players": 1,
      "maxPlayers": 2
    },
    {
      "roomCode": "XYZ789",
      "hostName": "Charlie",
      "players": 1,
      "maxPlayers": 2
    }
  ]
}
```

### Send Heartbeat

```bash
curl -X POST https://your-url.vercel.app/api/heartbeat \
  -H "Content-Type: application/json" \
  -d '{
    "roomCode": "ABC123"
  }'
```

Response:
```json
{
  "success": true
}
```

## Error Responses

### Room Not Found (404)

```json
{
  "error": "Room not found"
}
```

### Room Full (400)

```json
{
  "error": "Room is full"
}
```

### Missing Player Name (400)

```json
{
  "error": "Player name is required"
}
```

### Server Error (500)

```json
{
  "error": "Internal server error"
}
```

## Using with Ably REST API

Once you have an `ablyToken` from create-room or join-room:

### Publish a Message

```bash
curl -X POST https://rest.ably.io/channels/tetris:room:ABC123/messages \
  -H "Authorization: Bearer YOUR_ABLY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "game_message",
    "data": "move|host|I|5|10|0"
  }'
```

### Get Message History

```bash
curl https://rest.ably.io/channels/tetris:room:ABC123/messages?limit=10 \
  -H "Authorization: Bearer YOUR_ABLY_TOKEN"
```

Response:
```json
{
  "items": [
    {
      "id": "...",
      "name": "game_message",
      "data": "move|host|I|5|10|0",
      "timestamp": 1705512000000
    }
  ]
}
```

## Rate Limits

- **Ably Free Tier**: 3M messages/month, 200 concurrent connections
- **Vercel Free Tier**: 100K function invocations/month
- **Vercel KV Free Tier**: 30K requests/month

## Room Lifecycle

1. **Creation**: Host calls `/api/create-room` → Gets room code
2. **Discovery**: Public rooms appear in `/api/list-rooms`
3. **Joining**: Client calls `/api/join-room` with room code
4. **Heartbeat**: Host sends `/api/heartbeat` every 30 seconds
5. **Expiry**: Rooms without heartbeat for 60s are removed from listing
6. **TTL**: Rooms automatically deleted after 1 hour (Vercel KV TTL)

## Message Protocol

The game uses a pipe-delimited protocol over Ably:

```
message_type|player_id|...args
```

Examples:
- `join|host` - Player joined
- `move|client|I|5|10|0` - Piece moved (type, x, y, rotation)
- `board|host|1122334455...` - Full board state sync
- `score|client|1250` - Score update
- `garb|host|4` - Send 4 garbage lines
- `over|client` - Game over

These messages are automatically encoded/decoded by `src/net/protocol.lua` and sent via `OnlineClient:publish()`.
