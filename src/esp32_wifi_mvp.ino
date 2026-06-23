#include <WiFi.h>
#include <WebServer.h>

// AP credentials
const char* ssid = "Sendex-ESP32";
const char* password = "sendex123";

WebServer server(80);

// Simulated GPS data
double lat = 48.856600;
double lng = 2.352200;
double speed = 0.0;
double totalDistance = 0.0;
double prevLat = lat, prevLng = lng;
unsigned long lastUpdate = 0;

void setup() {
  Serial.begin(115200);

  WiFi.softAP(ssid, password);
  Serial.print("AP IP: ");
  Serial.println(WiFi.softAPIP());

  server.on("/", handleRoot);
  server.on("/data", handleData);

  server.begin();
  Serial.println("Server started");
}

void loop() {
  server.handleClient();
  updateSimulatedGps();
}

void updateSimulatedGps() {
  if (millis() - lastUpdate < 1000) return;
  lastUpdate = millis();

  speed = random(0, 30) / 10.0; // 0.0 - 3.0 km/h
  lat += (random(-100, 100) / 1000000.0);
  lng += (random(-100, 100) / 1000000.0);

  double dist = sqrt(pow((lat - prevLat) * 111320.0, 2) + pow((lng - prevLng) * 111320.0 * cos(lat * 0.0174533), 2));
  totalDistance += dist;
  prevLat = lat;
  prevLng = lng;
}

void handleRoot() {
  String html = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" name="viewport" content="width=device-width,initial-scale=1">
  <title>Sendex</title>
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { font-family:-apple-system,system-ui,sans-serif; background:#0d1117; color:#c9d1d9; display:flex; justify-content:center; padding:20px; }
    .card { background:#161b22; border-radius:16px; padding:24px; width:100%; max-width:400px; border:1px solid #30363d; }
    h1 { font-size:22px; margin-bottom:20px; color:#58a6ff; }
    .row { display:flex; justify-content:space-between; padding:10px 0; border-bottom:1px solid #21262d; }
    .row:last-child { border-bottom:none; }
    .label { color:#8b949e; }
    .value { font-weight:600; font-variant-numeric:tabular-nums; }
    .badge { display:inline-block; background:#238636; color:#fff; padding:4px 12px; border-radius:20px; font-size:12px; margin-top:16px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>&#127934; Sendex Live</h1>
    <div id="data">
      <div class="row"><span class="label">Latitude</span><span class="value" id="lat">--</span></div>
      <div class="row"><span class="label">Longitude</span><span class="value" id="lng">--</span></div>
      <div class="row"><span class="label">Speed</span><span class="value" id="speed">--</span></div>
      <div class="row"><span class="label">Total Distance</span><span class="value" id="dist">--</span></div>
      <div class="row"><span class="label">Satellites</span><span class="value" id="sats">--</span></div>
      <div class="row"><span class="label">Time</span><span class="value" id="time">--</span></div>
    </div>
    <div class="badge">&#9679; LIVE</div>
  </div>
  <script>
    async function fetchData() {
      try {
        const r = await fetch('/data');
        const d = await r.json();
        document.getElementById('lat').textContent = d.lat.toFixed(6);
        document.getElementById('lng').textContent = d.lng.toFixed(6);
        document.getElementById('speed').textContent = d.speed + ' km/h';
        document.getElementById('dist').textContent = d.dist.toFixed(2) + ' m';
        document.getElementById('sats').textContent = d.sats;
        document.getElementById('time').textContent = d.time;
      } catch(e) {}
    }
    setInterval(fetchData, 1000);
    fetchData();
  </script>
</body>
</html>
)rawliteral";
  server.send(200, "text/html", html);
}

void handleData() {
  char buf[256];
  snprintf(buf, sizeof(buf),
    R"({"lat":%.6f,"lng":%.6f,"speed":%.1f,"dist":%.1f,"sats":%d,"time":"%s"})",
    lat, lng, speed, totalDistance, random(4, 12), "12:00:00");
  server.send(200, "application/json", buf);
}
