# Chrome Web Store Submission Checklist

## Extension Information

| Field | Value |
|-------|-------|
| **Name** | Stop Impulsing |
| **Short Description** (132 chars) | Track product prices and beat impulse buying. Add items to your wishlist and get notified when the cooldown ends. |
| **Category** | Shopping |

## Full Description

Stop impulse buying with smart price tracking.

**The Problem:**
You see something you want. You buy it immediately. You regret it later.

**The Solution:**
Stop Impulsing adds a "Think About It" button to product pages. Click it, set a cooldown period, and we'll track the price. You only get notified AFTER your cooldown ends—giving you time to decide if you really need it.

**Features:**
✓ One-click product tracking from any store
✓ Works on Amazon, Walmart, Target, Best Buy, and 1000+ more
✓ Price history tracking
✓ Syncs with our iOS app
✓ Privacy-focused: we only see pages you explicitly track

**How It Works:**
1. Visit any product page
2. Click "Track with Stop Impulsing"
3. Set your cooldown (7, 14, or 30 days)
4. We track the price silently
5. After cooldown, you get notified of the current price

**Free Forever:**
Track 1 product for free. Upgrade for more.

Beat the algorithm. Keep your money.

## Required Assets

### Icons
| Size | Filename | Usage |
|------|----------|-------|
| 128x128 | icon128.png | Chrome Web Store |
| 48x48 | icon48.png | Extensions page |
| 16x16 | icon16.png | Toolbar |

### Screenshots (1280x800 or 640x400)
1. Product page with "Track" button visible
2. Extension popup showing tracked items
3. Price drop notification

### Promotional Images
| Size | Usage |
|------|-------|
| 440x280 | Small promo tile |
| 920x680 | Large promo tile (optional) |
| 1400x560 | Marquee (optional) |

## Permissions Justification

| Permission | Justification |
|------------|---------------|
| `activeTab` | Needed to detect product pages and extract price/title |
| `storage` | Store user preferences and auth token locally |
| `https://*.supabase.co/*` | Communicate with our backend API |

## Privacy Practices

### Data Use Declarations
- [ ] **Personally Identifiable Information**: YES (email for account)
- [ ] **Health Information**: NO
- [ ] **Financial Information**: NO
- [ ] **Authentication Information**: YES (stored locally)
- [ ] **Personal Communications**: NO
- [ ] **Location**: NO
- [ ] **Web History**: NO (only pages where user clicks Track)
- [ ] **User Activity**: YES (which products tracked)
- [ ] **Website Content**: YES (product title, price, image)

### Data Usage
- Used to provide core functionality
- NOT sold to third parties
- NOT used for advertising

## URLs Required

| Type | URL |
|------|-----|
| Website | https://stopimpulsing.app |
| Privacy Policy | https://stopimpulsing.app/privacy |
| Support | https://stopimpulsing.app/support |

## Pre-Submission Checklist

- [ ] All icons generated
- [ ] Screenshots captured
- [ ] Promotional tile created
- [ ] Privacy policy URL live
- [ ] Manifest permissions minimal
- [ ] Remove console.log statements
- [ ] Test on Chrome, Edge, Brave
- [ ] Increment version in manifest.json
- [ ] Create .zip of extension folder
- [ ] Submit to Chrome Web Store Developer Dashboard

## Review Notes

"This extension adds a 'Track Price' button to e-commerce product pages. Users must explicitly click this button to track a product—we do not automatically track or monitor browsing history.

The extension communicates with our backend (Supabase/Cloudflare) only when the user initiates tracking. No data is collected passively."
