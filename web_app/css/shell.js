/* ================================================================
   GEOVISION — SHARED SHELL JS v3.0
   Include on every page AFTER the body content
   ================================================================ */

/* ── PEOPLE DATA POOL ── */
const PEOPLE = [
  { name:'Arjun Kumar',     id:'SRN21CS001', dept:'CS',  role:'Student',  initials:'AK', color:'#dc2626,#991b1b', threat:'Low' },
  { name:'Priya Sharma',    id:'SRN21EC045', dept:'EC',  role:'Student',  initials:'PS', color:'#2563eb,#1e3a8a', threat:'Low' },
  { name:'Rohit Nair',      id:'SRN21ME012', dept:'ME',  role:'Student',  initials:'RN', color:'#16a34a,#14532d', threat:'Low' },
  { name:'Sneha Krishnan',  id:'STAF-005',   dept:'Admin',role:'Staff',  initials:'SK', color:'#7c3aed,#4c1d95', threat:'Low' },
  { name:'Mohammed Tariq',  id:'SRN21IT088', dept:'IT',  role:'Student',  initials:'MT', color:'#db2777,#831843', threat:'Low' },
  { name:'Divya Menon',     id:'SRN22CS034', dept:'CS',  role:'Student',  initials:'DM', color:'#0891b2,#164e63', threat:'Low' },
  { name:'Kiran Reddy',     id:'SRN22EE021', dept:'EE',  role:'Student',  initials:'KR', color:'#d97706,#92400e', threat:'Low' },
  { name:'Ananya Pillai',   id:'STAF-009',   dept:'Admin',role:'Staff',  initials:'AP', color:'#dc2626,#7f1d1d', threat:'Medium' },
  { name:'Suresh Babu',     id:'SRN21CV007', dept:'CV',  role:'Student',  initials:'SB', color:'#059669,#064e3b', threat:'Low' },
  { name:'Lavanya Singh',   id:'SRN22CS019', dept:'CS',  role:'Student',  initials:'LS', color:'#6366f1,#312e81', threat:'Low' },
  { name:'Ravi Teja',       id:'SRN21EC081', dept:'EC',  role:'Student',  initials:'RT', color:'#ea580c,#7c2d12', threat:'Low' },
  { name:'Meghna Bose',     id:'STAF-012',   dept:'Faculty',role:'Faculty',initials:'MB',color:'#0ea5e9,#0c4a6e', threat:'Low' },
];

const GATES = ['Main Gate','East Entrance','Library','Admin Block','Sports Complex','Lab Block','Cafeteria','North Gate'];

/* ── THEME ── */
function initTheme() {
  const saved = localStorage.getItem('gv-theme') || 'light';
  if (saved === 'dark') document.documentElement.setAttribute('data-theme','dark');
  updateThemeToggle(saved);
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme') || 'light';
  const next = current === 'dark' ? 'light' : 'dark';
  if (next === 'dark') document.documentElement.setAttribute('data-theme','dark');
  else document.documentElement.removeAttribute('data-theme');
  localStorage.setItem('gv-theme', next);
  updateThemeToggle(next);
}

function updateThemeToggle(theme) {
  const btn = document.getElementById('theme-toggle');
  if (!btn) return;
  btn.innerHTML = theme === 'dark'
    ? '<span class="toggle-icon">☀️</span> Light Mode'
    : '<span class="toggle-icon">🌙</span> Dark Mode';
}

/* ── CLOCK ── */
function startClock() {
  const clockEl = document.getElementById('live-clock');
  const dateEl  = document.getElementById('live-date');
  if (!clockEl) return;
  function tick() {
    const now = new Date();
    clockEl.textContent = now.toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit',second:'2-digit'});
    if (dateEl) dateEl.textContent = now.toLocaleDateString('en-IN',{weekday:'long',year:'numeric',month:'long',day:'numeric'});
  }
  tick(); setInterval(tick, 1000);
}

