# CyberJKD Router Firmware Research
## B819 4G/5G Router - SMS UI Bug Fix & Firmware Analysis


**Author:** Dalla Samuel (CyberJKD)

**Status:** In Progress - Patch written, UART root shell pending

**Platform:** CP106 / FY_CP106_V4 · ZXIC ZC2535 SoC

**Roadmap:** [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap)
 
---
 
## Overview
 
This project documents the reverse engineering of a B819 4G/5G router manufactured by Dong Yang Shi Paisheng Smart Home Co., Ltd. 

The router's SMS page was stuck in an infinite loading loop - a bug caused by a missing retry escape in the frontend JavaScript. 
This project covers the full discovery process: browser console attack, API reverse engineering, JS source analysis, patch development, upload endpoint discovery, and hardware identification for UART root access.
 
**What I was able to prove:**
- Identified the real API endpoint structure
- Found and fixed a JavaScript infinite loop bug
- Wrote and tested CyberJKD Patch v1.0
- Discovered the firmware upload CGI endpoint
- Located UART pads on the PCB for root shell access
---
 
## Device Specifications
 
| Field | Value |
|-------|-------|
| Model | B819 (white-label OEM) |
| Manufacturer | Dong Yang Shi Paisheng Smart Home Co., Ltd |
| Platform | CP106 / FY_CP106_V4 |
| SoC | ZXIC ZC2535 |
| Firmware | CP106TV4.4_XY_FB_FY_DL_V01.01.02P42U17_01 |
| Web Server | Demo-Webs |
| ISP | MTN Nigeria |
| Admin UI | http://192.168.0.1 |
 
---
 
## The Bug
 
**Problem:** The SMS page at `http://192.168.0.1/#fast_set` was stuck in an infinite loading loop — permanently showing "Waiting..." and blocking all UI interaction.
 
**Root cause:** The router's frontend JavaScript checks `simStatus` before rendering the SMS inbox. 
If `simStatus` is `undefined` or matches a value in `TEMPORARY_MODEM_MAIN_STATE`, the function calls itself again via `addTimeout()` every 500ms. 
There was no exit condition - no retry limit, no timeout escape. The loop ran forever.
 
**Discovery method:** Browser DevTools → Network tab → XHR filter → identified `/reqproc/proc_get` as the real polling endpoint → downloaded `com.js` from `http://192.168.0.1/js/com.js` → located the loop at position ~155771.
 
---
 
## Phase Breakdown
 
### Phase 1 - Problem Diagnosis
SMS page stuck in infinite loading loop. Observed repeated XHR calls in DevTools Network tab with no resolution.
 
**Key finding:** Real API base is `/reqproc/proc_get` - not `/goform/` as expected from most Chinese router platforms.

 
### Phase 2 - Browser Console Attack
Identified overlay element IDs responsible for the stuck UI:
- `loading` - the loading spinner
- `confirm-overlay` - modal overlay
- `.simplemodal-overlay` - jQuery SimpleModal overlay
- `.simplemodal-container` - jQuery SimpleModal container


### Phase 3 - API Reverse Engineering
Discovered the real polling endpoint structure:
 
```
GET /reqproc/proc_get?cmd=upgrade_result&_=<timestamp>
GET /reqproc/proc_get?multi_data=1&sms_received_flag_flag=0&sts_received_flag_flag=0&cmd=...
GET /reqproc/proc_get?cmd=sms_capacity_info&_=<timestamp>
```
 
Confirmed upload endpoint:
```
POST /cgi-bin/upload/upload.cgi
Content-Type: multipart/form-data
→ Returns: {"result":"success"}
```
 
### Phase 4 - JS Source Analysis
Downloaded and analysed `com.js` (207KB) from the router using curl on Kali Linux:
 
```bash
curl -o /tmp/com.js "http://192.168.0.1/js/com.js?random=0.1"
```
 
Located the infinite simStatus loop bug at position ~155771 in `com.js`.
 
Also downloaded supporting JS files for full frontend analysis:
```
~/router_fw/js/com.js    — 207KB — main frontend logic
~/router_fw/js/lib.js    — 19KB  — library functions
~/router_fw/js/set.js    — 16KB  — settings page logic
~/router_fw/js/main.js   — 2KB   — entry point
```
 
### Phase 5 - Patch Development
 
**CyberJKD Patch v1.0** - two-part fix:
 
**PATCH 1 - Fix infinite simStatus loop**
 
Replace in `com.js` at position ~155771:
 
```javascript
// BUGGY (original) — no exit condition:
if(t.simStatus==undefined){
  showLoading("waiting");
  function p(){
    var u=g.getStatusInfo();
    if(u.simStatus==undefined||f.inArray(u.simStatus,c.TEMPORARY_MODEM_MAIN_STATE)!=-1){
      addTimeout(p,500)  // loops forever
    }else{
      d(q[0],u.simStatus,r);
      hideLoading()
    }
  }
  p()
}
 
// FIXED — retry counter, exits after 10 attempts (5 seconds):
if(t.simStatus==undefined){
  showLoading("waiting");
  var _retryCount=0;
  function p(){
    var u=g.getStatusInfo();
    _retryCount++;
    if(_retryCount>10){
      hideLoading();
      d(q[0],u.simStatus||"modem_init_complete",r);
      return
    }
    if(u.simStatus==undefined||f.inArray(u.simStatus,c.TEMPORARY_MODEM_MAIN_STATE)!=-1){
      addTimeout(p,500)
    }else{
      d(q[0],u.simStatus,r);
      hideLoading()
    }
  }
  p()
}
```
 
