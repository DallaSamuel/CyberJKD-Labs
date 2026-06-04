# B819 Router — Discovered API Endpoints

Base URL: `http://192.168.0.1`

## GET endpoints — /reqproc/proc_get

All GET requests require `_=<timestamp_ms>` parameter.

| Endpoint | Returns | Notes |
|---|---|---|
| `/reqproc/proc_get?cmd=sms_capacity_info` | SMS storage counts | `sms_nv_total`, `sms_sim_rev_total` etc |
| `/reqproc/proc_get?cmd=sms_data_list&pageIndex=1&pageSize=20` | SMS message list | Empty when inbox cleared |
| `/reqproc/proc_get?cmd=upgrade_result` | `{"upgrade_result":""}` | Empty unless upgrade in progress |
| `/reqproc/proc_get?cmd=upgrade_state` | `{"upgrade_state":""}` | Empty at idle |
| `/reqproc/proc_get?cmd=upgrade_type` | `{"upgrade_type":""}` | Returns empty — FOTA only |
| `/reqproc/proc_get?cmd=fw_version` | `{"fw_version":""}` | Returns empty |
| `/reqproc/proc_get?cmd=multi_data=1&cmd=modem_main_state,...` | Device status bundle | Large multi-field response |

## POST endpoint — /cgi-bin/upload/upload.cgi

| Field | Value |
|---|---|
| Method | POST |
| Encoding | `multipart/form-data` |
| Field name | `filename` |
| Response | `{"result":"success"}` |
| Notes | Accepts any file, returns success — but only applies valid FOTA packages |

## Subpages

| Path | Status | Notes |
|---|---|---|
| `/subpg/ota_update.html` | 200 | Contains upload form with CGI action |
| `/subpg/adm_management.html` | 200 | Password change form |
| All other subpages probed | 404 | — |

## Fake endpoints (all return 404)

```
/goform/getSysInfo
/goform/deleteMsg
/goform/getSmsInfo
/goform/getStatus
/proc_get/*        (missing /reqproc/ prefix)
/config/version.txt
/firmware.bin
```

## Notes

- `_=` timestamp parameter must be current Unix time in milliseconds
- Router serves JS files directly: `/js/com.js`, `/js/lib.js`, `/js/set.js`, `/js/main.js`
- Web server: `Demo-Webs` (GoAhead-based embedded server)
- UPGRADE_TYPE is `"FOTA"` — local file uploads require proprietary package format
