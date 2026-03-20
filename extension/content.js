// Content script - runs on product pages
(function () {
    'use strict';

    const API_URL = 'https://price-tracker-api.stopimpulsebuying.workers.dev';

    // Detect if we're on a product page
    function isProductPage() {
        const url = window.location.href;
        // Check for /dp/ in URL for Amazon (works regardless of path before it)
        if (url.includes('/dp/')) return true;
        if (url.includes('walmart.com/ip/')) return true;
        if (url.includes('bestbuy.com/site/')) return true;
        if (url.includes('target.com/p/')) return true;
        return false;
    }

    // Extract product data based on store
    function extractProductData() {
        const url = window.location.href;
        let data = {
            url: url,
            title: null,
            price: null,
            imageUrl: null,
            store: null
        };

        if (url.includes('amazon.com') || url.includes('/dp/')) {
            data.store = 'amazon';
            data.title = document.querySelector('#productTitle')?.textContent.trim();

            // Try multiple price selectors
            const priceWhole = document.querySelector('.a-price-whole')?.textContent;
            const priceFraction = document.querySelector('.a-price-fraction')?.textContent;
            if (priceWhole) {
                data.price = parseFloat(priceWhole.replace(/[^0-9.]/g, '') + '.' + (priceFraction || '00'));
            }

            data.imageUrl = document.querySelector('#landingImage')?.src ||
                document.querySelector('#imgTagWrapperId img')?.src;
        } else if (url.includes('walmart.com')) {
            data.store = 'walmart';
            data.title = document.querySelector('h1[itemprop="name"]')?.textContent.trim();

            const priceEl = document.querySelector('[itemprop="price"]');
            if (priceEl) {
                data.price = parseFloat(priceEl.textContent.replace('$', '').replace(',', ''));
            }

            data.imageUrl = document.querySelector('[data-testid="hero-image-container"] img')?.src;
        } else if (url.includes('bestbuy.com')) {
            data.store = 'bestbuy';
            data.title = document.querySelector('.sku-title h1')?.textContent.trim();

            const priceEl = document.querySelector('[data-testid="customer-price"] span');
            if (priceEl) {
                data.price = parseFloat(priceEl.textContent.replace('$', '').replace(',', ''));
            }

            data.imageUrl = document.querySelector('.primary-image')?.src;
        } else if (url.includes('target.com')) {
            data.store = 'target';
            data.title = document.querySelector('h1[data-test="product-title"]')?.textContent.trim();

            const priceEl = document.querySelector('[data-test="product-price"]');
            if (priceEl) {
                data.price = parseFloat(priceEl.textContent.replace('$', '').replace(',', ''));
            }

            data.imageUrl = document.querySelector('[data-test="image-gallery-item-0"] img')?.src;
        }

        return data;
    }

    // Create and inject "Track Price" button
    function injectTrackButton() {
        if (document.getElementById('sib-track-button')) return; // Already injected

        const button = document.createElement('button');
        button.id = 'sib-track-button';
        button.className = 'sib-track-btn';
        button.innerHTML = `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="9" cy="21" r="1"></circle>
        <circle cx="20" cy="21" r="1"></circle>
        <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path>
      </svg>
      <span>Track Price</span>
    `;

        button.addEventListener('click', async () => {
            button.disabled = true;
            button.textContent = 'Adding...';

            const productData = extractProductData();

            try {
                // Send to background script
                chrome.runtime.sendMessage({
                    action: 'trackProduct',
                    data: productData
                }, (response) => {
                    if (response && response.success) {
                        button.textContent = '✓ Tracked!';
                        button.classList.add('sib-tracked');
                        setTimeout(() => {
                            button.innerHTML = `
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                  <path d="M10 2L3 7V17L10 22L17 17V7L10 2Z" stroke="currentColor" stroke-width="2"/>
                  <path d="M10 12L7 10V8L10 6L13 8V10L10 12Z" fill="currentColor"/>
                </svg>
                <span>Track Price</span>
              `;
                            button.disabled = false;
                            button.classList.remove('sib-tracked');
                        }, 3000);
                    } else {
                        button.textContent = 'Failed';
                        button.disabled = false;
                        console.error('Track failed:', response?.error || 'Unknown error');
                    }
                });
            } catch (error) {
                console.error('Error tracking product:', error);
                button.textContent = 'Error';
                button.disabled = false;
            }
        });

        // Find appropriate location to inject button
        let targetElement = null;
        const url = window.location.href;

        if (url.includes('amazon.com') || url.includes('/dp/')) {
            // Try multiple Amazon selectors in order of preference
            targetElement = document.querySelector('#add-to-cart-button')?.closest('div') ||
                document.querySelector('#addToCart_feature_div') ||
                document.querySelector('#buybox') ||
                document.querySelector('#desktop_buybox') ||
                document.querySelector('#rightCol') ||
                document.querySelector('#ppd');
        } else if (url.includes('walmart.com')) {
            targetElement = document.querySelector('[data-testid="add-to-cart-section"]');
        } else if (url.includes('bestbuy.com')) {
            targetElement = document.querySelector('.fulfillment-add-to-cart-button');
        } else if (url.includes('target.com')) {
            targetElement = document.querySelector('[data-test="orderPickupButton"]')?.parentElement;
        }

        if (targetElement) {
            targetElement.insertAdjacentElement('beforebegin', button);
            console.log('Stop Impulsing: Button injected successfully');
        } else {
            console.log('Stop Impulsing: Could not find target element for button injection');
            // Fallback: inject at top of page as floating button
            button.style.cssText = 'position: fixed; top: 100px; right: 20px; z-index: 99999;';
            document.body.appendChild(button);
            console.log('Stop Impulsing: Button injected as floating element');
        }
    }

    // Initialize
    console.log('Stop Impulsing: Content script loaded');
    console.log('Stop Impulsing: Current URL:', window.location.href);
    console.log('Stop Impulsing: Is product page?', isProductPage());

    if (isProductPage()) {
        console.log('Stop Impulsing: Detected product page, attempting injection');

        // Try immediate injection
        function tryInject() {
            if (!document.getElementById('sib-track-button')) {
                injectTrackButton();
            }
        }

        // Try immediately
        tryInject();

        // Retry after short delays (Amazon loads dynamically)
        setTimeout(tryInject, 500);
        setTimeout(tryInject, 1500);
        setTimeout(tryInject, 3000);
        setTimeout(tryInject, 5000);

        // Re-inject on dynamic content changes (SPAs)
        const observer = new MutationObserver(() => {
            if (!document.getElementById('sib-track-button')) {
                injectTrackButton();
            }
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    } else {
        console.log('Stop Impulsing: Not a product page, skipping injection');
    }
})();
