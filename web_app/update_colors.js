const fs = require('fs');
let content = fs.readFileSync('index.html', 'utf8');

// Replace CSS variables section completely
content = content.replace(/:root\s*\{[\s\S]*?\}/, `:root {
            /* Core Palette */
            --clr-primary: red;
            --clr-primary-light: red;
            --clr-primary-dark: red;
            --clr-primary-ghost: red;
            --clr-primary-ghost-hover: red;

            --clr-accent: red;
            --clr-danger: red;
            --clr-danger-ghost: red;
            --clr-warning: yellow;
            --clr-warning-ghost: yellow;
            --clr-success: green;
            --clr-success-ghost: green;
            --clr-online: green;
            --clr-offline: red;

            /* Surfaces */
            --bg-body: white;
            --bg-sidebar: black;
            --bg-card: white;
            --bg-panel: white;
            --bg-table-row-hover: white;
            --bg-table-row-selected: white;
            --bg-input: white;
            --bg-badge: white;

            /* Text */
            --text-primary: black;
            --text-secondary: black;
            --text-tertiary: black;
            --text-inverse: white;
            --text-sidebar: white;
            --text-sidebar-active: white;

            /* Borders */
            --border-light: black;
            --border-focus: red;

            /* Shadows */
            --shadow-sm: none;
            --shadow-md: none;
            --shadow-lg: none;
            --shadow-xl: none;
            --shadow-card: none;
            --shadow-card-hover: none;

            /* Layout */
            --sidebar-width: 260px;
            --panel-width: 320px;
            --radius-sm: 6px;
            --radius-md: 10px;
            --radius-lg: 14px;
            --radius-xl: 20px;
            --radius-full: 9999px;

            /* Transitions */
            --transition-fast: 150ms ease;
            --transition-normal: 250ms ease;
            --transition-slow: 400ms cubic-bezier(0.4, 0, 0.2, 1);
        }`);

// Replace rgba functions
content = content.replace(/rgba?\([^)]+\)/g, (match) => {
    if (match.includes('255,255,255') || match.includes('255, 255, 255') || match.includes('200,200,200')) return 'white';
    if (match.includes('220,38,38') || match.includes('220, 38, 38') || match.includes('255,0,0')) return 'red';
    if (match.includes('34,197,94') || match.includes('34, 197, 94') || match.includes('0,255,0')) return 'green';
    if (match.includes('245,158,11') || match.includes('245, 158, 11') || match.includes('255,255,0')) return 'yellow';
    return 'black';
});

// Replace hex codes
content = content.replace(/#([a-fA-F0-9]{3,6})\b/gi, (match) => {
    if (match === '#') return match;
    match = match.toLowerCase();
    const isDark = ['#111111', '#1a1a1a', '#0d0d0d', '#111', '#222', '#333', '#444', '#555', '#666', '#888', '#000', '#000000'];
    const isLight = ['#f1f1f1', '#f5f5f5', '#f9f9f9', '#fafafa', '#ffffff', '#fff', '#e4e4e4', '#cccccc'];
    const isRed = ['#ef4444', '#991b1b', '#dc2626', '#7f1d1d', '#b91c1c'];
    if (isDark.includes(match)) return 'black';
    if (isLight.includes(match)) return 'white';
    if (isRed.includes(match)) return 'red';
    return 'black'; 
});

// Remove gradient rules explicitly if they slipped through
content = content.replace(/linear-gradient\([^)]+\)/g, (match) => {
    if(match.includes('red') || match.includes('white') || match.includes('black') || match.includes('yellow') || match.includes('green')){
        return match;
    }
    return 'black'; // fallback
});
// let's actually just replace linear-gradient backgrounds completely with solid colours.
content = content.replace(/background:\s*linear-gradient\([^)]+\)/g, 'background: black');
content = content.replace(/background: black/g, (match, offset, str) => {
    // If we're inside .sidebar-avatar or something, maybe make it red
    return match;
});

// One specific fix for avatar
content = content.replace(/background:linear-gradient\([^)]+\)/g, 'background:red');


fs.writeFileSync('index.html', content);
