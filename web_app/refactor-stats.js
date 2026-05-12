const fs = require('fs');
const path = require('path');

const files = [
    'admin/dashboard.html',
    'admin/entry-history.html',
    'admin/security-threats.html',
    'user/visitor-management.html'
];
const basePath = 'c:\\Users\\Marc Pedrin\\Desktop\\GCS - GeoVision';

for (const rel of files) {
    const fullPath = path.join(basePath, rel);
    if (!fs.existsSync(fullPath)) continue;
    let content = fs.readFileSync(fullPath, 'utf8');
    
    // The regex to find all current stat cards
    const regex = /<div class="stat-card"([^>]*)>\s*<div class="stat-card-header">\s*<div class="stat-card-icon"([^>]*)>(.*?)<\/div>\s*(<span class="stat-card-trend[^>]*>.*?<\/span>)\s*<\/div>\s*(<div class="stat-card-value"[^>]*>.*?<\/div>)\s*<div class="stat-card-label">(.*?)<\/div>\s*<\/div>/gs;

    let matchCount = 0;
    let modified = content.replace(regex, (match, cardAttrs, iconAttrs, iconBody, trendRaw, valueRaw, labelBody) => {
        matchCount++;
        return `<div class="stat-card"${cardAttrs}>
          <div class="stat-card-header">
            <div class="stat-card-title-group">
              <div class="stat-card-label">${labelBody.trim()}</div>
              <div class="stat-card-icon"${iconAttrs}>${iconBody.trim()}</div>
            </div>
            ${trendRaw.trim()}
          </div>
          ${valueRaw.trim()}
        </div>`;
    });

    fs.writeFileSync(fullPath, modified, 'utf8');
    console.log(`Updated ${rel}: replaced ${matchCount} cards`);
}
