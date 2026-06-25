# Selova Product Analytics

Selova uses PostHog Cloud for a developer-only product analytics dashboard.

- Dashboard: https://us.posthog.com/project/484042/dashboard/1754529
- Purpose: understand feature adoption, navigation, learning engagement, and completion behavior.
- Not for: viewing video titles, URLs, note text, or user-entered content.

## Privacy defaults

- Only explicit custom events are sent.
- Automatic screen, lifecycle, and element-interaction capture are disabled.
- Session replay is disabled.
- Client IP storage is disabled in the PostHog project.
- Every custom event disables GeoIP enrichment.
- Selova does not call `identify`, so analytics remains per-install anonymous.

## Event catalog

| Event | Properties | Answers |
| --- | --- | --- |
| `app launched` | — | How often is the app opened? |
| `screen viewed` | `screen_name` | Which areas of the app are used? |
| `tab selected` | `tab_name` | Do people move between Home and Library? |
| `video added` | `stage`, `entry_point`, `video_source` | Where does video import start and complete? |
| `folder created` | `folder_level` | Is folder organization being adopted? |
| `video started` | `video_source`, `is_resumed` | What kind of learning content is played and resumed? |
| `feed paged` | `direction`, `video_source` | How do users move through the study feed? |
| `notes opened` | `video_source` | Is the note feature used during study? |
| `study session recorded` | `duration_seconds`, `focused_seconds`, `focus_rate`, `video_source` | How long and how deeply do users focus? |
| `video completed` | `video_source` | How often do users finish learning videos? |
| `setting changed` | `setting_name`, `setting_value` | Which study settings are actually used? |
| `focus insights viewed` | — | Is the Focus Insights sheet being opened? |
| `recommendation tapped` | `recommendation_kind`, `surface`, `video_source` | Which recommendation surfaces actually send people back into study? |
| `close reminder scheduled` | `video_source`, `reminder_count`, `threshold_seconds` | How often do reminder notifications become eligible? |
| `live activity started` | `video_source` | How often does the Live Activity return prompt appear? |
| `return to study` | `source`, `reminder_id`, `video_source` | Which return prompts actually bring people back into study? |

## Dashboard setup

The dashboard starts with:

- `日次アプリ起動数`
- `画面ごとの利用数`

Recommended additions for the dashboard:

- A funnel from `video added` (`stage = saved`) to `video started` and `video completed`.
- Trends for average `focused_seconds` and `focus_rate` on `study session recorded`.
- Trends for `recommendation tapped`, `close reminder scheduled`, `live activity started`, and `return to study` with source breakdown where useful.
