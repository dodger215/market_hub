# Realtime Market Backend API

A production-ready Elixir/Phoenix WebSocket backend API for a realtime market application with chat, AI commands, shops, and live delivery tracking.

## 🚀 Features

- **Realtime Chat System**: WebSocket-based chat rooms with AI command parsing
- **AI Commands**: Natural language commands starting with `@` (e.g., `@createshop`, `@createproduct`)
- **Shop & Product Management**: Create shops, products with SKU management
- **Live Delivery Tracking**: Real-time GPS tracking with WebSocket updates
- **OTP Authentication**: Phone-based authentication with JWT tokens
- **MongoDB Integration**: No Ecto/SQL, direct MongoDB operations
- **Event Broadcasting**: Real-time events for chat and delivery updates
- **Modular Architecture**: Clean separation of concerns

## 📁 Project Structure

```
realtime_market/
├── lib/
│   ├── realtime_market/
│   │   ├── accounts/          # User authentication & management
│   │   ├── shops/            # Shop & product logic
│   │   ├── chat/             # Chat room & message logic
│   │   ├── delivery/         # Delivery tracking & geo calculations
│   │   ├── ai/               # AI command parsing & flow engine
│   │   └── mongo.ex          # MongoDB connection & queries
│   └── realtime_market_web/
│       ├── channels/         # Phoenix WebSocket channels
│       ├── controllers/      # HTTP controllers
│       └── endpoint.ex       # Phoenix endpoint configuration
├── config/                   # Environment configurations
└── mix.exs                   # Dependencies & project config
```

## 🛠️ Tech Stack

- **Elixir 1.14+** with **Phoenix 1.7.2**
- **MongoDB** with `mongodb` driver (no Ecto)
- **Phoenix Channels** for WebSocket communication
- **JWT** for authentication
- **OTP** for phone verification

## 🚀 Quick Start

### Prerequisites

- Elixir 1.14+
- Erlang/OTP 25+
- MongoDB 6+
- Phoenix 1.7.2

### Installation

1. **Clone and setup:**
```bash
git clone <repository>
cd realtime_market
```

2. **Install dependencies:**
```bash
mix deps.get
```

3. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your MongoDB credentials
```

4. **Start MongoDB:**
```bash
# Local MongoDB
docker run -d -p 27017:27017 --name mongodb mongo:6

# Or connect to MongoDB Atlas
# Update MONGO_SEEDS in .env
```

5. **Start the server:**
```bash
# Development
mix phx.server

# Production
MIX_ENV=prod mix phx.server
```

Server runs at `http://localhost:4000`

## 📡 API Endpoints

### Authentication


#### Adding A User
```http
POST /api/auth/register
{
  "username": "testuser1",
  "phone_number": "+12345678901"
}
```

#### Request OTP
```http
POST /api/auth/request-otp
Content-Type: application/json

{
  "phone_number": "+1234567890"
}
```

**Response:**
```json
{
  "success": true,
  "message": "OTP sent"
}
```

#### Verify OTP
```http
POST /api/auth/verify-otp
Content-Type: application/json

{
  "phone_number": "+1234567890",
  "otp": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "token": "jwt.token.here",
  "user": {
    "id": "uuid",
    "username": "john_doe",
    "phone_number": "+1234567890"
  }
}
```

## 🔌 WebSocket Channels

### Connection
Connect to WebSocket endpoint:
```javascript
const socket = new WebSocket("ws://localhost:4000/socket/websocket?token=<JWT_TOKEN>");
```

### Chat Channel

#### Join Chat Room
```javascript
channel = socket.channel("chat:room_<room_id>", {token: "<JWT_TOKEN>"});
channel.join()
  .receive("ok", resp => console.log("Joined chat room"))
  .receive("error", resp => console.log("Failed to join"));
```

**Events:**
- `message`: Send a chat message
- `typing`: Broadcast typing status
- `mark_read`: Mark message as read

**Broadcasts:**
- `new_message`: New chat message
- `user_joined`: User joined room
- `user_left`: User left room
- `user_typing`: User typing status
- `message_read`: Message read receipt

#### Example Usage:
```javascript
// Send message
channel.push("message", {content: "Hello world!"});

// Typing indicator
channel.push("typing", {is_typing: true});

// Listen for messages
channel.on("new_message", payload => {
  console.log("New message:", payload);
});
```

### Delivery Channel

