/**
 * GeoVision — Client-Side Database (IndexedDB + localStorage fallback)
 * api/db.js
 *
 * Schemas:
 *   users       — credentials, profile, face enrolment
 *   entry_logs  — gate entry/exit records
 *   visitors    — visitor management records
 */

const GeoVisionDB = (() => {
  const DB_NAME    = 'geovision_db';
  const DB_VERSION = 1;
  let db = null;

  // ── OPEN / INIT ──────────────────────────────────────────────
  function open() {
    return new Promise((resolve, reject) => {
      if (db) { resolve(db); return; }

      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onupgradeneeded = (e) => {
        const idb = e.target.result;

        // USERS store
        if (!idb.objectStoreNames.contains('users')) {
          const users = idb.createObjectStore('users', { keyPath: 'email' });
          users.createIndex('role', 'role', { unique: false });
        }

        // ENTRY LOGS store
        if (!idb.objectStoreNames.contains('entry_logs')) {
          const logs = idb.createObjectStore('entry_logs', {
            keyPath: 'id', autoIncrement: true
          });
          logs.createIndex('userId',    'userId',    { unique: false });
          logs.createIndex('timestamp', 'timestamp', { unique: false });
          logs.createIndex('gate',      'gate',      { unique: false });
        }

        // VISITORS store
        if (!idb.objectStoreNames.contains('visitors')) {
          const visitors = idb.createObjectStore('visitors', {
            keyPath: 'id', autoIncrement: true
          });
          visitors.createIndex('status', 'status', { unique: false });
        }
      };

      request.onsuccess = (e) => { db = e.target.result; resolve(db); };
      request.onerror   = (e) => { console.error('DB open failed', e); reject(e); };
    });
  }

  // ── GENERIC HELPERS ──────────────────────────────────────────
  function tx(store, mode = 'readonly') {
    return db.transaction(store, mode).objectStore(store);
  }

  function getAll(storeName) {
    return open().then(() => new Promise((resolve, reject) => {
      const req = tx(storeName).getAll();
      req.onsuccess = () => resolve(req.result);
      req.onerror   = reject;
    }));
  }

  function getByKey(storeName, key) {
    return open().then(() => new Promise((resolve, reject) => {
      const req = tx(storeName).get(key);
      req.onsuccess = () => resolve(req.result);
      req.onerror   = reject;
    }));
  }

  function put(storeName, record) {
    return open().then(() => new Promise((resolve, reject) => {
      const req = tx(storeName, 'readwrite').put(record);
      req.onsuccess = () => resolve(req.result);
      req.onerror   = reject;
    }));
  }

  function add(storeName, record) {
    return open().then(() => new Promise((resolve, reject) => {
      const req = tx(storeName, 'readwrite').add(record);
      req.onsuccess = () => resolve(req.result);
      req.onerror   = reject;
    }));
  }

  function deleteRecord(storeName, key) {
    return open().then(() => new Promise((resolve, reject) => {
      const req = tx(storeName, 'readwrite').delete(key);
      req.onsuccess = () => resolve();
      req.onerror   = reject;
    }));
  }

  function getByIndex(storeName, indexName, value) {
    return open().then(() => new Promise((resolve, reject) => {
      const req = tx(storeName).index(indexName).getAll(value);
      req.onsuccess = () => resolve(req.result);
      req.onerror   = reject;
    }));
  }

  // ── AUTH ─────────────────────────────────────────────────────
  const HARDCODED = [
    {
      email:    'admin@reva.edu.in',
      password: 'Admin',
      role:     'admin',
      name:     'Admin User',
    },
    {
      email:    'student@reva.edu.in',
      password: 'Student',
      role:     'student',
      name:     'Demo Student',
      studentId: 'SRN21CV007',
      phone:    '+91 98765 43210',
      dept:     'Computer Science',
      year:     '3rd Year',
      faceEnrolled: false,
      pfp:      null,
      joinedAt: new Date().toISOString(),
    }
  ];

  async function seedDefaults() {
    for (const u of HARDCODED) {
      const existing = await getByKey('users', u.email).catch(() => null);
      if (!existing) await put('users', u);
    }
  }

  async function authenticate(email, password) {
    await open();
    await seedDefaults();
    const user = await getByKey('users', email);
    if (!user) return { ok: false, error: 'No account found with this email.' };
    if (user.password !== password) return { ok: false, error: 'Incorrect password.' };
    // Store session
    sessionStorage.setItem('gv_user', JSON.stringify({ email: user.email, role: user.role, name: user.name }));
    return { ok: true, user };
  }

  function currentUser() {
    try { return JSON.parse(sessionStorage.getItem('gv_user')); }
    catch { return null; }
  }

  function logout() {
    sessionStorage.removeItem('gv_user');
  }

  function requireAuth(role) {
    const u = currentUser();
    if (!u) { window.location.href = '/index.html'; return null; }
    if (role && u.role !== role) {
      window.location.href = u.role === 'admin'
        ? '/admin/dashboard.html'
        : '/user/profile.html';
      return null;
    }
    return u;
  }

  // ── USERS ────────────────────────────────────────────────────
  const users = {
    get:    (email)  => getByKey('users', email),
    getAll: ()       => getAll('users'),
    save:   (record) => put('users', record),
    register: async (data) => {
      const existing = await getByKey('users', data.email).catch(() => null);
      if (existing) return { ok: false, error: 'Email already registered.' };
      const user = {
        ...data,
        role:         'student',
        faceEnrolled: false,
        pfp:          null,
        joinedAt:     new Date().toISOString(),
      };
      await put('users', user);
      sessionStorage.setItem('gv_user', JSON.stringify({ email: user.email, role: 'student', name: user.name }));
      return { ok: true, user };
    }
  };

  // ── ENTRY LOGS ───────────────────────────────────────────────
  const entryLogs = {
    getAll:      ()        => getAll('entry_logs'),
    getByUser:   (userId)  => getByIndex('entry_logs', 'userId', userId),
    add:         (record)  => add('entry_logs', { ...record, timestamp: record.timestamp || new Date().toISOString() }),
    seedSample:  async ()  => {
      const all = await getAll('entry_logs');
      if (all.length > 0) return;
      const gates = ['Main Gate', 'East Entrance', 'North Gate', 'Admin Block Entry'];
      const names = ['Ramesh Kumar','Ananya Shah','Courier Exec','Dr. Jha','Vijay Thomas','Suresh Babu','Kiran Reddy','Mohammed Tariq'];
      const now = Date.now();
      for (let i = 0; i < 20; i++) {
        await add('entry_logs', {
          userId:    'demo_' + i,
          name:      names[i % names.length],
          gate:      gates[i % gates.length],
          type:      i % 3 === 0 ? 'exit' : 'entry',
          timestamp: new Date(now - i * 600000).toISOString(),
          confidence: (85 + Math.random() * 14).toFixed(1),
        });
      }
    }
  };

  // ── VISITORS ─────────────────────────────────────────────────
  const visitors = {
    getAll:    ()         => getAll('visitors'),
    getActive: async ()   => {
      const all = await getAll('visitors');
      return all.filter(v => v.status !== 'Exited');
    },
    add:    (record)      => add('visitors', { ...record, checkinAt: record.checkinAt || new Date().toISOString() }),
    update: (record)      => put('visitors', record),
    remove: (id)          => deleteRecord('visitors', id),
    seedSample: async () => {
      const all = await getAll('visitors');
      if (all.length > 0) return;
      const seeds = [
        { name:'Ramesh Kumar',  phone:'+91 98001 11111', purpose:'Meeting Faculty',  host:'Dr. Ravi Shankar',    dept:'CS Dept',    idnum:'KA-DL-2021-0001234', status:'On Campus' },
        { name:'Ananya Shah',   phone:'+91 98001 22222', purpose:'Parent Visit',     host:'Admin Office',        dept:'Admin Block', idnum:'MH-5432109876',      status:'On Campus' },
        { name:'Courier Exec',  phone:'+91 98001 33333', purpose:'Delivery',         host:'Admin Block',         dept:'Admin Block', idnum:'CORP-DELIVERY-001',  status:'On Campus' },
        { name:'Dr. Jha',       phone:'+91 98001 44444', purpose:'Guest Lecture',    host:'Prof. Meenakshi Iyer',dept:'EC Dept',    idnum:'GOV-GJ-19875432',    status:'On Campus' },
        { name:'Vijay Thomas',  phone:'+91 98001 55555', purpose:'Maintenance',      host:'Facilities',          dept:'Lab Block',   idnum:'MAINT-2024-007',     status:'Exited'    },
      ];
      const gates = ['Main Gate','East Entrance','North Gate','Admin Block Entry'];
      for (const s of seeds) {
        await add('visitors', { ...s, gate: gates[Math.floor(Math.random() * gates.length)], checkinAt: new Date().toISOString() });
      }
    }
  };

  // ── INIT ─────────────────────────────────────────────────────
  async function init() {
    await open();
    await seedDefaults();
    await entryLogs.seedSample();
    await visitors.seedSample();
  }

  return { init, authenticate, currentUser, logout, requireAuth, users, entryLogs, visitors };
})();

// Auto-init on load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => GeoVisionDB.init().catch(console.error));
} else {
  GeoVisionDB.init().catch(console.error);
}
