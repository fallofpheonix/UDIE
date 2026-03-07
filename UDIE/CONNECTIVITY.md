# Backend connectivity checklist

If the app shows **"Cannot connect to backend at http://localhost:3000"**, the app is still using `localhost`. On a **physical device** that points at the phone, not your Mac.

---

## 1. Where the URL comes from

The app reads the backend URL in this order:

1. **Environment variable** `UDIE_API_BASE_URL` (e.g. in Scheme → Run → Environment Variables) — **overrides everything**
2. **Info.plist** key `UDIE_API_BASE_URL`
3. **Build setting** `INFOPLIST_KEY_UDIE_API_BASE_URL` in the Xcode project
4. **Fallback** in `UDIE/Core/Networking/APIClient.swift`: `http://localhost:3000`

If you changed only `APIClient.swift` or only `Info.plist` but the app still shows localhost, either the **binary wasn’t rebuilt** or another source (e.g. plist) is still set to localhost.

---

## 2. Fix for physical device (no code edit)

1. **Get your Mac’s LAN IP**  
   Terminal: `ifconfig | grep "inet "` → use something like `192.168.1.7` (not 127.0.0.1).

2. **Set env var in the Run scheme**  
   Xcode → Product → Scheme → Edit Scheme… → **Run** → **Arguments** → **Environment Variables** → **+**  
   - Name: `UDIE_API_BASE_URL`  
   - Value: `http://192.168.1.7:3000` (your IP).

3. **Clean and rebuild**  
   Product → Clean Build Folder (⇧⌘K), then Build (⌘R). Run on device again.

4. **Backend must be running and reachable**  
   - `engine-backend` already listens on `0.0.0.0` in `engine-backend/src/main.ts`.  
   - On your Mac: `curl http://localhost:3000/api/v1/health/ready`  
   - On the same Wi‑Fi, from the phone’s browser: `http://192.168.1.7:3000/api/v1/health/ready`

5. **Same network**  
   Mac and phone must be on the same Wi‑Fi (or same VPN if you use one).

---

## 3. If it still shows localhost

- **Clean build**: Product → Clean Build Folder, then delete `~/Library/Developer/Xcode/DerivedData` (or at least the UDIE folder), then ⌘R.
- **Confirm env var**: Edit Scheme → Run → Environment Variables and ensure `UDIE_API_BASE_URL` is set and has no typo or newline.
- **Search the project** for `localhost:3000`: `UDIE/Info.plist`, `UDIE.xcodeproj/project.pbxproj` (INFOPLIST_KEY_UDIE_API_BASE_URL), and `APIClient.swift` (fallback). For device, the **running** app should get the URL from the scheme env var.

---

## 4. Quick checks

| Check | Command / action |
|-------|-------------------|
| Backend listening on Mac | `lsof -i :3000` or `curl http://localhost:3000/api/v1/health/ready` |
| Backend bound to all interfaces | `engine-backend/src/main.ts`: `await app.listen(port, '0.0.0.0')` ✓ |
| Test from phone browser | Open `http://YOUR_MAC_IP:3000/api/v1/health/ready` on the phone |

---

## 5. Backend running in Docker

If the backend runs **inside Docker** with `3000:3000`, the app still must use your **computer’s LAN IP**, not `localhost`.

- **Docker** maps port 3000 on the **host**, so the path is: **device → computer-ip:3000 → Docker → backend**.
- From the phone or simulator, `localhost` is the **device**, so `http://localhost:3000` never reaches your Mac.

**Do not edit code.** Set `UDIE_API_BASE_URL` in the Run scheme to `http://YOUR_MAC_IP:3000` (same as §2), then clean and rebuild.

**If containers keep restarting** (e.g. Postgres “database system is shut down” in logs):

- Run `docker ps` and ensure the backend container is **Up**, not **Restarting**.
- Then: `docker compose down` and `docker compose up --build`.

The Nest app in `engine-backend` already uses `listen(port, '0.0.0.0')`, so once the container is stable, external connections work.

---

## 6. 30-second stack check

Run these in order to see where the chain breaks:

| Step | Command | If it fails |
|------|--------|--------------|
| 1. Backend on Mac | `curl -s http://localhost:3000/api/v1/health/ready` | Backend not running or not listening on 3000 |
| 2. Containers up | `docker ps` (backend container **Up**) | Restart stack: `docker compose down && docker compose up --build` |
| 3. Backend from phone | In Safari on the phone: `http://YOUR_MAC_IP:3000/api/v1/health/ready` | Firewall, or phone not on same Wi‑Fi |

If (1) and (2) are OK but (3) fails → firewall or network. If (1) fails → backend/NestJS not serving on 3000 or container crashed.

---

## 7. Permanent setup (optional)

Use two schemes:

- **UDIE (Simulator)** – no `UDIE_API_BASE_URL` (or leave as localhost).
- **UDIE (Device)** – Environment Variable `UDIE_API_BASE_URL` = `http://YOUR_MAC_IP:3000`.

Switch schemes when running on simulator vs device so you never have to edit code or plist for the URL.

---

## If it still fails

Only these remain:

1. Backend container crashed or not listening on 3000  
2. NestJS bound to `127.0.0.1` (this project uses `0.0.0.0` ✓)  
3. Firewall blocking port 3000  
4. App still using localhost → set `UDIE_API_BASE_URL` in Scheme and clean rebuild