**PATCH 2 - Overlay killer** (appended to end of `com.js`)
 
```javascript
;(function(){
  var _ok=setInterval(function(){
    var l=document.getElementById("loading");
    var o=document.querySelector(".simplemodal-overlay");
    var c=document.querySelector(".simplemodal-container");
    var co=document.getElementById("confirm-overlay");
    if(l&&l.style.display!=="none")l.style.display="none";
    if(o&&o.style.display!=="none")o.style.display="none";
    if(c&&c.style.display!=="none")c.style.display="none";
    if(co&&co.style.display!=="none")co.style.display="none";
  },300);
  console.log("[CyberJKD PATCH v1.0] SMS fix active");
})();
```
 
**How the patch works:**
- Patch 1 adds a `_retryCount` variable that increments on each loop iteration.
  After 10 retries (5 seconds), it forces `hideLoading()` and falls back to `modem_init_complete` - breaking the infinite loop permanently
- Patch 2 adds an interval that checks for stuck overlay elements every 300ms and forces them hidden - acts as a safety net for any other UI blocking scenarios


### Phase 6 - Upload Endpoint Found
 
```bash
curl -v -X POST "http://192.168.0.1/cgi-bin/upload/upload.cgi" \
  --form "file=@test.bin" \
  -H "Referer: http://192.168.0.1/"
# Returns: {"result":"success"}
```
 
Firmware upload page scan results:
```
ota_update: 200   ← accessible
adm_upgrade: 404
adm_software_upload: 404
software_upload: 404
system_upgrade: 404
```
 
### Phase 7 - Hardware Identification
 
**PCB:** FY_CP106_V4
**SoC:** ZXIC ZC2535
**UART pads:** Located at top edge of PCB - 4 pads visible
 
**Next step for root access:**
1. Get CP2102 USB-TTL adapter
2. Connect TX → RX, RX → TX, GND → GND
3. Open serial terminal at 115200 baud
4. Access Linux root shell
5. Replace `com.js` directly on the filesystem
6. Full router customisation - CyberJKD firmware
---

 
## Current Status
 
| Task | Status |
|------|--------|
| Bug identified | ✅ Complete |
| CyberJKD Patch v1.0 written | ✅ Complete |
| Upload CGI discovered and tested | ✅ Complete |
| API endpoint structure mapped | ✅ Complete |
| PCB and UART pads located | ✅ Complete |
| Patch permanently flashed | ⏳ Pending — firmware package format being reverse engineered |
| UART root shell access | ⏳ Pending — need CP2102 USB-TTL adapter |
| Full router customisation | 🎯 Goal |
 
---
 
## Tools Used
 
| Tool | Purpose |
|------|---------|
| Kali Linux | Primary attack platform |
| curl | HTTP requests, JS file extraction, endpoint testing |
| binwalk | Firmware binary analysis |
| grep | JS source pattern matching |
| Browser DevTools | Network tab XHR analysis, console attack |
| Firefox (Network tab) | API endpoint discovery |
 
---
 
## Files
 
```
router_fw/
├── js/
│   ├── com.js          — main frontend logic (patched)
│   ├── lib.js          — library functions
│   ├── set.js          — settings page logic
│   └── main.js         — entry point
├── firmware.bin        — firmware binary (171 bytes placeholder)
├── index.html          — router web root
└── patch/
    └── cyberjkd_patch_v1.0.js   — CyberJKD Patch v1.0
```
 
---
 
## Screenshots
 
| # | Screenshot | Description |
|---|-----------|-------------|
| 01 | 01-kali-js-download.png | Kali Linux — curl downloading com.js from router |
| 02 | 02-firmware-analysis.png | curl + binwalk firmware endpoint analysis |
| 03 | 03-api-endpoint-discovery.png | POST /reqproc/proc_set endpoint testing |
| 04 | 04-router-webui-devtools.png | Router Web UI with DevTools Network tab open |
| 05 | 05-upload-endpoint-search.png | grep searching set.js for upload form action |
| 06 | 06-firmware-paths-scan.png | ota_update 200 — upload path confirmed |
| 07 | 07-browser-console-xhr.png | Browser console XHR calls to /reqproc/proc_get |
| 08 | 08-patch-verification.png | curl verifying CyberJKD PATCH signature in com.js |
| 09 | 09-patch-upload-test.png | Patch upload test and upgrade_result response |
 
---
 
## What I'd Change for Production
 
| Current approach | Production improvement |
|-----------------|----------------------|
| Manual patch injection via curl | Automated patch deployment script |
| Browser overlay killer interval | Root-level com.js replacement via UART |
| Firmware package format unknown | Full firmware unpacking with binwalk + squashfs |
| UART access pending | CP2102 adapter + automated root shell script |
 
---
 
## Next Steps
 
1. **Get CP2102 USB-TTL adapter** - enables UART root shell access
2. **Dump full filesystem** via UART root shell
3. **Replace com.js directly** on the router filesystem
4. **Reverse engineer firmware package format** - build custom firmware update package
5. **CyberJKD firmware** - custom UI, security hardening, feature additions
---
 
> "Becoming dangerous through fundamentals." - CyberJKD

 
**GitHub:** [github.com/DallaSamuel/CyberJKD-Labs](https://github.com/DallaSamuel/CyberJKD-Labs)

**Roadmap:** [dallasamuel.github.io/CyberJKD-Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap)
