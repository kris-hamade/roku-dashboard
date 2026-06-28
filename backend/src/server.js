import 'dotenv/config';
import express from 'express';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const circuitImageCache = new Map();

const config = {
  port: Number(process.env.PORT || 3000),
  timezone: process.env.TIMEZONE || 'America/Detroit',
  weatherLocation: process.env.WEATHER_LOCATION || 'White Lake, MI',
  weatherLatitude: Number(process.env.WEATHER_LATITUDE || 42.6389),
  weatherLongitude: Number(process.env.WEATHER_LONGITUDE || -83.5033),
  blizzardClientId: process.env.BLIZZARD_CLIENT_ID || '',
  blizzardClientSecret: process.env.BLIZZARD_CLIENT_SECRET || '',
  wowRegion: process.env.WOW_REGION || 'us',
  wowRealmSlugs: parseCsv(process.env.WOW_REALM_SLUGS || process.env.WOW_REALM_SLUG || 'illidan,misha,sargeras'),
  f1ScheduleFile: process.env.F1_SCHEDULE_FILE || './data/f1-2026.json'
};

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.get('/api/dashboard', async (req, res) => {
  const now = new Date();
  const assetBaseUrl = `${req.protocol}://${req.get('host')}`;

  const [weather, wow, f1] = await Promise.all([
    getWeather().catch(error => fallbackWeather(error)),
    getWowStatuses().catch(error => fallbackWow(error)),
    getNextF1Session(now, assetBaseUrl).catch(error => fallbackF1(error))
  ]);

  res.json({
    time: {
      timezone: config.timezone,
      iso: now.toISOString(),
      display: formatTime(now)
    },
    weather,
    wow,
    f1
  });
});

app.get('/assets/circuit/:slug.png', async (req, res) => {
  const slug = req.params.slug.replace(/[^a-z0-9_-]/gi, '');
  if (!slug) {
    res.status(404).send('Not found');
    return;
  }

  try {
    const image = await getCircuitImage(slug);
    res.setHeader('Content-Type', image.contentType);
    res.setHeader('Cache-Control', 'public, max-age=14400');
    res.send(image.buffer);
  } catch (error) {
    console.warn(`Circuit image unavailable for ${slug}:`, error.message);
    res.status(502).send('Circuit image unavailable');
  }
});

app.listen(config.port, () => {
  console.log(`HomeBoard backend listening on http://localhost:${config.port}`);
});

async function getWeather() {
  const params = new URLSearchParams({
    latitude: config.weatherLatitude.toString(),
    longitude: config.weatherLongitude.toString(),
    current: 'temperature_2m,weather_code,is_day',
    daily: 'temperature_2m_max,temperature_2m_min',
    temperature_unit: 'fahrenheit',
    timezone: config.timezone,
    forecast_days: '1'
  });

  const response = await fetch(`https://api.open-meteo.com/v1/forecast?${params}`);
  if (!response.ok) throw new Error(`Open-Meteo returned ${response.status}`);

  const data = await response.json();
  const isDay = data.current?.is_day === 1;
  const moon = getMoonPhase(new Date());

  return {
    location: config.weatherLocation,
    tempF: Math.round(data.current?.temperature_2m),
    condition: weatherCodeToCondition(data.current?.weather_code),
    highF: Math.round(data.daily?.temperature_2m_max?.[0]),
    lowF: Math.round(data.daily?.temperature_2m_min?.[0]),
    icon: weatherCodeToIcon(data.current?.weather_code, isDay, moon.icon),
    isDay,
    moonPhase: moon
  };
}

function fallbackWeather(error) {
  console.warn('Weather unavailable:', error.message);
  return {
    location: config.weatherLocation,
    tempF: null,
    condition: 'Data unavailable',
    highF: null,
    lowF: null,
    icon: 'unknown',
    isDay: null,
    moonPhase: getMoonPhase(new Date())
  };
}

async function getWowStatuses() {
  if (!config.blizzardClientId || !config.blizzardClientSecret) {
    return unavailableWow('Missing Blizzard credentials');
  }

  const token = await getBlizzardToken();
  const realms = await Promise.all(config.wowRealmSlugs.map(slug => getWowRealmStatus(slug, token)));

  return {
    region: config.wowRegion,
    realms
  };
}

