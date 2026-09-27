# Detection Query — Denied File Access on FS01

## Status: written, not yet validated against live data

The Data Collection Rule (`dcr-fs01-security`) and its association with FS01 are deployed and
active in the subscription — created directly via `az monitor data-collection rule create` and
`az monitor data-collection rule association create`, **not through Terraform**. Same for the
`AzureMonitorWindowsAgent` extension itself (`az vm extension set`). Neither is captured in this
repo's `.tf` files, which is a real gap: a `terraform destroy` + `terraform apply` from this
codebase today would not recreate this piece of the pipeline. Bringing the DCR and the agent
extension into `hardening.tf` as proper Terraform resources is listed in the README's
What I'd Change for Production section.

Separately, the agent *extension* reported `provisioningState: Succeeded`, but its Windows
service never actually registered on FS01 (`Get-Service` found no matching service at all), so
no event has shipped to the `law-fslab` workspace regardless of the Terraform question above.
That's the second, independent gap — see the README's Troubleshooting Log (#8).

The underlying audit event is real and already verified directly against FS01's own Security
log — a denied Finance access attempt by `tom.davis`, captured with `Get-WinEvent` during
testing. The queries below are what would run against the `Event` table once ingestion is
working; they're written against the actual field layout of that captured event, not guessed
syntax.

## Query 1 — Recent denied file access attempts

```kql
Event
| where EventLog == "Security"
| where Source == "Microsoft-Windows-Security-Auditing"
| where EventID in (4656, 4663)
| where RenderedDescription contains "Not granted"
| extend Account   = extract(@"Account Name:\s+(\S+)", 1, RenderedDescription)
| extend ObjectName = extract(@"Object Name:\s+([^\r\n]+)", 1, RenderedDescription)
| project TimeGenerated, Computer, EventID, Account, ObjectName
| order by TimeGenerated desc
```

Run this first to see every failed access attempt on FS01 in the selected time range, one row
per attempt, with the account and the object (share/folder/file) already pulled out of the raw
message text instead of making someone read the full event body.

`contains` is used instead of `has` for the phrase and path checks throughout this document:
`has` does word/term-boundary matching in KQL and is unreliable for multi-word phrases and
strings containing punctuation like backslashes (a file path would get tokenized into pieces,
not matched as one term). `contains` does a true substring match — slower on a large table, but
correct regardless of how the text tokenizes.

Scoped to `4656`/`4663` only, not `4660` (object deleted), even though the Data Collection Rule
collects all three. A deletion event doesn't carry a "Not granted" reason — it only fires on
success — so it would never match this filter anyway; the scoping here is deliberate (this is a
*denied-access* query), not an oversight. A separate query against `4660` alone would be the
right way to track deletions specifically.

## Query 2 — Denied attempts against a specific share

```kql
Event
| where EventLog == "Security"
| where EventID in (4656, 4663)
| where RenderedDescription contains "Not granted"
| where RenderedDescription contains @"C:\Shares\Finance"
| extend Account = extract(@"Account Name:\s+(\S+)", 1, RenderedDescription)
| project TimeGenerated, Computer, Account, EventID
| order by TimeGenerated desc
```

Narrows Query 1 to one share — this is the query that would have surfaced the `tom.davis`
Finance denial automatically, the same event this lab confirmed manually.

## Query 3 — Repeated-denial alert candidate

```kql
Event
| where EventLog == "Security"
| where EventID in (4656, 4663)
| where RenderedDescription contains "Not granted"
| extend Account = extract(@"Account Name:\s+(\S+)", 1, RenderedDescription)
| summarize DeniedAttempts = count() by Account, bin(TimeGenerated, 1h)
| where DeniedAttempts >= 5
```

Five or more denials from one account inside an hour is a reasonable first threshold for "this
looks like probing, not an honest mistake." This is written as a query, not wired up as an
actual Azure Monitor alert rule — the next step once ingestion is confirmed working would be
turning this into a scheduled alert with an action group (email/Teams/PagerDuty) attached.

## What was actually verified (no Log Analytics required)

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4656,4663; StartTime=(Get-Date).AddHours(-2)} |
  Where-Object { $_.Message -match 'tom.davis' } |
  Select-Object TimeCreated, Id, Message | Format-List
```

Result (trimmed to the relevant fields):

```
TimeCreated : 9/23/2026 9:09:13 PM
Id          : 4656
Account Name:           tom.davis
Object Name:            C:\Shares\Finance
Access Reasons:         ReadData (or ListDirectory):    Not granted
```

This confirms the audit policy and SACL are correctly generating the event at the source. The
only broken link is the Azure→Log Analytics shipping path, not the auditing itself.
