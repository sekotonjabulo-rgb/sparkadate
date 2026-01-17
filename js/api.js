const API_BASE_URL = 'https://sparkadate-1n.onrender.com/api';

function getToken() {
    return localStorage.getItem('sparkToken');
}

function setToken(token) {
    localStorage.setItem('sparkToken', token);
}

function removeToken() {
    localStorage.removeItem('sparkToken');
}

// Check token expiration and refresh if needed
async function checkAndRefreshToken() {
    const token = getToken();
    if (!token) return false;

    try {
        // Decode JWT to check expiration (without verifying signature)
        const payload = JSON.parse(atob(token.split('.')[1]));
        const expiresAt = payload.exp * 1000; // Convert to milliseconds
        const now = Date.now();
        const daysUntilExpiry = (expiresAt - now) / (1000 * 60 * 60 * 24);

        // Refresh if less than 7 days until expiry
        if (daysUntilExpiry < 7 && daysUntilExpiry > 0) {
            try {
                const response = await fetch(`${API_BASE_URL}/auth/refresh`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${token}`
                    }
                });

                if (response.ok) {
                    const data = await response.json();
                    setToken(data.token);
                    localStorage.setItem('sparkUser', JSON.stringify(data.user));
                    return true;
                }
            } catch (refreshError) {
                console.error('Token refresh failed:', refreshError);
            }
        }

        // Token is still valid
        if (expiresAt > now) {
            return true;
        }

        // Token expired, try to refresh anyway
        try {
            const response = await fetch(`${API_BASE_URL}/auth/refresh`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                }
            });

            if (response.ok) {
                const data = await response.json();
                setToken(data.token);
                localStorage.setItem('sparkUser', JSON.stringify(data.user));
                return true;
            }
        } catch (refreshError) {
            console.error('Token refresh failed:', refreshError);
        }

        return false;
    } catch (error) {
        console.error('Token check error:', error);
        return false;
    }
}

async function apiRequest(endpoint, options = {}) {
    const token = getToken();

    const config = {
        headers: {
            'Content-Type': 'application/json',
            ...(token && { 'Authorization': `Bearer ${token}` })
        },
        ...options
    };

    try {
        const response = await fetch(`${API_BASE_URL}${endpoint}`, config);
        const data = await response.json();

        // If unauthorized, try to refresh token
        if (response.status === 401 && token) {
            const refreshed = await checkAndRefreshToken();
            if (refreshed) {
                // Retry the request with new token
                config.headers['Authorization'] = `Bearer ${getToken()}`;
                const retryResponse = await fetch(`${API_BASE_URL}${endpoint}`, config);
                const retryData = await retryResponse.json();
                if (!retryResponse.ok) {
                    throw new Error(retryData.error || 'Request failed');
                }
                return retryData;
            }
        }

        if (!response.ok) {
            throw new Error(data.error || 'Request failed');
        }

        return data;
    } catch (error) {
        console.error('API Error:', error);
        throw error;
    }
}

const auth = {
    async signup(userData) {
        const data = await apiRequest('/auth/signup', {
            method: 'POST',
            body: JSON.stringify(userData)
        });
        setToken(data.token);
        localStorage.setItem('sparkUser', JSON.stringify(data.user));
        return data;
    },

    async login(email, password) {
        const data = await apiRequest('/auth/login', {
            method: 'POST',
            body: JSON.stringify({ email, password })
        });
        setToken(data.token);
        localStorage.setItem('sparkUser', JSON.stringify(data.user));
        return data;
    },

    logout() {
        removeToken();
        localStorage.removeItem('sparkUser');
        localStorage.removeItem('sparkUserData');
        localStorage.removeItem('sparkCurrentMatch');
        localStorage.removeItem('sparkLastPage');
        localStorage.removeItem('sparkLastPageTime');
        window.location.href = 'index.html';
    },

    isLoggedIn() {
        const token = getToken();
        if (!token) return false;

        try {
            // Decode JWT to check expiration
            const payload = JSON.parse(atob(token.split('.')[1]));
            const expiresAt = payload.exp * 1000;
            return Date.now() < expiresAt;
        } catch {
            return false;
        }
    },

    async checkSession() {
        // Check and refresh token if needed
        return await checkAndRefreshToken();
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
    },

    async deleteAccount() {
        return apiRequest('/users/me', {
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

    async send(matchId, content, replyToId = null) {
        return apiRequest(`/messages/${matchId}`, {
            method: 'POST',
            body: JSON.stringify({ content, reply_to_id: replyToId })
        });
    },

    async edit(matchId, messageId, content) {
        return apiRequest(`/messages/${matchId}/${messageId}`, {
            method: 'PATCH',
            body: JSON.stringify({ content })
        });
    },

    async delete(matchId, messageId) {
        return apiRequest(`/messages/${matchId}/${messageId}`, {
            method: 'DELETE'
        });
    },

    async analyzeConversation(matchId) {
        return apiRequest(`/messages/${matchId}/analyze`, { method: 'POST' });
    }
};

const typing = {
    async setTyping(matchId, isTyping) {
        return apiRequest(`/typing/${matchId}`, {
            method: 'POST',
            body: JSON.stringify({ isTyping })
        });
    },

    async getPartnerTyping(matchId) {
        return apiRequest(`/typing/${matchId}`);
    }
};

const push = {
    async getVapidKey() {
        return apiRequest('/push/vapid-public-key');
    },

    async subscribe(subscription) {
        return apiRequest('/push/subscribe', {
            method: 'POST',
            body: JSON.stringify({ subscription })
        });
    },

    async unsubscribe(endpoint) {
        return apiRequest('/push/unsubscribe', {
            method: 'POST',
            body: JSON.stringify({ endpoint })
        });
    }
};

const presence = {
    async heartbeat() {
        return apiRequest('/presence/heartbeat', { method: 'POST' });
    },

    async setOffline() {
        return apiRequest('/presence/offline', { method: 'POST' });
    },

    async getStatus(userId) {
        return apiRequest(`/presence/${userId}`);
    },

    async getMatchStatus(matchId) {
        return apiRequest(`/presence/match/${matchId}`);
    }
};

// Page navigation tracking for PWA session restoration
const navigation = {
    // Pages that should be restored (main app pages, not auth/onboarding)
    restorablePages: ['chat.html', 'match.html', 'timer.html', 'reveal.html', 'revealed.html', 'revealrequest.html', 'settings.html'],

    // Save current page to localStorage
    saveCurrentPage() {
        const currentPage = window.location.pathname.split('/').pop() || 'index.html';
        if (this.restorablePages.includes(currentPage)) {
            localStorage.setItem('sparkLastPage', currentPage);
            localStorage.setItem('sparkLastPageTime', Date.now().toString());
        }
    },

    // Get the last saved page (if valid and recent)
    getLastPage() {
        const lastPage = localStorage.getItem('sparkLastPage');
        const lastPageTime = localStorage.getItem('sparkLastPageTime');

        if (!lastPage || !lastPageTime) return null;

        // Only restore if the saved page is less than 7 days old
        const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
        if (Date.now() - parseInt(lastPageTime) > sevenDaysMs) {
            this.clearLastPage();
            return null;
        }

        return lastPage;
    },

    // Clear saved page
    clearLastPage() {
        localStorage.removeItem('sparkLastPage');
        localStorage.removeItem('sparkLastPageTime');
    }
};

window.SparkAPI = {
    auth,
    users,
    matches,
    messages,
    typing,
    push,
    presence,
    navigation
};
