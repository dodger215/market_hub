class FeedPlayer {
  constructor(containerId, options = {}) {
    this.container = document.getElementById(containerId);
    this.items = [];
    this.currentIndex = 0;
    this.isPlaying = false;
    this.autoplay = options.autoplay || true;
    this.loop = options.loop || false;
    this.volume = options.volume || 0.7;
    
    this.socket = null;
    this.userId = options.userId;
    this.token = options.token;
    
    this.initialize();
  }
  
  initialize() {
    // Create player structure
    this.container.innerHTML = `
      <div class="feed-container">
        <div class="feed-item active">
          <div class="media-container">
            <video class="media-video" playsinline webkit-playsinline></video>
            <img class="media-image" style="display: none;">
            <audio class="media-audio"></audio>
          </div>
          <div class="overlay-ui">
            <div class="left-controls">
              <div class="shop-info">
                <img class="shop-avatar">
                <span class="shop-name"></span>
                <button class="follow-btn">Follow</button>
              </div>
              <div class="product-info">
                <h3 class="product-name"></h3>
                <p class="product-price"></p>
                <p class="product-description"></p>
              </div>
            </div>
            <div class="right-controls">
              <button class="like-btn">
                <i class="heart-icon"></i>
                <span class="like-count">0</span>
              </button>
              <button class="comment-btn">
                <i class="comment-icon"></i>
              </button>
              <button class="share-btn">
                <i class="share-icon"></i>
              </button>
              <button class="save-btn">
                <i class="save-icon"></i>
              </button>
              <button class="sound-btn">
                <i class="sound-icon"></i>
              </button>
            </div>
            <div class="progress-bar">
              <div class="progress-fill"></div>
            </div>
          </div>
          <div class="swipe-hint">↑ Swipe for next</div>
        </div>
      </div>
      <div class="navigation">
        <button class="nav-btn prev-btn">◀</button>
        <button class="nav-btn next-btn">▶</button>
      </div>
    `;
    
    this.setupElements();
    this.setupEventListeners();
    this.connectWebSocket();
    this.loadInitialFeed();
  }
  
  setupElements() {
    this.video = this.container.querySelector('.media-video');
    this.image = this.container.querySelector('.media-image');
    this.audio = this.container.querySelector('.media-audio');
    this.progressFill = this.container.querySelector('.progress-fill');
    this.likeBtn = this.container.querySelector('.like-btn');
    this.likeCount = this.container.querySelector('.like-count');
    this.soundBtn = this.container.querySelector('.sound-btn');
    this.nextBtn = this.container.querySelector('.next-btn');
    this.prevBtn = this.container.querySelector('.prev-btn');
  }
  
  setupEventListeners() {
    // Video events
    this.video.addEventListener('timeupdate', () => this.updateProgress());
    this.video.addEventListener('ended', () => this.nextItem());
    
    // Touch/swipe events
    let startY = 0;
    this.container.addEventListener('touchstart', (e) => {
      startY = e.touches[0].clientY;
    });
    
    this.container.addEventListener('touchend', (e) => {
      const endY = e.changedTouches[0].clientY;
      const diff = startY - endY;
      
      if (Math.abs(diff) > 50) {
        if (diff > 0) this.nextItem(); // Swipe up
        else this.prevItem(); // Swipe down
      }
    });
    
    // Keyboard events
    document.addEventListener('keydown', (e) => {
      switch(e.key) {
        case 'ArrowUp': this.nextItem(); break;
        case 'ArrowDown': this.prevItem(); break;
        case ' ': this.togglePlay(); break;
        case 'm': this.toggleMute(); break;
        case 'l': this.likeCurrent(); break;
      }
    });
    
    // Button events
    this.likeBtn.addEventListener('click', () => this.likeCurrent());
    this.soundBtn.addEventListener('click', () => this.toggleMute());
    this.nextBtn.addEventListener('click', () => this.nextItem());
    this.prevBtn.addEventListener('click', () => this.prevItem());
  }
  
  connectWebSocket() {
    this.socket = new Phoenix.Socket("/socket", {
      params: {token: this.token}
    });
    
    this.socket.connect();
    
    this.channel = this.socket.channel(`feed:user_${this.userId}`, {});
    
    this.channel.join()
      .receive("ok", resp => console.log("Joined feed channel"))
      .receive("error", resp => console.error("Failed to join", resp));
    
    this.channel.on("new_item", payload => {
      this.addItem(payload.item);
    });
    
    this.channel.on("like_update", payload => {
      this.updateLikes(payload.product_id, payload.likes);
    });
  }
  
  async loadInitialFeed() {
    try {
      const response = await fetch(`/api/feed?limit=10`, {
        headers: {'Authorization': `Bearer ${this.token}`}
      });
      
      const data = await response.json();
      this.items = data.items;
      
      if (this.items.length > 0) {
        this.loadItem(0);
        this.recordView(this.items[0]._id);
      }
    } catch (error) {
      console.error('Failed to load feed:', error);
    }
  }
  
  loadItem(index) {
    if (index < 0 || index >= this.items.length) return;
    
    this.currentIndex = index;
    const item = this.items[index];
    
    // Update UI
    this.container.querySelector('.shop-name').textContent = item.shop?.name || 'Shop';
    this.container.querySelector('.product-name').textContent = item.name;
    this.container.querySelector('.product-price').textContent = `$${item.price}`;
    this.container.querySelector('.product-description').textContent = item.description;
    this.likeCount.textContent = item.likes || 0;
    
    // Load media
    if (item.type === 'video') {
      const videoMedia = item.media.find(m => m.image.media_type === 'video');
      if (videoMedia) {
        this.video.src = videoMedia.image.url;
        this.video.style.display = 'block';
        this.image.style.display = 'none';
        
        if (item.audio) {
          this.audio.src = item.audio.url;
          this.audio.currentTime = this.video.currentTime;
        }
        
        if (this.autoplay) {
          this.video.play().catch(e => console.log('Autoplay prevented:', e));
          this.audio.play().catch(e => console.log('Audio autoplay prevented:', e));
          this.isPlaying = true;
        }
      }
    } else {
      const imageMedia = item.media[0];
      if (imageMedia) {
        this.image.src = imageMedia.image.url;
        this.image.style.display = 'block';
        this.video.style.display = 'none';
        this.video.pause();
        this.audio.pause();
      }
    }
    
    // Record view
    this.recordView(item._id);
  }
  
  nextItem() {
    if (this.currentIndex < this.items.length - 1) {
      this.loadItem(this.currentIndex + 1);
    } else if (this.loop) {
      this.loadItem(0);
    }
  }
  
  prevItem() {
    if (this.currentIndex > 0) {
      this.loadItem(this.currentIndex - 1);
    } else if (this.loop) {
      this.loadItem(this.items.length - 1);
    }
  }
  
  togglePlay() {
    if (this.items[this.currentIndex]?.type === 'video') {
      if (this.video.paused) {
        this.video.play();
        this.audio.play();
        this.isPlaying = true;
      } else {
        this.video.pause();
        this.audio.pause();
        this.isPlaying = false;
      }
    }
  }
  
  toggleMute() {
    this.video.muted = !this.video.muted;
    this.audio.muted = !this.audio.muted;
    this.soundBtn.classList.toggle('muted');
  }
  
  likeCurrent() {
    const item = this.items[this.currentIndex];
    if (item) {
      this.channel.push("like_item", {product_id: item._id});
      
      // Update UI immediately
      const currentLikes = parseInt(this.likeCount.textContent);
      this.likeCount.textContent = currentLikes + 1;
      this.likeBtn.classList.add('liked');
      
      // Reset animation after 1s
      setTimeout(() => {
        this.likeBtn.classList.remove('liked');
      }, 1000);
    }
  }
  
  updateProgress() {
    if (this.video.duration) {
      const percent = (this.video.currentTime / this.video.duration) * 100;
      this.progressFill.style.width = `${percent}%`;
    }
  }
  
  recordView(productId) {
    this.channel.push("view_item", {product_id: productId});
  }
  
  addItem(item) {
    this.items.push(item);
  }
  
  updateLikes(productId, likes) {
    if (this.items[this.currentIndex]?._id === productId) {
      this.likeCount.textContent = likes;
    }
  }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  const player = new FeedPlayer('feed-player', {
    userId: window.userId,
    token: window.userToken,
    autoplay: true,
    loop: true
  });
});