/* ── TOAST ── */
function showToast(msg, type='info') {
  let wrap = document.getElementById('toast-container');
  if (!wrap) {
    wrap = document.createElement('div');
    wrap.id = 'toast-container';
    wrap.className = 'toast-container';
    document.body.appendChild(wrap);
  }
  const t = document.createElement('div');
  t.className = `toast ${type}`;
  t.textContent = msg;
  wrap.appendChild(t);
  setTimeout(() => t.remove(), 3200);
}

/* ── HELPERS ── */
function fmtTime(d) {
  return d.toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit',second:'2-digit'});
}

function randomPerson() {
  return PEOPLE[Math.floor(Math.random() * PEOPLE.length)];
}

function randomGate() {
  return GATES[Math.floor(Math.random() * GATES.length)];
}

function randomConf() {
  return (85 + Math.random() * 14.9).toFixed(1);
}

function randomLowConf() {
  return (55 + Math.random() * 25).toFixed(1);
}

/* ── INIT ── */
document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  startClock();

  const themeBtn = document.getElementById('theme-toggle');
  if (themeBtn) themeBtn.addEventListener('click', toggleTheme);

  const logoutBtn = document.getElementById('btn-logout');
  if (logoutBtn) logoutBtn.addEventListener('click', () => {
    if (confirm('Are you sure you want to logout?')) {
      showToast('Logging out…','info');
      sessionStorage.removeItem('gv_user'); // Clear user session from DB
      setTimeout(() => window.location.href = '../index.html', 1000);
    }
  });

  const refreshBtn = document.getElementById('btn-refresh');
  if (refreshBtn) refreshBtn.addEventListener('click', () => showToast('Dashboard refreshed — data is up to date.','info'));

  const exportBtn = document.getElementById('btn-export');
  if (exportBtn) exportBtn.addEventListener('click', () => showToast('Generating security report… download starting shortly.','info'));

  // CCTV Modal Injection
  const modalHTML = `
    <div id="cctv-modal" class="cctv-modal">
        <div class="cctv-modal-overlay"></div>
        <div class="cctv-modal-content">
            <button class="cctv-modal-close">&times;</button>
            <div class="cctv-modal-header">
                <span class="cctv-modal-title">Live Feed</span>
                <span class="cctv-modal-badge">LIVE</span>
            </div>
            <div class="cctv-modal-video" id="cctv-modal-video"></div>
        </div>
    </div>
  `;
  document.body.insertAdjacentHTML('beforeend', modalHTML);

  const cctvModal = document.getElementById('cctv-modal');
  const modalVideo = document.getElementById('cctv-modal-video');
  const modalTitle = cctvModal.querySelector('.cctv-modal-title');
  const closeBtn = cctvModal.querySelector('.cctv-modal-close');
  const overlay = cctvModal.querySelector('.cctv-modal-overlay');

  function closeCctvModal() {
      cctvModal.classList.remove('active');
  }

  closeBtn.addEventListener('click', closeCctvModal);
  overlay.addEventListener('click', closeCctvModal);

  const triggers = document.querySelectorAll('.cctv-cell, .cam-card');
  triggers.forEach(trigger => {
      trigger.addEventListener('click', () => {
          const bgEl = trigger.querySelector('.cctv-cell-bg') || trigger.querySelector('.cam-feed');
          const titleEl = trigger.querySelector('.cctv-label') || trigger.querySelector('h4');
          const titleText = titleEl ? titleEl.textContent.trim() : 'Live Camera';

          if (bgEl) {
              if (bgEl.style.backgroundImage) {
                  modalVideo.style.backgroundImage = bgEl.style.backgroundImage;
              } else if (bgEl.style.background) {
                   modalVideo.style.background = bgEl.style.background;
              }
          }

          modalTitle.textContent = titleText.replace(/🔒|📍|❌/g, '').trim();
          cctvModal.classList.add('active');
      });
  });
});
