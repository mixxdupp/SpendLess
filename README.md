# Stop Impulsing

iOS app + Chrome extension to track product prices and prevent impulse purchases.

## Project Structure

```
SpendLess/
├── Sources/SpendLess/     # iOS App (Swift/SwiftUI)
│   ├── Models/                       # Data models
│   ├── Services/                     # API, Auth, Purchase services
│   ├── Views/                        # SwiftUI views
│   └── Components/                   # Reusable UI components
├── backend/                          # Backend API
│   ├── workers/                      # Cloudflare Workers
│   └── supabase/migrations/          # Database schema
└── extension/                        # Chrome Extension
    ├── manifest.json
    ├── content.js                    # Inject track button
    ├── background.js                 # API communication
    └── popup.html/js                 # Extension popup
```

## Setup Instructions

### 1. Supabase Setup

1. Create account at [supabase.com](https://supabase.com)
2. Create new project
3. Run migration: `backend/supabase/migrations/001_initial_schema.sql`
4. Get project URL and anon key from Settings > API

### 2. Cloudflare Workers Setup

```bash
cd backend
npm install
wrangler login
wrangler secret put SUPABASE_KEY  # Paste your Supabase anon key
wrangler deploy
```

Update `wrangler.toml` with your Supabase URL.

### 3. iOS App Setup

1. Open Xcode
2. Update `AuthService.swift` and `APIClient.swift` with your Supabase credentials
3. Configure App Store Connect:
   - Bundle ID: `com.stopimpulsebuying.app`
   - Create in-app products:
     - `com.stopimpulsebuying.unlock` ($4.99 one-time)
     - `com.stopimpulsebuying.premium.monthly` ($2.99/month)
     - `com.stopimpulsebuying.premium.yearly` ($29.99/year)

### 4. Chrome Extension Setup

1. Update `API_URL` in `background.js`, `content.js`, `popup.js`
2. Load extension in Chrome:
   - Go to `chrome://extensions`
   - Enable Developer Mode
   - Click "Load unpacked"
   - Select `extension/` folder

## Configuration Needed

Replace placeholders in these files:

- `Sources/SpendLess/Services/AuthService.swift` - Supabase URL/key
- `Sources/SpendLess/Services/APIClient.swift` - Supabase URL/key
- `backend/wrangler.toml` - Supabase URL, KV namespace ID
- `backend/workers/index.js` - Update scraping logic (currently placeholder)
- `extension/background.js` - Worker URL
- `extension/content.js` - Worker URL
- `extension/popup.js` - Worker URL

## Key Features

- **Impulse Blocker**: Cooldown period (3-30 days) before price alerts
- **Money Saved Tracker**: Shows total value of products NOT purchased
- **Social Sharing**: Share savings achievements
- **Multi-store Support**: Amazon, Walmart, Best Buy, Target
- **Price History Charts**: Visual price trends
- **Push Notifications**: Alert when prices drop (after cooldown)

## Next Steps

1. **Replace scraping placeholders** in `backend/workers/index.js`
   - Implement real scraping or use affiliate APIs
   - Consider legal implications (see implementation_plan.md)

2. **Add push notifications**
   - Configure APNs certificates
   - Implement notification sending in Workers

3. **Create app icons**
   - iOS app icon (1024x1024)
   - Extension icons (16x16, 48x48, 128x128)

4. **Privacy Policy & Terms**
   - Required for App Store and Chrome Web Store
   - Update links in `SettingsView.swift`

5. **Testing**
   - Test all subscription tiers
   - Test price scraping accuracy
   - Test push notifications
   - Test extension on all supported stores


## Legal Considerations

Web scraping may violate store ToS. Mitigation:
- Respectful rate limiting
- Use official APIs where available
- Consider data provider partnerships at scale
- Have legal review before launch

## License

Proprietary - All rights reserved