#### Join Delivery Tracking
```javascript
// As authenticated user
channel = socket.channel("delivery:delivery_<delivery_id>", {token: "<JWT_TOKEN>"});

// Or as customer with tracking token
channel = socket.channel("delivery:token_<tracking_token>", {});
```

**Events:**
- `location_update`: Update delivery location (delivery person only)
- `update_status`: Update delivery status
- `get_eta`: Get estimated arrival time

**Broadcasts:**
- `location_updated`: Real-time location update
- `status_changed`: Delivery status change
- `eta_updated`: ETA update

#### Example Usage:
```javascript
// Update location (delivery person)
channel.push("location_update", {
  latitude: 40.7128,
  longitude: -74.0060
});

// Update status
channel.push("update_status", {status: "in_transit"});

// Listen for updates
channel.on("location_updated", payload => {
  console.log("Location:", payload.latitude, payload.longitude);
});

channel.on("status_changed", payload => {
  console.log("Status:", payload.status);
});
```

## 💬 AI Commands in Chat

Send messages starting with `@` to trigger AI commands:

### Available Commands:
- `@createshop` - Start shop creation wizard
- `@createproduct` - Start product creation wizard
- `@setupdelivery` - Setup delivery (coming soon)
- `@help` - Show available commands
- `@status` - Check system status
- `@listproducts` - List your products

### Example Flow:
```
User: @createshop
AI: Let's create a shop! What should we name it?
User: My Awesome Shop
AI: Great name! Where is the shop located?
User: New York
AI: What category is your shop? (e.g., food, clothing, electronics)
User: clothing
AI: ✅ Shop created successfully! ID: shop_12345
```

## 🏪 Shop Management

### Create Shop (via AI Command)
Use `@createshop` in chat or implement via API:

**Schema:**
```json
{
  "shop_name": "string (unique)",
  "location": "string",
  "category": "string",
  "subscription_plan": "string (default: free)"
}
```

### Create Product (via AI Command)
Use `@createproduct` in chat:

**Schema:**
```json
{
  "name": "string",
  "description": "string",
  "price": "decimal",
  "stock_quantity": "integer",
  "media": [
    {
      "media_type": "image|video",
      "tag": "string",
      "url": "string"
    }
  ],
  "variances": [
    {
      "name": "string",
      "options": ["string"]
    }
  ]
}
```

## 🚚 Delivery System

### Delivery Statuses
1. `assigned` - Delivery assigned to driver
2. `in_transit` - Driver picked up and moving
3. `arrived` - Driver arrived at destination
4. `delivered` - Package delivered
5. `cancelled` - Delivery cancelled

### Real-time Tracking Features
- **Live GPS Updates**: WebSocket location streaming
- **ETA Calculation**: Based on speed and distance
- **Geo-fencing**: Automatic status updates (arrived, delivered)
- **Distance Calculation**: Haversine formula for accurate distances
- **Location History**: Store and retrieve location trail

### Delivery Events
- `assigned` - Delivery assigned
- `moving` - Driver on the move
- `nearby` - Driver within 100m
- `delivered` - Delivery completed
- `cancelled` - Delivery cancelled

## 🗄️ Database Schema

### Users
```elixir
%{
  _id: "uuid",
  phone_number: "string (unique)",
  username: "string (unique)",
  created_at: "datetime",
  last_login: "datetime",
  updated_at: "datetime"
}
```

### Shops
```elixir
%{
  _id: "uuid",
  owner_id: "user_id",
  shop_name: "string (unique)",
  location: "string",
  category: "string",
  subscription_plan: "string",
  created_at: "datetime",
  updated_at: "datetime"
}
```

### Products
```elixir
%{
  _id: "uuid",
  sku: "integer (auto-increment per shop)",
  shop_id: "shop_id",
  name: "string",
  description: "string",
  price: "decimal",
  stock_quantity: "integer",
  created_at: "datetime",
  updated_at: "datetime"
}
```

### Chat Rooms
```elixir
%{
  _id: "uuid",
  type: "user_user|user_shop|user_ai",
  participant_ids: ["user_id"],
  created_at: "datetime",
  updated_at: "datetime"
}
```

### Messages
```elixir
%{
  _id: "uuid",
  chat_room_id: "room_id",
  sender_type: "user|ai|system",
  sender_id: "user_id (nullable)",
  content: "text",
  created_at: "datetime"
}
```

