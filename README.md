# Funicontrol

Funicontrol is a small cable-car control-room simulator built with Rails, ActionCable, SQLite, and Funicular/PicoRuby.wasm. It demonstrates a Ruby SPA that receives live car-position updates, sends dispatch commands, records incidents and comments, keeps an operation log, and replays historical events.

## Setup

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails funicular:compile
```

The seed data is idempotent and creates one line, three stations, and two cars:

- Mt. Ruby Funicular
- 麓駅, 中腹駅, 山頂駅
- Car A, Car B

## Run

```sh
bin/rails server
```

Open:

- http://127.0.0.1:3000/dashboard
- http://127.0.0.1:3000/lines/1
- http://127.0.0.1:3000/cars/1

Start the simulator in a second terminal:

```sh
bin/simulate
```

With two browser windows open on `/lines/1`, car position, dispatch changes, line suspend/resume, station alerts, incidents, comments, and the operation log are broadcast through ActionCable.

## Demo Flow

1. Open two browser windows at `/lines/1`.
2. Run `bin/simulate`.
3. Select a car and press `Emergency`.
4. Confirm the other browser receives the stopped status.
5. Suspend/resume the line or raise/clear a station alert from the control side panel.
6. Create an incident from Quick Incident.
7. Attach an image or inspection file to the incident if needed.
8. Open the incident detail and post a comment.
9. Use `/replay` to step through the recorded operation events.

## Funicular Coverage

- `Funicular::Model`: `Line`, `Station`, `Car`, `Incident`, `IncidentComment`, `OperationEvent`.
- Routing: `/dashboard`, `/lines/:id`, `/cars/:id`, `/incidents`, `/incidents/:id`, `/replay`, `/settings`.
- HTTP: cached line/station/event loading, dispatch API, line status changes, station alerts, incident/comment creation, replay event loading.
- ActionCable: `LineChannel` streams `line_<id>` updates and accepts the `dispatch` action.
- Store: IndexedDB-backed `OperatorPrefsStore`, `IncidentDraftStore`, `OperationLogCache`, `SelectedLineStore`, and `HttpCacheStore`, with a localStorage mirror for synchronous reads.
- Form Builder: incident form with file upload, comment form, settings form.
- CSS-in-Ruby styles: car state, severity, dispatch button variants.
- ErrorBoundary: line map, operation log, replay panel.
- Suspense: dashboard, line control, car detail, incident detail, replay data loading.
- Refs: operation log scroll target and line-map canvas.
- JS Integration: `line_map_renderer.js` draws the line, stations, and cars on canvas.
- FileUpload: incident photos/files use ActiveStorage through multipart form submission.

Note: `funicular 0.1.0` does not currently compile `app/funicular/stores`, so the app-side Store classes live under `app/funicular/models` to keep them in the compiler input set.

## API

Representative endpoints:

```text
GET  /api/lines
GET  /api/lines/:id
POST /api/lines/:id/suspend
POST /api/lines/:id/resume
POST /api/lines/:id/dispatch
GET  /api/lines/:line_id/stations
POST /api/lines/:line_id/stations/:id/raise_alert
POST /api/lines/:line_id/stations/:id/clear_alert
GET  /api/lines/:line_id/cars
POST /api/cars/:id/dispatch
GET  /api/lines/:line_id/incidents
POST /api/lines/:line_id/incidents
GET  /api/incidents/:id
PATCH /api/incidents/:id
POST /api/incidents/:id/resolve
GET  /api/incidents/:incident_id/incident_comments
POST /api/incidents/:incident_id/incident_comments
GET  /api/lines/:line_id/operation_events
GET  /api/schema/:id
```

Validation errors use:

```json
{ "errors": { "title": ["Title can't be blank"] } }
```

## Tests

```sh
bin/rails test
```

The test suite covers models, services, request APIs, and `LineChannel`.

## Future Extensions

- Weather and passenger-satisfaction events.
- Operator chat.
- Daily Markdown/PDF reports.
- A score-based game mode.
