document.addEventListener('DOMContentLoaded', () => {
  const authInput = document.getElementById('authData');
  const saveBtn = document.getElementById('saveBtn');
  const statusDiv = document.getElementById('status');

  saveBtn.addEventListener('click', async () => {
    try {
      const rawData = authInput.value.trim();
      if (!rawData) {
        throw new Error('Please paste your sync data');
      }

      let authData;
      try {
        authData = JSON.parse(rawData);
      } catch (e) {
        // Try decoding base64 if user pasted a base64 string
        try {
          authData = JSON.parse(atob(rawData));
        } catch (e2) {
          throw new Error('Invalid format. Please copy fresh data from the iOS app.');
        }
      }

      if (!authData.access_token || !authData.refresh_token) {
        throw new Error('Missing token data. Please try copying again.');
      }

      // Save to storage
      await chrome.storage.local.set({
        authToken: authData.access_token,
        refreshToken: authData.refresh_token,
        userId: authData.user_id
      });

      statusDiv.textContent = '✓ Successfully synced!';
      statusDiv.className = 'success';
      statusDiv.style.display = 'block';

      // Notify background script to update badge
      chrome.runtime.sendMessage({ action: 'updateBadge' });

      setTimeout(() => {
        window.close();
      }, 1500);

    } catch (error) {
      statusDiv.textContent = error.message;
      statusDiv.className = 'error';
      statusDiv.style.display = 'block';
    }
  });
});
