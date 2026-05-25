# Funicontrol

Funicontrol is a small cable-car control-room simulator built with Rails, ActionCable, SQLite, and Funicular/PicoRuby.wasm. It demonstrates a Ruby SPA that receives live car-position updates, sends dispatch commands, manages incidents and comments, keeps an operation log, and replays historical events.

## What It Shows

- Live line dashboard with running cars, incident counts, SLA state, and recent operation events.
- Line control screen with canvas/DOM map, station state, dispatch console, line status controls, operator chat, and incident creation.
- ActionCable synchronization across browser windows.
- Incident workflow with acknowledgement, resolution, comments, ActiveStorage attachments, thumbnails, replacement, and purge.
- Replay mode that rebuilds line state from operation events.
- IndexedDB/localStorage-backed client stores for preferences, drafts, cached HTTP responses, selected line, and operation logs.
- PWA shell with manifest and service worker.

## Setup

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails funicular:compile
```

The seed data is idempotent. It creates the main `mt-ruby` line plus scenario lines:

- `mt-ruby`: Mt. Ruby Funicular
- `mt-ruby-crowded`: Crowded Demo
- `mt-ruby-emergency`: Emergency Drill
- `mt-ruby-maintenance`: Maintenance Window

## Run

```sh
bin/rails server
```

Open:

- http://127.0.0.1:3000/dashboard
- http://127.0.0.1:3000/lines/mt-ruby
- http://127.0.0.1:3000/replay
- http://127.0.0.1:3000/settings

Start the simulator in another terminal:

```sh
bin/simulate
```

Useful simulator flags:

```sh
SIM_TICK_INTERVAL=0.5 bin/simulate
SIM_RANDOM_EVENTS=1 bin/simulate
SIM_ACTIVE_JOB=1 bin/simulate
```

`SIM_ACTIVE_JOB=1` enqueues `SimulationTickJob` through ActiveJob/Solid Queue instead of running the foreground loop.

## Demo Flow

1. Open two browser windows at `/lines/mt-ruby`.
2. Run `bin/simulate`.
3. Select a car and press `Emergency`.
4. Confirm the other browser receives the stopped status through ActionCable.
5. Use `Recover`, then confirm the inspection-required step before returning to service.
6. Suspend/resume the line, enter/exit maintenance, update weather, or change a station to alert/crowded/closed.
7. Create a quick incident, optionally attach an image or inspection file, then open the incident detail.
8. Acknowledge, comment, replace or remove attachments, and resolve the incident.
9. Use `/replay` to step through the recorded operation events and compare replay state to live state.

## Funicular Coverage

- `Funicular::Model`: `Line`, `Station`, `Car`, `Incident`, `IncidentComment`, `OperationEvent`, `TrackSegment`.
- Routing: `/dashboard`, `/lines/:id_or_slug`, `/cars/:id`, `/incidents`, `/incidents/:id`, `/replay`, `/settings`.
- HTTP: cached and live line loading, dispatch API, line status changes, weather, station operations, incident/comment workflows, reports, scenarios, replay event loading.
- ActionCable: `LineChannel` streams `line_<id>` updates, dispatches car actions, and accepts operator messages.
- Store: `OperatorPrefsStore`, `IncidentDraftStore`, `OperationLogCache`, `SelectedLineStore`, and `HttpCacheStore`.
- Form Builder: incident upload form, comment form, settings form.
- CSS-in-Ruby styles: car state, severity, dispatch button variants.
- ErrorBoundary: line map, operation log, replay panel.
- Suspense: dashboard, line control, car detail, incident detail, replay data loading.
- Refs: operation log scroll target and line-map canvas.
- JS Integration: canvas line map, upload bridge, operation-log scroll helper, JSON normalization.
- FileUpload: incident attachments use ActiveStorage through multipart form submission.

Note: `funicular 0.1.0` does not currently compile `app/funicular/stores`, so app-side Store classes live under `app/funicular/models` to keep them in the compiler input set.

## API

Representative endpoints:

```text
GET    /api/lines
GET    /api/lines/:id_or_slug
POST   /api/lines/:id_or_slug/suspend
POST   /api/lines/:id_or_slug/resume
POST   /api/lines/:id_or_slug/enter_maintenance
POST   /api/lines/:id_or_slug/exit_maintenance
POST   /api/lines/:id_or_slug/weather
POST   /api/lines/:id_or_slug/dispatch

GET    /api/lines/:line_id_or_slug/stations
POST   /api/lines/:line_id_or_slug/stations/:id/raise_alert
POST   /api/lines/:line_id_or_slug/stations/:id/clear_alert
POST   /api/lines/:line_id_or_slug/stations/:id/mark_crowded
POST   /api/lines/:line_id_or_slug/stations/:id/close
POST   /api/lines/:line_id_or_slug/stations/:id/reopen

GET    /api/lines/:line_id_or_slug/cars
GET    /api/cars/:id_or_code
POST   /api/cars/:id_or_code/dispatch

GET    /api/incidents
GET    /api/lines/:line_id_or_slug/incidents
POST   /api/lines/:line_id_or_slug/incidents
GET    /api/incidents/:id
PATCH  /api/incidents/:id
POST   /api/incidents/:id/acknowledge
POST   /api/incidents/:id/resolve
DELETE /api/incidents/:id/attachments/:attachment_id
GET    /api/incidents/:incident_id/incident_comments
POST   /api/incidents/:incident_id/incident_comments

GET    /api/lines/:line_id_or_slug/operation_events
GET    /api/reports/daily
POST   /api/scenarios/import
GET    /api/schema/:id
```

Operation event queries support `after_id`, `before_id`, `since`, `order=asc`, `important=true`, `event_type`, `car_id`, `station_id`, `incident_id`, and `severity`.

Validation and domain errors use a consistent JSON object:

```json
{ "errors": { "title": ["Title can't be blank"] } }
```

## Checks

Run the full local check script:

```sh
bin/check
```

It runs bundler-audit, Brakeman, StandardRB, Funicular compile, and Rails tests.

Individual checks:

```sh
bin/rails test
bin/rails test:system
bin/rails funicular:compile
bundle exec standardrb
```

The test suite covers models, services, jobs, request APIs, `LineChannel`, and a two-browser synchronization system test.
