# HomeBoard

HomeBoard is a Roku SceneGraph/BrightScript screensaver backed by a small Node.js/Express API. The Roku app calls one endpoint, `/api/dashboard`, and the backend aggregates weather, current time, World of Warcraft realm status, and Formula 1 race countdown data.

## Project Tree

```text
.
├── Makefile
├── README.md
├── config.json
├── manifest
├── package.json
├── source
│   └── main.brs
├── components
│   ├── DashboardTask.brs
│   ├── DashboardTask.xml
│   ├── HomeBoardScene.brs
│   └── HomeBoardScene.xml
├── images
│   └── backgrounds
│       ├── city-night.png
│       └── mountain-lake.png
└── backend
    ├── .env.example
    ├── package.json
    ├── data
    │   └── f1-2026.json
    └── src
        └── server.js
```

## Backend Setup

Requires Node.js 18 or newer.

```sh
npm run backend:install
cp backend/.env.example backend/.env
npm run backend:dev
```

The API will run at:

```text
http://localhost:3000/api/dashboard
```

For Roku hardware, `localhost` is the Roku device itself, not your computer. Set `BACKEND_URL` in `config.json` to your computer or server LAN address:

```json
{
  "BACKEND_URL": "http://192.168.1.25:3000/api/dashboard"
}
```

## Environment Variables

Create `backend/.env` from `backend/.env.example`.

```sh
PORT=3000
TIMEZONE=America/Detroit
WEATHER_LOCATION=White Lake, MI
WEATHER_LATITUDE=42.6389
WEATHER_LONGITUDE=-83.5033

BLIZZARD_CLIENT_ID=
BLIZZARD_CLIENT_SECRET=
WOW_REGION=us
WOW_REALM_SLUGS=illidan,misha,sargeras

F1_SCHEDULE_FILE=./data/f1-2026.json
```

Weather uses Open-Meteo and latitude/longitude config. WoW uses Blizzard Battle.net OAuth client credentials. If `BLIZZARD_CLIENT_ID` and `BLIZZARD_CLIENT_SECRET` are missing, the API returns your configured realms with `status: "unavailable"` instead of fake online data.

The F1 schedule is intentionally lightweight: edit `backend/data/f1-2026.json` when the calendar, race start times, track outline points, or qualifying top three change.

Circuit images are proxied by the backend from Formula Timer. The Roku scene receives a backend URL such as `/assets/circuit/red_bull_ring.png`, keeping external image fetching out of the Roku app.

## Roku Screensaver

This is a screensaver package, not just a normal channel. `source/main.brs` implements `RunScreenSaver()` and creates the SceneGraph scene in the screensaver BrightScript context. No channel state is required.

The Roku UI:

- Rotating dark scenic/cityscape backgrounds
- Large local clock updated every second
- Flat weather icons based on current conditions, including moon phase icons at night
- F1 hero panel with countdown, next weekend hint, circuit name, real circuit image, and qualifying top three when present
- Rotating WoW realm row for Illidan, Misha, and Sargeras by default
- Backend polling every 5 minutes
- Graceful “Data unavailable” state if the backend request fails

## Sideload to Roku Developer Mode

1. Enable Developer Mode on your Roku.
2. Note the Roku IP address and developer password.
3. Update `config.json` with your backend URL reachable from the Roku.
4. Start the backend:

```sh
npm run backend:dev
```

5. Zip and deploy:

```sh
make deploy ROKU_DEV_TARGET=192.168.1.50 ROKU_DEV_PASSWORD='your-password'
```

You can create the sideload zip without deploying:

```sh
make zip
```

The zip will be written to `build/homeboard.zip`.

## npm Scripts

```sh
npm run backend:install
npm run backend:dev
npm run backend:start
npm run zip
npm run deploy -- ROKU_DEV_TARGET=192.168.1.50 ROKU_DEV_PASSWORD='your-password'
```

For `npm run deploy`, passing Make variables through npm can be shell-dependent. If it is fussy, use `make deploy ...` directly.

## Backend Container

The backend can be built as a container from `backend/Dockerfile`.

```sh
docker build -t homeboard-backend ./backend
docker run --env-file backend/.env -p 3000:3000 homeboard-backend
```

GitHub Actions publishes the backend image to GitHub Container Registry on pushes to `main` that touch backend files:

```text
ghcr.io/OWNER/REPO/homeboard-backend:latest
ghcr.io/OWNER/REPO/homeboard-backend:sha-...
```

## API Shape

`GET /api/dashboard`

```json
{
  "time": {
    "timezone": "America/Detroit",
    "iso": "2026-06-26T05:24:00.000Z",
    "display": "1:24 AM"
  },
  "weather": {
    "location": "White Lake, MI",
    "tempF": 72,
    "condition": "Cloudy",
    "highF": 80,
    "lowF": 64,
    "icon": "moon-waxing-gibbous",
    "isDay": false,
    "moonPhase": {
      "name": "Waxing Gibbous",
      "illumination": 97,
      "ageDays": 13
    }
  },
  "wow": {
    "region": "us",
    "realms": [
      {
        "realm": "Illidan",
        "slug": "illidan",
        "region": "us",
        "status": "online",
        "population": "full"
      }
    ]
  },
  "f1": {
    "nextRace": "Austrian Grand Prix",
    "session": "Race",
    "date": "2026-06-28T13:00:00.000Z",
    "countdown": "6h 17m",
    "country": "Austria",
    "circuit": "Red Bull Ring",
    "circuitSlug": "red_bull_ring",
    "circuitImage": "http://192.168.1.55:3000/assets/circuit/red_bull_ring.png",
    "trackType": "short alpine power circuit",
    "trackPoints": [[19, 60], [33, 35]],
    "qualifyingTop3": [
      {
        "position": 1,
        "driver": "George Russell",
        "team": "Mercedes",
        "time": "1:06.113"
      }
    ],
    "weekendAfter": {
      "nextRace": "British Grand Prix",
      "countdown": "7d 7h 17m"
    }
  }
}
```

## Troubleshooting

- If Roku shows “Data unavailable”, open `http://YOUR_BACKEND_HOST:3000/api/dashboard` from another device on the same network.
- Make sure your computer firewall allows inbound connections to the backend port.
- Do not use `localhost` in `config.json` for a physical Roku.
- If Blizzard credentials are absent, WoW realms will show `unavailable`. Add Battle.net API credentials to `backend/.env` and restart the backend for real realm status.
- Blizzard realm and connected-realm calls use `Authorization: Bearer ...`. Passing the token as an `access_token` query parameter can produce 404s on connected-realm requests.
- If weather is unavailable, confirm `WEATHER_LATITUDE`, `WEATHER_LONGITUDE`, and internet access from the backend host.
- If the F1 countdown, circuit image, or qualifying order looks wrong, update `backend/data/f1-2026.json`; it is the source of truth for this first version.

## Blizzard Credentials

Create a Blizzard API client in the Battle.net developer portal, then set:

```sh
BLIZZARD_CLIENT_ID=your-client-id
BLIZZARD_CLIENT_SECRET=your-client-secret
WOW_REGION=us
WOW_REALM_SLUGS=illidan,misha,sargeras
```

Restart the backend after editing `backend/.env`.
