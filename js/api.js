/**
 * Spark API Configuration
 * Change this to http://localhost:3000/api for local testing
 * or your ngrok URL for mobile/external testing.
 */
const API_BASE_URL = 'https://sparkadate-production.up.railway.app/api';

// --- Token Management Helpers ---

function getToken() {
    return localStorage.getItem('sparkToken');
}

function setToken(token) {
    localStorage.setItem('sparkToken', token);
}

function removeToken() {
    localStorage.removeItem('sparkToken');
}

// --- Core Request Engine ---

async function apiRequest(endpoint, options = {}) {
    const token = getToken();

    const config = {
        headers: {
            'Content-Type': 'application/json',
            // Required to bypass the ngrok warning page during testing
            'ngrok-skip-browser-warning': 'true', 
            ...(token && { 'Authorization': `Bearer ${token}` })
        },
        ...options
    };

    try {
        const response = await fetch(`${API_BASE_URL}${endpoint}`, config);
        
        // 1. Check if the response actually has JSON content to parse
        const contentType = response.headers.get("content-type");
        let data = null;
        
        if (contentType && contentType.includes("application/json")) {
            data = await response.json();
        }

        // 2. Handle HTTP errors (400s, 500s)
        if (!response.ok) {
            // If the server didn't send a JSON error message, use the status text
            throw new Error(data?.error || `Request failed with status: ${response.status}`);
        }

        return data;
    } catch (error) {
        console.error('API Error:', error);
        throw error;
    }
}

// --- API Service Modules ---

const auth = {
    async signup(userData) {
        const data = await apiRequest('/auth/signup', {
            method: 'POST',
            body: JSON.stringify(userData)
        });
        if (data?.token) setToken(data.token);
        if (data?.user) localStorage.setItem('sparkUser', JSON.stringify(data.user));
        return data;
    },

    async login(email, password) {
        const data = await apiRequest('/auth/login', {
            method: 'POST',
            body: JSON.stringify({ email, password })
        });
        if (data?.token) setToken(data.token);
        if (data?.user) localStorage.setItem('sparkUser', JSON.stringify(data.user));
        return data;
    },

    logout() {
        removeToken();
        localStorage.removeItem('sparkUser');
        localStorage.removeItem('sparkUserData');
        localStorage.removeItem('sparkCurrentMatch');
        window.location.href = 'index.html';
    },

    isLoggedIn() {
        return !!getToken();
    },

    getCurrentUser() {
        const user = localStorage.getItem('sparkUser');
        return user ? JSON.parse(user) : null;
    }
};

const users = {
    async getProfile() {
        return apiRequest('/users/me');
    },

    async updateProfile(updates) {
        return apiRequest('/users/me', {
            method: 'PATCH',
            body: JSON.stringify(updates)
        });
    },

    async updatePreferences(preferences) {
        return apiRequest('/users/me/preferences', {
            method: 'PATCH',
            body: JSON.stringify(preferences)
        });
    },

    async addPhoto(photoUrl, isPrimary = false) {
        return apiRequest('/users/me/photos', {
            method: 'POST',
            body: JSON.stringify({ photo_url: photoUrl, is_primary: isPrimary })
        });
    },

    async uploadPhoto(base64Data, index) {
        const response = await fetch(base64Data);
        const blob = await response.blob();

        const formData = new FormData();
        formData.append('photo', blob, `photo_${index}.jpg`);
        formData.append('is_primary', index === 0);
        formData.append('upload_order', index);

        const token = getToken();
        // Note: FormData requests don't need 'Content-Type': 'application/json'
        const res = await fetch(`${API_BASE_URL}/users/me/photos/upload`, {
            method: 'POST',
            headers: {
                ...(token && { 'Authorization': `Bearer ${token}` })
            },
            body: formData
        });

        if (!res.ok) {
            const errorData = await res.json();
            throw new Error(errorData.error || 'Photo upload failed');
        }

        return res.json();
    },

    async deletePhoto(photoId) {
        return apiRequest(`/users/me/photos/${photoId}`, {
            method: 'DELETE'
        });
    }
};

const matches = {
    async getCurrent() {
        return apiRequest('/matches/current');
    },

    async findNew() {
        return apiRequest('/matches/find', { method: 'POST' });
    },

    async requestReveal(matchId) {
        return apiRequest(`/matches/${matchId}/reveal`, { method: 'POST' });
    },

    async markRevealSeen(matchId) {
        return apiRequest(`/matches/${matchId}/seen`, { method: 'POST' });
    },

    async exit(matchId) {
        return apiRequest(`/matches/${matchId}/exit`, { method: 'POST' });
    },

    async getMatchPhotos(matchId) {
        return apiRequest(`/matches/${matchId}/photos`);
    }
};

const messages = {
    async getAll(matchId) {
        return apiRequest(`/messages/${matchId}`);
    },

    async send(matchId, content) {
        return apiRequest(`/messages/${matchId}`, {
            method: 'POST',
            body: JSON.stringify({ content })
        });
    },

    async analyzeConversation(matchId) {
        return apiRequest(`/messages/${matchId}/analyze`, { method: 'POST' });
    }
};

// --- Export for use in other scripts ---
const SparkAPI = {
    auth,
    users,
    matches,
    messages
};
