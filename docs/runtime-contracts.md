# Runtime Contracts

The Ruby runtime owns all files under `runtime.stateDir`.

`snapshot.json` contains normalized source status, active-candidate runs, an independently bounded current-nightly cohort, recent terminal runs, aggregate summary, and presenter-owned `view` data. It never contains raw database credentials, raw command arguments, or raw log tails.

`ui.json` has the shape:

```json
{"open": false, "requestedAt": ""}
```

`state-event.json` changes after snapshot or UI writes so QuickShell can reload both files.

The Waybar payload has the standard shape:

```json
{"text":"SFB 1 !3","tooltip":"...","class":["benchbar","warning","active","has-attention"]}
```
