# Realtime Market WebSocket Documentation

## 🔌 WebSocket Connection Guide

### **Connection Setup**

#### **1. JavaScript/Web Client**
```javascript
// Install Phoenix client
// npm install phoenix

import { Socket } from "phoenix"

const socket = new Socket("ws://localhost:4000/socket", {
  params: { token: "your_jwt_token_here" }
})

socket.connect()

// Channels (subscribe after connect)
const chatChannel = socket.channel("chat:room_12345", {})
const feedChannel = socket.channel("feed:user_user123", {})
const deliveryChannel = socket.channel("delivery:delivery_67890", {})
const notificationsChannel = socket.channel("notifications:user123", {})
```

#### **2. Mobile Client (React Native)**
```javascript
import { Socket } from "phoenix-react-native"

const socket = new Socket("ws://your-server.com/socket", {
  params: { token: userToken }
})

socket.connect()
```

#### **3. Testing with wscat (Command Line)**
```bash
# Install wscat
npm install -g wscat

# Connect to WebSocket
wscat -c "ws://localhost:4000/socket/websocket?token=your_jwt_token"

# Subscribe to channel
{"topic":"chat:room_12345","event":"phx_join","payload":{},"ref":"1"}
```

### **Channel Joining & Authentication**

All channels require JWT authentication. The token can be passed:
1. In connection params: `?token=<JWT>`
2. In channel params: `channel.join({token: "<JWT>"})`

## 📡 Channel Specifications

### **Chat Channel: `chat:room_<room_id>`**

#### **Join:**
```javascript
channel.join()
  .receive("ok", resp => console.log("Joined successfully"))
  .receive("error", resp => console.error("Failed to join:", resp))
```

#### **Events to Send:**

| Event | Payload | Description |
|-------|---------|-------------|
| `message` | `{"content": "Hello world"}` | Send chat message |
| `typing` | `{"is_typing": true/false}` | Typing indicator |
| `mark_read` | `{"message_id": "msg_123"}` | Mark message as read |

#### **Events to Receive:**

| Event | Payload | Description |
|-------|---------|-------------|
| `new_message` | `{"id": "...", "sender_type": "...", "content": "...", "created_at": "..."}` | New message |
| `user_joined` | `{"user_id": "...", "username": "...", "timestamp": "..."}` | User joined room |
| `user_left` | `{"user_id": "...", "username": "...", "timestamp": "..."}` | User left room |
| `user_typing` | `{"user_id": "...", "username": "...", "is_typing": true/false}` | User typing status |
| `message_read` | `{"message_id": "...", "user_id": "...", "timestamp": "..."}` | Message read receipt |
| `messages_history` | `{"messages": [...]}` | Previous messages on join |

#### **Example Flow:**
```javascript
// Join chat room
const chatChannel = socket.channel("chat:room_abc123", {})

chatChannel.join()
  .receive("ok", ({messages}) => {
    console.log("Loaded", messages.length, "previous messages")
  })

// Send message
chatChannel.push("message", {
  content: "Hello everyone!"
})

// Listen for new messages
chatChannel.on("new_message", (message) => {
  console.log("New message from", message.sender_type, ":", message.content)
})

// Typing indicator
let typingTimeout
chatChannel.push("typing", {is_typing: true})
setTimeout(() => {
  chatChannel.push("typing", {is_typing: false})
}, 2000)
```

### **Feed Channel: `feed:user_<user_id>`**

Instagram Reels-style product feed with autoplay videos.

#### **Join:**
```javascript
const feedChannel = socket.channel("feed:user_user123", {})
feedChannel.join()
  .receive("ok", ({items}) => {
    console.log("Feed loaded with", items.length, "items")
  })
```

#### **Events to Send:**

| Event | Payload | Description |
|-------|---------|-------------|
| `view_item` | `{"product_id": "prod_123"}` | Record product view |
| `like_item` | `{"product_id": "prod_123"}` | Like a product |
| `share_item` | `{"product_id": "prod_123", "platform": "whatsapp/facebook"}` | Share product |
| `save_item` | `{"product_id": "prod_123"}` | Save to favorites |
| `load_more` | `{"skip": 10}` | Load more feed items |
| `report_item` | `{"product_id": "prod_123", "reason": "spam"}` | Report inappropriate content |

#### **Events to Receive:**

| Event | Payload | Description |
|-------|---------|-------------|
| `feed_loaded` | `{"items": [...], "has_more": true/false}` | Initial feed data |
| `more_feed_items` | `{"items": [...], "has_more": true/false}` | Additional feed items |
| `new_item` | `{"item": {...}}` | New item added to feed |
| `like_update` | `{"product_id": "...", "likes": 42}` | Like count updated |
| `feed_error` | `{"reason": "failed_to_load"}` | Error loading feed |

