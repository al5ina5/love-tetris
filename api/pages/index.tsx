export default function Home() {
  return (
    <div style={{ padding: '2rem', fontFamily: 'system-ui' }}>
      <h1>Love Tetris API</h1>
      <p>API is running. Available endpoints:</p>
      <ul>
        <li><code>POST /api/create-room</code> - Create a game room</li>
        <li><code>POST /api/join-room</code> - Join an existing room</li>
        <li><code>GET /api/list-rooms</code> - List public rooms</li>
        <li><code>POST /api/heartbeat</code> - Keep room alive</li>
      </ul>
      <h2>Status: ✅ Online</h2>
    </div>
  )
}
