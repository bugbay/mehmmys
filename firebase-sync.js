// ============================================================
//  Mehmmy — Firebase (Firestore) live sync layer
//  Loaded as a module by index.html. Sets window.MehmmyCloud.
//  If firebase-config.js still has placeholders, stays disabled
//  and the app runs in local-only mode (no SDK is even loaded).
// ============================================================
import { firebaseConfig, GROUP_ID } from "./firebase-config.js";

const SDK = "https://www.gstatic.com/firebasejs/10.12.2/";
const Cloud = { enabled: false, status: "off", groupId: GROUP_ID, __ready: false };
window.MehmmyCloud = Cloud;

function ready() {
  Cloud.__ready = true;
  window.dispatchEvent(new Event("mehmmy-cloud-ready"));
}
function setStatus(s) {
  Cloud.status = s;
  window.dispatchEvent(new Event("mehmmy-cloud-status"));
}

const configured = firebaseConfig && firebaseConfig.apiKey && !/^YOUR_/.test(firebaseConfig.apiKey);

if (!configured) {
  ready(); // local-only mode — Firebase SDK never downloaded
} else {
  initCloud().catch(() => { setStatus("error"); ready(); });
}

async function initCloud() {
  // Load the SDK only when actually configured.
  const [{ initializeApp }, fs, { getAuth, signInAnonymously }] = await Promise.all([
    import(SDK + "firebase-app.js"),
    import(SDK + "firebase-firestore.js"),
    import(SDK + "firebase-auth.js")
  ]);
  const {
    getFirestore, collection, doc, onSnapshot, getDocs,
    setDoc, updateDoc, deleteDoc, increment, query, orderBy, limit
  } = fs;

  const app = initializeApp(firebaseConfig);
  const db = getFirestore(app);
  const auth = getAuth(app);
  const base = "groups/" + GROUP_ID;
  const fcol = () => collection(db, base + "/friends");
  const pcol = () => collection(db, base + "/places");
  const acol = () => collection(db, base + "/activity");
  const fref = (id) => doc(db, base + "/friends/" + id);
  const pref = (id) => doc(db, base + "/places/" + id);
  const aref = (id) => doc(db, base + "/activity/" + id);

  const cache = { friends: null, places: null, activity: null };
  let onData = null;
  const emit = () => { if (onData) onData(cache); };
  const num = (id) => { const n = Number(id); return String(n) === String(id) ? n : id; };
  const stripId = (o) => { const c = Object.assign({}, o); delete c.id; return c; };

  async function seed(local) {
    const jobs = [];
    (local.friends || []).forEach((f, i) => jobs.push(setDoc(fref(f.id), {
      name: f.name, emoji: f.emoji, color: f.color,
      mehmmys: f.mehmmys, miles: f.miles, rides: f.rides,
      order: Number(f.id) || (1000 + i)
    })));
    (local.places || []).forEach((p, i) => jobs.push(setDoc(pref(p.id), { name: p.name, lat: p.lat, lon: p.lon, order: i })));
    (local.activity || []).forEach((a, i) => jobs.push(setDoc(aref(a.id), Object.assign({ ts: Date.now() - i * 1000 }, stripId(a)))));
    await Promise.all(jobs);
  }

  Cloud.enabled = true;
  setStatus("connecting");

  Cloud.init = async function (local, cb) {
    onData = cb;
    try { await signInAnonymously(auth); } catch (e) { /* open rules may allow anonymous access */ }
    try {
      const snap = await getDocs(fcol());
      if (snap.empty) await seed(local);
    } catch (e) { setStatus("error"); return; }

    onSnapshot(fcol(), (s) => {
      cache.friends = s.docs.map((d) => Object.assign({ id: num(d.id) }, d.data()))
        .sort((a, b) => (a.order || 0) - (b.order || 0));
      emit();
    }, () => setStatus("error"));

    onSnapshot(pcol(), (s) => {
      cache.places = s.docs.map((d) => Object.assign({ id: d.id }, d.data()))
        .sort((a, b) => (a.order || 0) - (b.order || 0));
      emit();
    });

    onSnapshot(query(acol(), orderBy("ts", "desc"), limit(60)), (s) => {
      cache.activity = s.docs.map((d) => Object.assign({ id: d.id }, d.data()));
      emit();
    });

    setStatus("synced");
  };

  Cloud.logRide = (friendId, miles, act) => {
    updateDoc(fref(friendId), { mehmmys: increment(1), miles: increment(miles), rides: increment(1) }).catch(() => {});
    setDoc(aref(act.id), Object.assign({ ts: Date.now() }, stripId(act))).catch(() => {});
  };
  Cloud.redeem = (friendId, n, act) => {
    updateDoc(fref(friendId), { mehmmys: increment(-n) }).catch(() => {});
    setDoc(aref(act.id), Object.assign({ ts: Date.now() }, stripId(act))).catch(() => {});
  };
  Cloud.addFriend = (f) => setDoc(fref(f.id), { name: f.name, emoji: f.emoji, color: f.color, mehmmys: 0, miles: 0, rides: 0, order: Number(f.id) || Date.now() }).catch(() => {});
  Cloud.removeFriend = (id) => deleteDoc(fref(id)).catch(() => {});
  Cloud.addPlace = (p) => setDoc(pref(p.id), { name: p.name, lat: p.lat, lon: p.lon, order: Date.now() }).catch(() => {});
  Cloud.removePlace = (id) => deleteDoc(pref(id)).catch(() => {});

  ready();
}
