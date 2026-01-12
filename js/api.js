// 1. Definite Base URL
const API_BASE_URL = 'https://sparkadate-1n.onrender.com/api';

/**
 * Utility to manage the JWT token in LocalStorage
 */
const TokenManager = {
    get: () => localStorage.getItem('sparkToken'),
    set: (token) => localStorage.getItem('sparkToken', token),
    remove: () => localStorage.removeItem('sparkToken')
};

/**
 * The Core Request Handler
 * Standardizes headers and URL construction for all API calls.
 */
async function apiRequest(endpoint, options = {}) {
    const token = TokenManager.get();
    
    // Slash-Guard: Ensure endpoint starts with / and BASE_URL doesn't end with one
    const cleanEndpoint = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
    const url = `${API_BASE_URL}${cleanEndpoint}`;

    const config = {
        headers: {
            'Content-Type': 'application/json',
            ...(token && { 'Authorization': `Bearer ${token}` })
        },
        ...options
    };

    console.log(`🚀 Requesting: ${config.method || 'GET'} ${url}`);

    try {
        const response = await fetch(url, config);
        
        // Handle potential empty responses
        const contentType = response.headers.get("content-type");
        let data = null;
        if (contentType && contentType.includes("application/json")) {
            data = await response.json();
        }

        if (!response.ok) {
            console.error(`❌ Server returned ${response.status}:`, data);
            throw new Error(data?.error || `Request failed with status: ${response.status}`);
        }

        return data;
    } catch (error) {
        console.error('API Connection Error:', error);
        throw error;
    }
}

/**
 * SparkAPI Object
 * Exposed to the window so your HTML scripts can call SparkAPI.auth.signup()
 */
window.SparkAPI = {
    auth: {
        async signup(userData) {
            const data = await apiRequest('/auth/signup', {
                method: 'POST',
                body: JSON.stringify(userData)
            });
            if (data?.token) {
                localStorage.setItem('sparkToken', data.token);
                localStorage.setItem('sparkUser', JSON.stringify(data.user));
            }
            return data;
        },

        async login(email, password) {
            const data = await apiRequest('/auth/login', {
                method: 'POST',
                body: JSON.stringify({ email, password })
            });
            if (data?.token) {
                localStorage.setItem('sparkToken', data.token);
                localStorage.setItem('sparkUser', JSON.stringify(data.user));
            }
            return data;
        },

        logout() {
            localStorage.clear(); // Clears token and user data
            window.location.href = 'index.html';
        },

        isLoggedIn() {
            return !!localStorage.getItem('sparkToken');
        }
    },

    users: {
        async getProfile() {
            return apiRequest('/users/me');
        },

        async uploadPhoto(base64Data, index) {
            // Helper to convert base64 to Blob for multipart upload
            const response = await fetch(base64Data);
            const blob = await response.blob();

            const formData = new FormData();
            formData.append('photo', blob, `photo_${index}.jpg`);
            formData.append('is_primary', index === 0);
            formData.append('upload_order', index);

            const token = localStorage.getItem('sparkToken');
            
            // Manual fetch for FormData (apiRequest is optimized for JSON)
            const res = await fetch(`${API_BASE_URL}/users/me/photos/upload`, {
                method: 'POST',
                headers: {
                    ...(token && { 'Authorization': `Bearer ${token}` })
                },
                body: formData
            });

            if (!res.ok) throw new Error('Photo upload failed');
            return res.json();
        }
    },

    matches: {
        async getCurrent() { return apiRequest('/matches/current'); },
        async findNew() { return apiRequest('/matches/find', { method: 'POST' }); },
        async exit(matchId) { return apiRequest(`/matches/${matchId}/exit`, { method: 'POST' }); }
    },

    messages: {
        async getAll(matchId) { return apiRequest(`/messages/${matchId}`); },
        async send(matchId, content) {
            return apiRequest(`/messages/${matchId}`, {
                method: 'POST',
                body: JSON.stringify({ content })
            });
        }
    }
};
