// Shared TypeScript types for the API

export interface Room {
  code: string;
  hostName: string;
  isPublic: boolean;
  players: number;
  maxPlayers: number;
  createdAt: number;
  lastHeartbeat: number;
  channelName: string;
}

export interface CreateRoomRequest {
  playerName?: string;
  isPublic?: boolean;
}

export interface CreateRoomResponse {
  roomCode: string;
  channelName: string;
  ablyToken: string;
}

export interface JoinRoomRequest {
  roomCode: string;
  playerName?: string;
}

export interface JoinRoomResponse {
  channelName: string;
  ablyToken: string;
  hostName: string;
}

export interface ListRoomsResponse {
  rooms: Array<{
    roomCode: string;
    hostName: string;
    players: number;
    maxPlayers: number;
  }>;
}

export interface HeartbeatRequest {
  roomCode: string;
}

export interface HeartbeatResponse {
  success: boolean;
}

export interface ErrorResponse {
  error: string;
}
