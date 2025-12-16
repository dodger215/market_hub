// Simple Phoenix WebSocket protocol client using the native WebSocket API.
// This lets you manually test channels without bundlers or npm.

const WS_URL = "ws://localhost:4000/socket/websocket";

let socket = null;
let refCounter = 1;

const channels = {
  // topic => {joined: boolean}
};

function nextRef() {
  return (refCounter++).toString();
}

function log(...args) {
  const el = document.getElementById("log");
  const line = `[${new Date().toISOString()}] ${args.join(" ")}`;
  el.textContent += line + "\n";
  el.scrollTop = el.scrollHeight;
}

function setSocketStatus(status) {
  const el = document.getElementById("socket-status");
  el.textContent = status;
}

function encodeMsg(topic, event, payload) {
  return JSON.stringify({
    topic,
    event,
    payload,
    ref: nextRef(),
  });
}

function connectSocket() {
  const token = document.getElementById("token-input").value.trim();
  if (!token) {
    alert("Please paste a JWT token first.");
    return;
  }

  if (socket && socket.readyState === WebSocket.OPEN) {
    log("Socket already connected");
    return;
  }

  const url = `${WS_URL}?token=${encodeURIComponent(token)}`;
  log("Connecting to", url);
  socket = new WebSocket(url);

  socket.onopen = () => {
    setSocketStatus("connected");
    log("Socket opened");
    // Enable buttons
    document.getElementById("disconnect-btn").disabled = false;
    document.getElementById("connect-btn").disabled = true;
    document.getElementById("chat-join-btn").disabled = false;
    document.getElementById("feed-join-btn").disabled = false;
    document.getElementById("delivery-join-btn").disabled = false;
  };

  socket.onclose = (ev) => {
    setSocketStatus("disconnected");
    log("Socket closed", `code=${ev.code}`, `reason=${ev.reason || ""}`);
    document.getElementById("disconnect-btn").disabled = true;
    document.getElementById("connect-btn").disabled = false;
    document.getElementById("chat-join-btn").disabled = true;
    document.getElementById("chat-send-btn").disabled = true;
    document.getElementById("feed-join-btn").disabled = true;
    document.getElementById("feed-view-btn").disabled = true;
    document.getElementById("feed-like-btn").disabled = true;
    document.getElementById("feed-save-btn").disabled = true;
    document.getElementById("delivery-join-btn").disabled = true;
    document.getElementById("delivery-location-btn").disabled = true;
  };

  socket.onerror = (err) => {
    log("Socket error", String(err));
  };

  socket.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      log("RECV", msg.topic, msg.event, JSON.stringify(msg.payload));
    } catch (e) {
      log("RECV raw", ev.data);
    }
  };
}

function disconnectSocket() {
  if (socket) {
    log("Closing socket");
    socket.close();
  }
}

function send(topic, event, payload) {
  if (!socket || socket.readyState !== WebSocket.OPEN) {
    alert("Socket is not connected");
    return;
  }
  const frame = encodeMsg(topic, event, payload);
  log("SEND", topic, event, JSON.stringify(payload));
  socket.send(frame);
}

// --- Chat helpers ---------------------------------------------------------

function joinChat() {
  const roomId = document.getElementById("chat-room-id").value.trim();
  if (!roomId) {
    alert("Enter a room ID");
    return;
  }
  const topic = `chat:room_${roomId}`;
  channels[topic] = { joined: true };
  send(topic, "phx_join", {});
  document.getElementById("chat-send-btn").disabled = false;
  document.getElementById("chat-leave-btn").disabled = false;
}

function leaveChat() {
  const roomId = document.getElementById("chat-room-id").value.trim();
  if (!roomId) return;
  const topic = `chat:room_${roomId}`;
  if (!channels[topic]) return;
  send(topic, "phx_leave", {});
  delete channels[topic];
  document.getElementById("chat-send-btn").disabled = true;
  document.getElementById("chat-leave-btn").disabled = true;
}

function sendChatMessage() {
  const roomId = document.getElementById("chat-room-id").value.trim();
  const content = document.getElementById("chat-message").value.trim();
  if (!roomId || !content) {
    alert("Room ID and message are required");
    return;
  }
  const topic = `chat:room_${roomId}`;
  send(topic, "message", { content });
}

// --- Feed helpers ---------------------------------------------------------

