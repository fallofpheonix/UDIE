/**
 * UDIE Web Admin - Client-side Router
 */
class UDIERouter {
    constructor() {
        this.routes = {
            'dashboard': 'dashboard.html',
            'map': 'map.html',
            'routes': 'routes.html',
            'analytics': 'analytics.html',
            'health': 'system-health.html',
            'settings': 'settings.html'
        };

        window.addEventListener('popstate', () => this.handleNavigation());
    }

    navigate(page) {
        if (this.routes[page]) {
            history.pushState({ page }, '', `#${page}`);
            this.handleNavigation();
        }
    }

    async handleNavigation() {
        const page = window.location.hash.replace('#', '') || 'dashboard';
        const contentArea = document.getElementById('main-content');

        if (contentArea) {
            try {
                const response = await fetch(this.routes[page] || this.routes['dashboard']);
                const html = await response.text();
                contentArea.innerHTML = html;

                // Initialize page-specific modules
                this.initModule(page);
            } catch (err) {
                contentArea.innerHTML = '<h2>Page Load Failed</h2>';
            }
        }
    }

    initModule(page) {
        console.log(`UDIE: Initializing module - ${page}`);
        // Dispatch event for specialized modules to hook into
        window.dispatchEvent(new CustomEvent('pageChange', { detail: { page } }));
    }
}

window.router = new UDIERouter();
window.addEventListener('load', () => window.router.handleNavigation());
