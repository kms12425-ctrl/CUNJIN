# 寸进 · CUNJIN

> *An inch a day.*

A personal progress tracker built for HarmonyOS NEXT (API 12+, ArkTS / ArkUI).

## What is this?

**CUNJIN** (寸进, "an inch of progress") is a record-and-plan app built around doing one thing at a time. Create a plan card, set a deadline and a target number of hours, then check in day by day and leave a one-line note for each day. The app does the arithmetic — progress, time left, hours still needed per day — and turns it into progress rings and a stats board (PRAISE ARK UI!).

The name comes from 日有寸进: no promises of a breakthrough, only of accumulation. An inch is still an inch.

## Features

- **Plan cards** — name, description, deadline (or "until forever"), target hours (or "the sky is the limit"), and card length
- **Daily check-in** — log hours for the day and attach a note to it
- **Timer** — start and stop a running session from the card detail; the elapsed time lands on today
- **Progress rings** — done vs. time-left, with day counts and percentages computed live
- **Manage** — pin to top, archive (dimmed, and optionally hidden), delete
- **Stats** — today / last 7 days / streak / total, plus a per-day heat grid
- **Appearance** — solid color or image background, blur radius, light & dark color schemes, minimum card width
- **Backup** — export the whole store as JSON; a snapshot is saved automatically before any import

## Screenshots

> These were taken before the rename, so the header still shows the old title. Re-run a preview to refresh them.

![Phone](Examples/Screenshot_Phone.png)
![Foldable](Examples/Rocky%E2%80%99s%20Green%20Dashboard%20Interface_foldable.png)
![Pad](Examples/Rocky%E2%80%99s%20CUNJIN%20Time%20Dashboard_pad.png)

## Layout

```
AppScope/                     app-level config and icon
entry/src/main/ets/
├─ pages/Index.ets            single page: layout, state, events
├─ components/                cards, rings, board, panels
│  └─ atoms/                  title, explanation, symbol button, text area
├─ model/                     pure data layer: model, codecs, queries, stats, time formatting
├─ repository/                persistence: KV wrapper, single write path, backup files
├─ design/                    shared animation parameters
└─ entryability/              entry ability and backup extension
```

Most of `model/` and `repository/` is plain functions with no `@kit.*` imports, so the local unit tests (`entry/src/test`) can exercise it directly.

## Data

Local KV storage under `cards_v2` / `settings_v2` / `work_state_v2`, serialized from one object model. Everything read back passes through `normalize*` guards — missing fields get defaults, mismatched lengths get realigned — so old data loads without a migration step.

Backups carry the `cunjin-next-backup` format token and are named `cunjin-backup-*.json`; a snapshot is saved automatically before any import.

## Build

Open this directory in DevEco Studio, or build with a configured hvigor toolchain. `compatibleSdkVersion` is `5.0.0(12)`.

## License

See [LICENSE](LICENSE).