#### **Example Flow:**
```javascript
// Join feed
const feedChannel = socket.channel("feed:user_user123", {})
feedChannel.join()

// Track viewing
let currentProductId = null
function onProductViewed(productId) {
  if (currentProductId !== productId) {
    currentProductId = productId
    feedChannel.push("view_item", {product_id: productId})
  }
}

// Like a product
function likeProduct(productId) {
  feedChannel.push("like_item", {product_id: productId})
}

// Listen for updates
feedChannel.on("like_update", ({product_id, likes}) => {
  if (currentProductId === product_id) {
    updateLikeCount(likes)
  }
})

// Load more
function loadMore() {
  feedChannel.push("load_more", {skip: 10})
}
```

### **Delivery Channel: `delivery:delivery_<delivery_id>` or `delivery:token_<tracking_token>`**

#### **Join as Different Roles:**
```javascript
// As delivery person or shop owner (requires auth)
const deliveryChannel = socket.channel("delivery:delivery_abc123", {
  token: "jwt_token_here"
})

// As customer (public tracking)
const publicChannel = socket.channel("delivery:token_abc123track", {})
```

#### **Events to Send:**

| Event | Payload | Permissions | Description |
|-------|---------|-------------|-------------|
| `location_update` | `{"latitude": 40.7128, "longitude": -74.0060}` | Delivery person only | Update GPS location |
| `update_status` | `{"status": "in_transit"}` | Shop owner, delivery person, customer | Change delivery status |
| `get_eta` | `{}` | Anyone | Request ETA calculation |

#### **Events to Receive:**

| Event | Payload | Description |
|-------|---------|-------------|
| `delivery_details` | `{"delivery": {...}, "latest_location": {...}, "location_history": [...], "eta_seconds": 300}` | Initial delivery data |
| `location_updated` | `{"latitude": ..., "longitude": ..., "recorded_at": "...", "speed": 45}` | Real-time location update |
| `status_changed` | `{"status": "...", "delivered_at": "...", "updated_at": "..."}` | Status change notification |
| `eta_updated` | `{"eta_seconds": 180}` | Updated ETA calculation |

#### **Example Flow:**
```javascript
// Delivery person tracking
const deliveryChannel = socket.channel("delivery:delivery_abc123", {
  token: deliveryPersonToken
})

deliveryChannel.join()
  .receive("ok", ({delivery, latest_location}) => {
    console.log("Tracking delivery to:", delivery.customer_address)
    if (latest_location) {
      updateMap(latest_location.latitude, latest_location.longitude)
    }
  })

// Update location every 10 seconds
setInterval(() => {
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition((position) => {
      deliveryChannel.push("location_update", {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude
      })
    })
  }
}, 10000)

// Listen for location updates
deliveryChannel.on("location_updated", (location) => {
  updateMarker(location.latitude, location.longitude)
  updateSpeed(location.speed)
})

// Customer tracking view
const trackingChannel = socket.channel("delivery:token_abc123track", {})
trackingChannel.join()
  .receive("ok", ({delivery, eta_seconds}) => {
    displayETA(eta_seconds)
    startTrackingAnimation()
  })

trackingChannel.on("location_updated", (location) => {
  animateDeliveryMarker(location)
})
```

### **Notification Channel: `notifications:user_<user_id>` or `notifications:shop_<shop_id>`**

#### **Join:**
```javascript
const notificationsChannel = socket.channel("notifications:user_user123", {
  token: "jwt_token_here"
})

notificationsChannel.join()
  .receive("ok", ({unread_count}) => {
    updateNotificationBadge(unread_count)
  })
```

#### **Events to Receive:**

| Event | Payload | Description |
|-------|---------|-------------|
| `new_notification` | `{"id": "...", "type": "...", "data": {...}, "created_at": "..."}` | New notification |
| `notification_count` | `{"unread": 5, "total": 42}` | Updated counts |
| `notification_read` | `{"notification_id": "..."}` | Notification marked as read |

#### **Notification Types:**
- `follow` - Someone followed you/shop
- `product_like` - Someone liked your product
- `new_message` - New message in chat room
- `delivery_update` - Delivery status changed
- `order_confirmed` - Order confirmed by shop
- `payment_received` - Payment completed

#### **Example Flow:**
```javascript
const notificationsChannel = socket.channel("notifications:user_user123", {
  token: userToken
})

notificationsChannel.join()

notificationsChannel.on("new_notification", (notification) => {
  switch(notification.type) {
    case "follow":
      showFollowNotification(notification.data.follower_id)
      break
    case "product_like":
      showLikeNotification(notification.data.product_id)
      break
    case "new_message":
      showMessageNotification(notification.data.room_id)
      break
  }
  
  playNotificationSound()
  updateUnreadCount()
})
```

