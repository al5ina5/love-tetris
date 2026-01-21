// POST /api/create-room
// Creates a new game room and returns room code + Ably token
import type { NextApiRequest, NextApiResponse } from 'next';
import { createRoom } from '../../lib/rooms';
import { generateAblyToken, generateChannelName } from '../../lib/ably';
import type { CreateRoomRequest, CreateRoomResponse, ErrorResponse } from '../../lib/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { playerName = 'Host', isPublic = false } = req.body as CreateRoomRequest;

    // Validate input (optional now, use default if not provided)
    const finalPlayerName = playerName && playerName.trim().length > 0 ? playerName.trim() : 'Host';

    if (finalPlayerName.length > 20) {
      return res.status(400).json({ error: 'Player name too long (max 20 chars)' });
    }

    // Create room
    const channelName = generateChannelName('temp'); // Generate temp, will replace
    const room = await createRoom(finalPlayerName, isPublic, channelName);
    
    // Update channel name with actual room code
    room.channelName = generateChannelName(room.code);
    
    // Generate Ably token for the host
    const ablyToken = await generateAblyToken(room.channelName, 'host');

    return res.status(200).json({
      roomCode: room.code,
      channelName: room.channelName,
      ablyToken,
    });
  } catch (error) {
    console.error('Error creating room:', error);
    return res.status(500).json({ 
      error: error instanceof Error ? error.message : 'Internal server error' 
    });
  }
}