async function getWowRealmStatus(realmSlug, token) {
  const namespace = `dynamic-${config.wowRegion}`;
  const baseUrl = `https://${config.wowRegion}.api.blizzard.com`;
  const realmUrl = new URL(`/data/wow/realm/${realmSlug}`, baseUrl);
  realmUrl.searchParams.set('namespace', namespace);
  realmUrl.searchParams.set('locale', 'en_US');

  const realm = await blizzardJson(realmUrl, token);
  const connectedRealmUrl = new URL(realm.connected_realm.href);
  connectedRealmUrl.searchParams.set('namespace', namespace);
  connectedRealmUrl.searchParams.set('locale', 'en_US');

  const connectedRealm = await blizzardJson(connectedRealmUrl, token);
  const matchingRealm = connectedRealm.realms?.find(realmItem => realmItem.slug === realmSlug);

  return {
    realm: matchingRealm?.name || realm.name || realmSlug,
    slug: realmSlug,
    region: config.wowRegion,
    status: normalizeWowStatus(connectedRealm.status?.type),
    population: connectedRealm.population?.type?.toLowerCase() || 'unknown'
  };
}

function normalizeWowStatus(statusType) {
  const status = statusType?.toLowerCase() || 'unknown';
  if (status === 'up') return 'online';
  if (status === 'down') return 'offline';
  return status;
}

function unavailableWow(reason) {
  return {
    region: config.wowRegion,
    error: reason,
    realms: config.wowRealmSlugs.map(slug => ({
      realm: slug,
      slug,
      region: config.wowRegion,
      status: 'unavailable',
      population: 'unknown'
    }))
  };
}

function fallbackWow(error) {
  console.warn('WoW unavailable:', error.message);
  return unavailableWow(error.message);
}

async function getBlizzardToken() {
  const tokenUrl = `https://${config.wowRegion}.battle.net/oauth/token`;
  const body = new URLSearchParams({ grant_type: 'client_credentials' });
  const credentials = Buffer.from(`${config.blizzardClientId}:${config.blizzardClientSecret}`).toString('base64');

  const response = await fetch(tokenUrl, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body
  });

  if (!response.ok) throw new Error(`Battle.net OAuth returned ${response.status}`);
  const data = await response.json();
  return data.access_token;
}

async function blizzardJson(url, token) {
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
  if (!response.ok) throw new Error(`Blizzard API returned ${response.status}`);
  return response.json();
}

async function getNextF1Session(now, assetBaseUrl) {
  const schedulePath = path.resolve(__dirname, '..', config.f1ScheduleFile);
  const schedule = JSON.parse(await readFile(schedulePath, 'utf8'));
  const upcoming = schedule.sessions
    .map(session => ({ ...session, startsAt: new Date(session.date) }))
    .filter(session => session.startsAt > now)
    .sort((a, b) => a.startsAt - b.startsAt)[0];

  if (!upcoming) {
    return {
      nextRace: 'Season complete',
      session: 'Race',
      date: null,
      countdown: 'No upcoming races'
    };
  }

  return {
    nextRace: upcoming.race,
    session: upcoming.session,
    date: upcoming.startsAt.toISOString(),
    countdown: formatCountdown(upcoming.startsAt - now),
    country: upcoming.country || '',
    circuit: upcoming.circuit || '',
    circuitSlug: upcoming.circuitSlug || '',
    circuitImage: upcoming.circuitSlug ? `${assetBaseUrl}/assets/circuit/${upcoming.circuitSlug}.png` : '',
    circuitLocation: upcoming.circuitLocation || '',
    circuitLengthKm: upcoming.circuitLengthKm || null,
    laps: upcoming.laps || null,
    trackPoints: upcoming.trackPoints || [],
    qualifyingTop3: upcoming.qualifyingTop3 || [],
    weekendAfter: getWeekendAfter(schedule.sessions, upcoming, now)
  };
}

function fallbackF1(error) {
  console.warn('F1 unavailable:', error.message);
  return {
    nextRace: 'Data unavailable',
    session: 'Race',
    date: null,
    countdown: 'Data unavailable',
    country: '',
    circuit: '',
    circuitSlug: '',
    circuitImage: '',
    circuitLocation: '',
    circuitLengthKm: null,
    laps: null,
    trackPoints: [],
    qualifyingTop3: [],
    weekendAfter: null
  };
}

function formatTime(date) {
  return new Intl.DateTimeFormat('en-US', {
    timeZone: config.timezone,
    hour: 'numeric',
    minute: '2-digit'
  }).format(date);
}