### Deliveries
```elixir
%{
  _id: "uuid",
  shop_id: "shop_id",
  customer_id: "user_id",
  delivery_person_id: "delivery_person_id",
  status: "assigned|in_transit|arrived|delivered|cancelled",
  tracking_token: "string (unique)",
  created_at: "datetime",
  delivered_at: "datetime (nullable)",
  updated_at: "datetime"
}
```

### Delivery Locations
```elixir
%{
  _id: "uuid",
  delivery_id: "delivery_id",
  latitude: "decimal",
  longitude: "decimal",
  recorded_at: "datetime"
}
```

## 🔒 Security

### Authentication Flow:
1. User requests OTP with phone number
2. OTP sent via SMS (mock in development)
3. User verifies OTP, receives JWT token
4. Token used for WebSocket and API authentication

### JWT Claims:
```json
{
  "user_id": "uuid",
  "exp": 1700000000,
  "iat": 1699996400
}
```

### Security Features:
- **OTP-based authentication**
- **JWT token expiration (24 hours)**
- **Secure WebSocket authentication**
- **Input validation and sanitization**
- **Rate limiting** (configurable)
- **CORS protection**

## ⚙️ Configuration

### Environment Variables
Create `.env` file:
```env
# MongoDB
MONGO_SEEDS=localhost:27017
MONGO_DATABASE=realtime_market_dev
MONGO_USERNAME=
MONGO_PASSWORD=
MONGO_SSL=false

# Application
PORT=4000
PHX_HOST=localhost
JWT_SECRET=your-secret-key-here

# Features
ENABLE_AI_COMMANDS=true
MESSAGE_RATE_LIMIT=30
```

### Development
```bash
# Start MongoDB
docker run -d -p 27017:27017 --name mongodb mongo:6

# Run server
mix phx.server
```

### Production
```bash
# Set environment variables
export MIX_ENV=prod
export JWT_SECRET=$(openssl rand -base64 48)
export MONGO_SEEDS=cluster0.abcde.mongodb.net:27017

# Run with production settings
mix phx.server
```

## 📊 Monitoring & Logging

### Log Levels
- `:debug` - Development debugging
- `:info` - General information
- `:warn` - Warning messages
- `:error` - Error messages

### Channel Monitoring
Monitor active channels:
```elixir
# List all channel topics
Phoenix.PubSub.list(RealtimeMarket.PubSub, "chat:*")
```

### MongoDB Metrics
```elixir
# Check connection health
Mongo.command(:mongo, %{ping: 1})

# Get collection stats
Mongo.command(:mongo, %{collStats: "users"})
```

## 🧪 Testing

Run tests:
```bash
# Run all tests
mix test

# Run specific tests
mix test test/realtime_market/accounts/user_test.exs

# Test coverage
mix test --cover
```

### Test Structure
- Unit tests for domain logic
- Channel tests for WebSocket functionality
- Integration tests for API endpoints
- MongoDB test helpers

## 🔄 Deployment

### Docker Deployment
```bash
# Build and run
docker-compose up --build

# Production build
docker build -t realtime-market .
docker run -p 4000:4000 --env-file .env.production realtime-market
```

### Manual Deployment
1. Set up MongoDB cluster
2. Configure environment variables
3. Build release:
```bash
MIX_ENV=prod mix release
_build/prod/rel/realtime_market/bin/realtime_market start
```

## 📈 Scaling Considerations

### Horizontal Scaling
- Use Phoenix's distributed PubSub
- Configure MongoDB replica sets
- Implement Redis for session storage
- Use load balancer for multiple nodes

### Performance Optimizations
- MongoDB indexing on frequently queried fields
- Connection pooling for MongoDB
- Message batching for high-frequency updates
- Cache frequently accessed data

## 🔧 Troubleshooting

### Common Issues

1. **WebSocket Connection Failed**
   - Verify JWT token is valid
   - Check CORS settings
   - Ensure Phoenix server is running

2. **MongoDB Connection Issues**
   - Check connection string
   - Verify network connectivity
   - Check authentication credentials

3. **OTP Not Working**
   - Check OTP storage (ETS table)
   - Verify phone number format
   - Check expiration time

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=debug
mix phx.server
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create pull request

### Code Style
- Follow Elixir formatting: `mix format`
- Write descriptive commit messages
- Add tests for new features
- Update documentation

## 📄 License

MIT License - see LICENSE file for details.

## 📞 Support

For issues and questions:
1. Check existing issues
2. Create new issue with detailed description
3. Include relevant logs and configuration

---

**Built using Elixir & Phoenix**