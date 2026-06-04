"""
CyberJKD Patch v1.0
B819 Router / CP106 Platform — SMS infinite loop fix

Usage:
    python3 patch_script.py

Input:  com.js (extracted from router at http://192.168.0.1/js/com.js)
Output: com_patched.js (ready for upload to router)
"""

import os

INPUT_FILE  = 'com.js'
OUTPUT_FILE = 'com_patched.js'

# ── PATCH 1 ── simStatus infinite loop fix ──────────────────────────────────
# Bug: function p() calls itself every 500ms with no exit condition.
# Fix: add retry counter — forces hideLoading() after 10 retries (5 seconds).

OLD_CODE = (
    'if(t.simStatus==undefined){showLoading("waiting");'
    'function p(){var u=g.getStatusInfo();'
    'if(u.simStatus==undefined||f.inArray(u.simStatus,c.TEMPORARY_MODEM_MAIN_STATE)!=-1)'
    '{addTimeout(p,500)}else{d(q[0],u.simStatus,r);hideLoading()}}p()}'
)

NEW_CODE = (
    'if(t.simStatus==undefined){showLoading("waiting");'
    'var _retryCount=0;'
    'function p(){var u=g.getStatusInfo();_retryCount++;'
    'if(_retryCount>10){hideLoading();d(q[0],u.simStatus||"modem_init_complete",r);return}'
    'if(u.simStatus==undefined||f.inArray(u.simStatus,c.TEMPORARY_MODEM_MAIN_STATE)!=-1)'
    '{addTimeout(p,500)}else{d(q[0],u.simStatus,r);hideLoading()}}p()}'
)

# ── PATCH 2 ── Overlay killer ─────────────────────────────────────────────
# Appended to end of com.js.
# Suppresses all known blocking overlays every 300ms.

OVERLAY_KILLER = """
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
"""

def apply_patch():
    if not os.path.exists(INPUT_FILE):
        print(f"[ERROR] {INPUT_FILE} not found. Extract it first:")
        print(f'  curl -o {INPUT_FILE} "http://192.168.0.1/js/com.js?random=0.1"')
        return

    content = open(INPUT_FILE, 'r', encoding='utf-8').read()
    original_size = len(content)

    if OLD_CODE not in content:
        print("[ERROR] Patch target string not found — firmware version may differ")
        return

    patched = content.replace(OLD_CODE, NEW_CODE)
    patched += OVERLAY_KILLER

    open(OUTPUT_FILE, 'w', encoding='utf-8').write(patched)
    patched_size = len(patched)

    print(f"[SUCCESS] Patch applied")
    print(f"  Original : {original_size:,} bytes")
    print(f"  Patched  : {patched_size:,} bytes")
    print(f"  Delta    : +{patched_size - original_size} bytes")
    print(f"  Output   : {OUTPUT_FILE}")
    print()
    print("Next step — upload to router:")
    print(f'  curl -X POST "http://192.168.0.1/cgi-bin/upload/upload.cgi" \\')
    print(f'    -F "filename=@{OUTPUT_FILE};type=application/javascript"')

if __name__ == '__main__':
    apply_patch()