function formatCountdown(ms) {
  const totalMinutes = Math.max(0, Math.floor(ms / 60000));
  const days = Math.floor(totalMinutes / 1440);
  const hours = Math.floor((totalMinutes % 1440) / 60);
  const minutes = totalMinutes % 60;

  if (days > 0) return `${days}d ${hours}h ${minutes}m`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

function weatherCodeToCondition(code) {
  const conditions = {
    0: 'Clear',
    1: 'Mostly clear',
    2: 'Partly cloudy',
    3: 'Cloudy',
    45: 'Fog',
    48: 'Rime fog',
    51: 'Light drizzle',
    53: 'Drizzle',
    55: 'Heavy drizzle',
    61: 'Light rain',
    63: 'Rain',
    65: 'Heavy rain',
    71: 'Light snow',
    73: 'Snow',
    75: 'Heavy snow',
    80: 'Light showers',
    81: 'Showers',
    82: 'Heavy showers',
    95: 'Thunderstorm'
  };

  return conditions[code] || 'Unknown';
}

async function getCircuitImage(slug) {
  const cached = circuitImageCache.get(slug);
  if (cached && cached.expiresAt > Date.now()) return cached;

  const sourceUrl = `https://formula-timer.com/_next/image?url=%2Fcircuits%2F${encodeURIComponent(slug)}.png&w=1920&q=75`;
  const response = await fetch(sourceUrl, {
    headers: {
      Accept: 'image/png,image/*'
    }
  });

  if (!response.ok) throw new Error(`Formula Timer returned ${response.status}`);

  const image = {
    buffer: Buffer.from(await response.arrayBuffer()),
    contentType: response.headers.get('content-type') || 'image/png',
    expiresAt: Date.now() + 4 * 60 * 60 * 1000
  };

  circuitImageCache.set(slug, image);
  return image;
}

function weatherCodeToIcon(code, isDay, moonIcon) {
  if ([0, 1].includes(code)) return isDay ? 'sun' : moonIcon;
  if ([45, 48].includes(code)) return 'fog';
  if ([2, 3].includes(code)) return 'cloud';
  if ([51, 53, 55, 61, 63, 65, 80, 81, 82].includes(code)) return 'rain';
  if ([71, 73, 75].includes(code)) return 'snow';
  if ([95].includes(code)) return 'storm';
  return 'unknown';
}

function getMoonPhase(date) {
  const synodicMonth = 29.530588853;
  const knownNewMoon = Date.UTC(2000, 0, 6, 18, 14, 0);
  const daysSince = (date.getTime() - knownNewMoon) / 86400000;
  const age = ((daysSince % synodicMonth) + synodicMonth) % synodicMonth;
  const fraction = age / synodicMonth;
  const illumination = Math.round(((1 - Math.cos(2 * Math.PI * fraction)) / 2) * 100);

  let name = 'New Moon';
  let icon = 'moon-new';

  if (fraction >= 0.03 && fraction < 0.22) {
    name = 'Waxing Crescent';
    icon = 'moon-waxing-crescent';
  } else if (fraction >= 0.22 && fraction < 0.28) {
    name = 'First Quarter';
    icon = 'moon-first-quarter';
  } else if (fraction >= 0.28 && fraction < 0.47) {
    name = 'Waxing Gibbous';
    icon = 'moon-waxing-gibbous';
  } else if (fraction >= 0.47 && fraction < 0.53) {
    name = 'Full Moon';
    icon = 'moon-full';
  } else if (fraction >= 0.53 && fraction < 0.72) {
    name = 'Waning Gibbous';
    icon = 'moon-waning-gibbous';
  } else if (fraction >= 0.72 && fraction < 0.78) {
    name = 'Last Quarter';
    icon = 'moon-last-quarter';
  } else if (fraction >= 0.78 && fraction < 0.97) {
    name = 'Waning Crescent';
    icon = 'moon-waning-crescent';
  }

  return {
    name,
    icon,
    illumination,
    ageDays: Number(age.toFixed(1))
  };
}

function getWeekendAfter(sessions, upcoming, now) {
  const next = sessions
    .map(session => ({ ...session, startsAt: new Date(session.date) }))
    .filter(session => session.startsAt > now && session.race !== upcoming.race)
    .sort((a, b) => a.startsAt - b.startsAt)[0];

  if (!next) return null;

  return {
    nextRace: next.race,
    session: next.session,
    date: next.startsAt.toISOString(),
    countdown: formatCountdown(next.startsAt - now),
    country: next.country || '',
    circuit: next.circuit || ''
  };
}

function parseCsv(value) {
  return value
    .split(',')
    .map(item => item.trim())
    .filter(Boolean);
}