## 🧪 WebSocket Testing Commands

### **1. Manual Testing with cURL**
```bash
# Test WebSocket endpoint
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" \
  -H "Sec-WebSocket-Version: 13" \
  "http://localhost:4000/socket/websocket"
```

### **2. Test Script with Node.js**
```javascript
// test_websocket.js
const WebSocket = require('ws')

const ws = new WebSocket('ws://localhost:4000/socket/websocket?token=test_token')

ws.on('open', () => {
  console.log('Connected')
  
  // Join chat channel
  const joinMsg = JSON.stringify({
    topic: 'chat:room_test123',
    event: 'phx_join',
    payload: {},
    ref: '1'
  })
  ws.send(joinMsg)
})

ws.on('message', (data) => {
  console.log('Received:', data.toString())
})

ws.on('error', (error) => {
  console.error('WebSocket error:', error)
})
```

### **3. Phoenix Client Test**
```elixir
# In IEx console
iex> {:ok, socket} = PhoenixClient.Socket.start_link(
...>   url: "ws://localhost:4000/socket/websocket",
...>   params: %{token: "test_token"}
...> )

iex> {:ok, _ref} = PhoenixClient.Channel.join(
...>   socket, 
...>   "chat:room_test123",
...>   %{}
...> )

iex> PhoenixClient.Channel.push(
...>   socket,
...>   "chat:room_test123",
...>   "message",
...>   %{content: "Test message"}
...> )
```

## 🎮 Complete WebSocket Demo

### **Frontend Implementation Example**

```javascript
class RealtimeMarketClient {
  constructor(token) {
    this.token = token
    this.socket = null
    this.channels = {}
    this.callbacks = {}
  }

  connect() {
    this.socket = new Socket("ws://localhost:4000/socket", {
      params: { token: this.token }
    })
    
    this.socket.connect()
    
    this.socket.onOpen(() => console.log("Connected"))
    this.socket.onError(() => console.error("Connection error"))
    this.socket.onClose(() => console.log("Disconnected"))
  }

  joinChat(roomId, onMessage, onJoin, onLeave) {
    const channel = this.socket.channel(`chat:room_${roomId}`, {})
    
    channel.join()
      .receive("ok", resp => {
        console.log("Joined chat room", roomId)
        if (onJoin) onJoin(resp)
      })
      .receive("error", resp => {
        console.error("Failed to join chat", resp)
      })
    
    channel.on("new_message", onMessage)
    channel.on("user_joined", onJoin)
    channel.on("user_left", onLeave)
    
    this.channels[`chat_${roomId}`] = channel
    return channel
  }

  sendMessage(roomId, content) {
    const channel = this.channels[`chat_${roomId}`]
    if (channel) {
      channel.push("message", { content })
    }
  }

  joinFeed(onNewItem, onLikeUpdate) {
    // Get user ID from JWT token
    const userId = this.getUserIdFromToken()
    const channel = this.socket.channel(`feed:user_${userId}`, {})
    
    channel.join()
      .receive("ok", ({items}) => {
        console.log("Feed loaded with", items.length, "items")
      })
    
    channel.on("new_item", onNewItem)
    channel.on("like_update", onLikeUpdate)
    
    this.channels.feed = channel
    return channel
  }

  likeProduct(productId) {
    if (this.channels.feed) {
      this.channels.feed.push("like_item", { product_id: productId })
    }
  }

  trackDelivery(deliveryId, onLocationUpdate, onStatusChange) {
    const channel = this.socket.channel(`delivery:delivery_${deliveryId}`, {
      token: this.token
    })
    
    channel.join()
      .receive("ok", ({delivery, eta_seconds}) => {
        console.log("Tracking delivery:", delivery.status)
        if (eta_seconds) {
          console.log("ETA:", eta_seconds, "seconds")
        }
      })
    
    channel.on("location_updated", onLocationUpdate)
    channel.on("status_changed", onStatusChange)
    
    this.channels[`delivery_${deliveryId}`] = channel
    return channel
  }

  updateDeliveryLocation(deliveryId, latitude, longitude) {
    const channel = this.channels[`delivery_${deliveryId}`]
    if (channel) {
      channel.push("location_update", { latitude, longitude })
    }
  }

  getUserIdFromToken() {
    // Decode JWT token to get user ID
    const payload = this.token.split('.')[1]
    const decoded = JSON.parse(atob(payload))
    return decoded.user_id
  }

  disconnect() {
    Object.values(this.channels).forEach(channel => {
      channel.leave()
    })
    this.socket.disconnect()
  }
}

// Usage
const client = new RealtimeMarketClient("your_jwt_token")
client.connect()

// Join chat room
client.joinChat(
  "room123",
  (message) => console.log("New message:", message.content),
  (user) => console.log(user.username, "joined"),
  (user) => console.log(user.username, "left")
)

// Join feed
client.joinFeed(
  (item) => console.log("New product:", item.name),
  (update) => console.log("Likes updated:", update)
)

// Track delivery
client.trackDelivery(
  "delivery123",
  (location) => console.log("Location:", location.latitude, location.longitude),
  (status) => console.log("Status changed to:", status.status)
)
```

