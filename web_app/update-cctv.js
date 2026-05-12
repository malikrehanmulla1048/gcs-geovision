const fs = require('fs');
let file = 'c:\\Users\\Marc Pedrin\\Desktop\\GCS - GeoVision\\admin\\cctv-feed.html';
let content = fs.readFileSync(file, 'utf8');

const bgMap = {
    'MAIN ENTRANCE': 'cctv_main_gate.png',
    'CENTRAL LOBBY': 'cctv_lobby.png',
    'PARKING LOT': 'cctv_parking.png',
    'LIBRARY HALL': 'cctv_library.png',
    'NORTH CORRIDOR': 'cctv_lobby.png',
    'HOSTEL GATE': 'cctv_main_gate.png',
    'SERVICE GATE': 'cctv_parking.png',
    'STORAGE YARD': 'cctv_parking.png'
}

let modified = content.replace(/<div class="cam-feed"><div class="cam-tag">(.*?)<\/div><\/div>/g, (match, tag) => {
    let img = bgMap[tag] || 'cctv_main_gate.png';
    return `<div class="cam-feed" style="background:url('../assets/${img}') center/cover;"><div class="cam-tag">${tag}</div></div>`;
});

fs.writeFileSync(file, modified, 'utf8');
