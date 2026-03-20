// Background service worker
const API_URL = 'https://price-tracker-api.stopimpulsebuying.workers.dev';

// Handle messages from content script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'trackProduct') {
        trackProduct(request.data)
            .then(result => sendResponse({ success: true, data: result }))
            .catch(error => sendResponse({ success: false, error: error.message }));
        return true; // Keep channel open for async response
    }
});

async function trackProduct(productData) {
    // Get auth token from storage
    const { authToken } = await chrome.storage.local.get('authToken');

    if (!authToken) {
        throw new Error('Please sign in to the iOS app first');
    }

    const response = await fetch(`${API_URL}/products`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${authToken}`
        },
        body: JSON.stringify({
            url: productData.url,
            cooldown_days: 7
        })
    });

    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to track product');
    }

    return await response.json();
}

// Badge to show tracked products count
async function updateBadge() {
    const { authToken } = await chrome.storage.local.get('authToken');

    if (!authToken) {
        chrome.action.setBadgeText({ text: '' });
        return;
    }

    try {
        const response = await fetch(`${API_URL}/products`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });

        if (response.ok) {
            const data = await response.json();
            const count = data.products?.length || 0;
            chrome.action.setBadgeText({ text: count > 0 ? count.toString() : '' });
            chrome.action.setBadgeBackgroundColor({ color: '#667eea' });
        }
    } catch (error) {
        console.error('Failed to update badge:', error);
    }
}

// Update badge periodically
chrome.alarms.create('updateBadge', { periodInMinutes: 30 });
chrome.alarms.onAlarm.addListener((alarm) => {
    if (alarm.name === 'updateBadge') {
        updateBadge();
    }
});

// Update on install
chrome.runtime.onInstalled.addListener(() => {
    updateBadge();
});