### **Testing Commands in Browser Console**

```javascript
// After loading the page with Phoenix client

// 1. Connect to socket
const socket = new Socket("ws://localhost:4000/socket", {
  params: { token: localStorage.getItem("jwt_token") }
})
socket.connect()

// 2. Create a test chat room
const testChannel = socket.channel("chat:room_test123", {})
testChannel.join()
  .receive("ok", resp => console.log("Joined test room"))

// 3. Test AI commands
testChannel.push("message", {content: "@help"})
testChannel.push("message", {content: "@createshop"})
testChannel.push("message", {content: "My Test Shop"})
testChannel.push("message", {content: "New York"})
testChannel.push("message", {content: "electronics"})

// 4. Test delivery tracking
const deliveryChannel = socket.channel("delivery:delivery_test456", {
  token: localStorage.getItem("jwt_token")
})
deliveryChannel.join()

// Simulate location updates
let lat = 40.7128, lng = -74.0060
setInterval(() => {
  lat += 0.001
  lng += 0.001
  deliveryChannel.push("location_update", {
    latitude: lat,
    longitude: lng
  })
}, 5000)
```

## 🔧 Debugging WebSocket Issues

### **Common Problems & Solutions**

#### **1. Connection Fails**
```javascript
// Check if token is valid
console.log("Token:", localStorage.getItem("jwt_token"))

// Check WebSocket URL
const socket = new Socket("ws://localhost:4000/socket", {
  params: { token: "test" },
  logger: (kind, msg, data) => { console.log(`${kind}: ${msg}`, data) }
})
```

#### **2. Channel Join Fails**
```javascript
channel.join()
  .receive("ok", resp => console.log("OK:", resp))
  .receive("error", resp => console.error("ERROR:", resp))
  .receive("timeout", () => console.error("TIMEOUT"))
```

#### **3. Messages Not Broadcasting**
- Check if sender has correct permissions
- Verify the channel topic matches exactly
- Check server logs for broadcast errors
- Ensure JWT token hasn't expired

### **Server-Side Debugging**

```elixir
# In your channel modules, add debug logging
def handle_in("message", payload, socket) do
  IO.inspect(payload, label: "Received message")
  # ... rest of function
end

# Monitor active connections
:observer.start()
# Check "Applications" tab for Phoenix.PubSub
```

### **Network Debugging**

```bash
# Check WebSocket handshake
curl -v -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" \
  -H "Sec-WebSocket-Version: 13" \
  http://localhost:4000/socket/websocket

# Monitor WebSocket traffic (Chrome DevTools)
# 1. Open DevTools (F12)
# 2. Go to Network tab
# 3. Filter by "WS" (WebSocket)
# 4. Click on connection and see "Messages" tab
```

## 📊 Monitoring Active Connections

### **Phoenix LiveDashboard**

Access `http://localhost:4000/dashboard` to see:
- Active WebSocket connections
- Channel subscriptions
- Message rates
- Memory usage

### **Custom Monitoring Endpoint**

Add to your router:
```elixir
get "/monitor/connections", MonitorController, :connections
```

Controller:
```elixir
def connections(conn, _params) do
  # Get all active channel topics
  chat_topics = Phoenix.PubSub.list(RealtimeMarket.PubSub, "chat:*")
  delivery_topics = Phoenix.PubSub.list(RealtimeMarket.PubSub, "delivery:*")
  
  json(conn, %{
    active_connections: Phoenix.Channel.Server.count(),
    chat_channels: length(chat_topics),
    delivery_channels: length(delivery_topics),
    chat_topics: Enum.take(chat_topics, 10),
    delivery_topics: Enum.take(delivery_topics, 10)
  })
end
```

## 🎯 Best Practices

1. **Token Management**: Always pass JWT token in connection params
2. **Error Handling**: Handle all receive cases (ok, error, timeout)
3. **Reconnection**: Implement automatic reconnection logic
4. **Rate Limiting**: Throttle high-frequency messages (location updates)
5. **Cleanup**: Leave channels and disconnect socket when not needed
6. **Security**: Validate all incoming messages server-side
7. **Monitoring**: Track connection counts and message rates

This comprehensive WebSocket setup provides real-time capabilities for chat, product feeds, delivery tracking, and notifications with proper authentication and error handling.