function joinFeed() {
  const userId = document.getElementById("feed-user-id").value.trim();
  if (!userId) {
    alert("Enter a user ID");
    return;
  }
  const topic = `feed:user_${userId}`;
  channels[topic] = { joined: true };
  send(topic, "phx_join", {});
  document.getElementById("feed-view-btn").disabled = false;
  document.getElementById("feed-like-btn").disabled = false;
  document.getElementById("feed-save-btn").disabled = false;
  document.getElementById("feed-leave-btn").disabled = false;
}

function leaveFeed() {
  const userId = document.getElementById("feed-user-id").value.trim();
  if (!userId) return;
  const topic = `feed:user_${userId}`;
  if (!channels[topic]) return;
  send(topic, "phx_leave", {});
  delete channels[topic];
  document.getElementById("feed-view-btn").disabled = true;
  document.getElementById("feed-like-btn").disabled = true;
  document.getElementById("feed-save-btn").disabled = true;
  document.getElementById("feed-leave-btn").disabled = true;
}

function feedAction(kind) {
  const userId = document.getElementById("feed-user-id").value.trim();
  const productId = document.getElementById("feed-product-id").value.trim();
  if (!userId || !productId) {
    alert("User ID and product ID are required");
    return;
  }
  const topic = `feed:user_${userId}`;
  const eventMap = {
    view: "view_item",
    like: "like_item",
    save: "save_item",
  };
  const event = eventMap[kind];
  if (!event) return;
  send(topic, event, { product_id: productId });
}

// --- Delivery helpers -----------------------------------------------------

function joinDelivery() {
  const id = document.getElementById("delivery-id").value.trim();
  if (!id) {
    alert("Enter a delivery ID");
    return;
  }
  const topic = `delivery:delivery_${id}`;
  channels[topic] = { joined: true };
  send(topic, "phx_join", {});
  document.getElementById("delivery-location-btn").disabled = false;
  document.getElementById("delivery-leave-btn").disabled = false;
}

function leaveDelivery() {
  const id = document.getElementById("delivery-id").value.trim();
  if (!id) return;
  const topic = `delivery:delivery_${id}`;
  if (!channels[topic]) return;
  send(topic, "phx_leave", {});
  delete channels[topic];
  document.getElementById("delivery-location-btn").disabled = true;
  document.getElementById("delivery-leave-btn").disabled = true;
}

function sendDeliveryLocation() {
  const id = document.getElementById("delivery-id").value.trim();
  const latStr = document.getElementById("delivery-lat").value.trim();
  const lngStr = document.getElementById("delivery-lng").value.trim();
  if (!id || !latStr || !lngStr) {
    alert("Delivery ID, latitude and longitude are required");
    return;
  }
  const topic = `delivery:delivery_${id}`;
  const latitude = parseFloat(latStr);
  const longitude = parseFloat(lngStr);
  if (Number.isNaN(latitude) || Number.isNaN(longitude)) {
    alert("Latitude and longitude must be numbers");
    return;
  }
  send(topic, "location_update", { latitude, longitude });
}

// --- Wire up DOM events ---------------------------------------------------

window.addEventListener("DOMContentLoaded", () => {
  document.getElementById("connect-btn").addEventListener("click", connectSocket);
  document.getElementById("disconnect-btn").addEventListener("click", disconnectSocket);

  document.getElementById("chat-join-btn").addEventListener("click", joinChat);
  document.getElementById("chat-leave-btn").addEventListener("click", leaveChat);
  document.getElementById("chat-send-btn").addEventListener("click", sendChatMessage);

  document.getElementById("feed-join-btn").addEventListener("click", joinFeed);
  document.getElementById("feed-leave-btn").addEventListener("click", leaveFeed);
  document.getElementById("feed-view-btn").addEventListener("click", () => feedAction("view"));
  document.getElementById("feed-like-btn").addEventListener("click", () => feedAction("like"));
  document.getElementById("feed-save-btn").addEventListener("click", () => feedAction("save"));

  document.getElementById("delivery-join-btn").addEventListener("click", joinDelivery);
  document.getElementById("delivery-leave-btn").addEventListener("click", leaveDelivery);
  document.getElementById("delivery-location-btn").addEventListener("click", sendDeliveryLocation);

  log("Manual client loaded. Paste a JWT token and click Connect.");
});


