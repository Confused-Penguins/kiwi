#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>

const char* AP_SSID = "Railway_Free_WiFi";

IPAddress apIP(192, 168, 4, 1);
IPAddress gateway(192, 168, 4, 1);
IPAddress subnet(255, 255, 255, 0);

DNSServer dnsServer;
WebServer server(80);

const byte DNS_PORT = 53;
const int MAX_RECORDS = 20;

// Synthetic demonstration records only.
struct DemoRecord {
  String aadhaar;
  String pnr;
  String phone;
  String ticket;
  String timestamp;
};

DemoRecord records[MAX_RECORDS];
int recordCount = 0;

String escapeHTML(String s) {
  s.replace("&", "&amp;");
  s.replace("<", "&lt;");
  s.replace(">", "&gt;");
  s.replace("\"", "&quot;");
  s.replace("'", "&#39;");
  return s;
}

// ESP32 has no real clock in this offline AP-only demo.
// This timestamp records elapsed time since the ESP32 was powered on.
String timestampNow() {
  unsigned long total = millis() / 1000UL;
  unsigned long hours = total / 3600UL;
  unsigned long minutes = (total % 3600UL) / 60UL;
  unsigned long seconds = total % 60UL;

  char buf[24];
  snprintf(buf, sizeof(buf), "T+%02lu:%02lu:%02lu",
           hours, minutes, seconds);
  return String(buf);
}

String portalPage() {
  return R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RailConnect Wi-Fi</title>
<style>
*{box-sizing:border-box}
body{margin:0;font-family:Arial,Helvetica,sans-serif;background:#f5f7fa;color:#18212f}
.top{height:6px;background:#0b6b57}
.nav{height:70px;background:#fff;border-bottom:1px solid #e6e9ee;display:flex;align-items:center;padding:0 7%;justify-content:space-between}
.brand{display:flex;align-items:center;gap:12px;font-weight:800;color:#123d35;font-size:20px}
.mark{width:38px;height:38px;border-radius:10px;background:#0b6b57;color:#fff;display:grid;place-items:center;font-weight:900}
.secure{font-size:12px;color:#547066;background:#eef7f4;padding:8px 12px;border-radius:20px}
.wrap{max-width:1080px;margin:45px auto;padding:0 22px;display:grid;grid-template-columns:1fr 430px;gap:55px;align-items:center}
.hero h1{font-size:46px;line-height:1.08;margin:0 0 18px;letter-spacing:-1px}
.hero p{font-size:17px;line-height:1.7;color:#647080;max-width:560px}
.points{display:grid;gap:14px;margin-top:28px}
.point{display:flex;gap:12px;align-items:center;color:#475363;font-size:14px}
.tick{width:25px;height:25px;border-radius:50%;background:#e4f4ef;color:#0b6b57;display:grid;place-items:center;font-weight:bold}
.card{background:#fff;border:1px solid #e4e8ee;border-radius:18px;padding:30px;box-shadow:0 14px 45px rgba(20,35,50,.09)}
.card h2{margin:0;font-size:24px}
.sub{color:#788393;font-size:13px;margin:8px 0 23px;line-height:1.5}
label{display:block;font-size:12px;font-weight:700;color:#44505f;margin:16px 0 7px}
input{width:100%;padding:13px 14px;border:1px solid #d7dde5;border-radius:9px;font-size:14px;outline:none}
input:focus{border-color:#0b6b57;box-shadow:0 0 0 3px #e4f4ef}
button{width:100%;border:0;border-radius:9px;padding:14px;margin-top:22px;background:#0b6b57;color:#fff;font-weight:700;font-size:15px;cursor:pointer}
.notice{font-size:10px;color:#8a929e;text-align:center;margin-top:16px;line-height:1.5}
.footer{text-align:center;color:#9aa2ad;font-size:11px;padding:25px}
.demo{display:inline-block;background:#fff5dc;color:#7a5a16;padding:5px 9px;border-radius:5px;font-size:10px;font-weight:700;margin-bottom:12px}
@media(max-width:800px){.wrap{grid-template-columns:1fr;margin:25px auto}.hero{display:none}.nav{padding:0 20px}}
</style>
</head>
<body>
<div class="top"></div>
<div class="nav">
<div class="brand"><div class="mark">R</div>RailConnect</div>
<div class="secure">PUBLIC WI-FI ACCESS</div>
</div>

<div class="wrap">
<section class="hero">
<div class="demo">CYBERSECURITY LAB DEMO</div>
<h1>Stay connected<br>while you travel.</h1>
<p>Welcome to RailConnect passenger Wi-Fi. Complete the quick identity and journey verification to activate your complimentary connection.</p>
<div class="points">
<div class="point"><span class="tick">OK</span> Fast station connectivity</div>
<div class="point"><span class="tick">OK</span> Passenger journey verification</div>
<div class="point"><span class="tick">OK</span> Connection status available instantly</div>
</div>
</section>

<section class="card">
<h2>Activate Wi-Fi</h2>
<div class="sub">Enter the information shown on your <b>demo ticket</b> to continue.</div>
<form action="/connect" method="POST">
<label>Aadhaar / ID</label>
<input name="aadhaar" placeholder="1234-5678-9012" maxlength="20" required>
<label>PNR / Booking reference</label>
<input name="pnr" placeholder="DEMO123456" maxlength="20" required>
<label>Mobile number</label>
<input name="phone" placeholder="9999999999" maxlength="15" required>
<label>Ticket reference</label>
<input name="ticket" placeholder="DEMO-TICKET-001" maxlength="30" required>
<button type="submit">Verify &amp; Connect</button>
</form>
<div class="notice">CYBERSECURITY DEMONSTRATION<br>Use synthetic information only. No real identity data is required.</div>
</section>
</div>
<div class="footer">RailConnect Passenger Services | Demonstration Environment</div>
</body>
</html>
)rawliteral";
}

String successPage() {
  return R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RailConnect - Connected</title>
<style>
*{box-sizing:border-box}
body{margin:0;font-family:Arial,Helvetica,sans-serif;background:#f4f8f7;color:#17252a}
.top{height:6px;background:#0b6b57}
.nav{height:70px;background:#fff;border-bottom:1px solid #e5ebe8;display:flex;align-items:center;padding:0 7%;justify-content:space-between}
.brand{display:flex;align-items:center;gap:12px;font-weight:800;color:#123d35;font-size:20px}
.mark{width:38px;height:38px;border-radius:10px;background:#0b6b57;color:#fff;display:grid;place-items:center;font-weight:900}
.status{font-size:12px;color:#0b6b57;background:#e7f5f0;padding:8px 12px;border-radius:20px}
.main{max-width:720px;margin:70px auto;padding:0 22px;text-align:center}
.check{width:82px;height:82px;border-radius:50%;background:#dff3ec;color:#0b6b57;margin:auto;display:grid;place-items:center;font-size:24px;font-weight:800;box-shadow:0 0 0 12px #edf9f5}
h1{font-size:38px;margin:35px 0 10px}
.lead{color:#697680;font-size:16px}
.panel{margin-top:32px;background:#fff;border:1px solid #e0e8e4;border-radius:16px;padding:22px;text-align:left;box-shadow:0 10px 35px rgba(30,50,45,.07)}
.line{display:flex;justify-content:space-between;padding:13px 0;border-bottom:1px solid #edf0ef;font-size:14px}
.line:last-child{border:0}.label{color:#7b858d}.value{font-weight:700;color:#253139}
.bar{height:7px;background:#e8efec;border-radius:9px;margin-top:20px;overflow:hidden}
.fill{height:100%;width:100%;background:#0b6b57;border-radius:9px}
.small{font-size:11px;color:#89939a;margin-top:20px}
</style>
</head>
<body>
<div class="top"></div>
<div class="nav"><div class="brand"><div class="mark">R</div>RailConnect</div><div class="status">CONNECTED</div></div>
<div class="main">
<div class="check">OK</div>
<h1>You're connected</h1>
<p class="lead">Your passenger Wi-Fi session has been activated successfully.</p>
<div class="panel">
<div class="line"><span class="label">Network</span><span class="value">RailConnect Passenger Wi-Fi</span></div>
<div class="line"><span class="label">Session</span><span class="value">Active</span></div>
<div class="line"><span class="label">Connection</span><span class="value">Session established</span></div>
<div class="bar"><div class="fill"></div></div>
</div>
<p class="small">Cybersecurity lab demonstration | Synthetic data only</p>
</div>
</body>
</html>
)rawliteral";
}

String dashboardPage() {
  String html = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="3">
<title>RailGuard - Security Console</title>
<style>
*{box-sizing:border-box}
body{margin:0;background:#f4f6f8;color:#17212b;font-family:Arial,Helvetica,sans-serif}
.sidebar{position:fixed;left:0;top:0;bottom:0;width:225px;background:#15232a;color:#dbe5e8;padding:26px 18px}
.logo{font-size:19px;font-weight:800;color:#fff;display:flex;align-items:center;gap:10px;margin-bottom:45px}
.logoMark{width:34px;height:34px;background:#0b6b57;border-radius:9px;display:grid;place-items:center}
.section{font-size:11px;color:#91a1a9;margin:18px 10px 8px;text-transform:uppercase;letter-spacing:1px}
.item{padding:12px 13px;border-radius:8px;margin:5px 0;font-size:13px}
.active{background:#21383a;color:#fff}
.clearBtn{width:100%;border:1px solid #b94a4a;background:transparent;color:#ffb5b5;padding:11px;border-radius:8px;font-weight:700;cursor:pointer;margin-top:10px}
.clearBtn:hover{background:#572b2b}
.main{margin-left:225px;padding:28px 34px;max-width:1200px}
.topbar{display:flex;justify-content:space-between;align-items:center;margin-bottom:28px}
.title h1{margin:0;font-size:25px}.title p{margin:6px 0;color:#7b8790;font-size:13px}
.live{background:#e6f5f0;color:#0b6b57;border-radius:20px;padding:8px 13px;font-size:11px;font-weight:700}
.warning{background:#fff8e7;border:1px solid #f1dfae;padding:14px 17px;border-radius:10px;color:#71591b;font-size:12px;margin-bottom:23px}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:23px}
.stat{background:#fff;border:1px solid #e5e9ed;border-radius:12px;padding:20px}
.stat .k{font-size:11px;color:#89939c;text-transform:uppercase;letter-spacing:.7px}.stat .v{font-size:27px;font-weight:800;margin-top:8px}.stat .s{font-size:11px;color:#6e7982;margin-top:5px}
.panel{background:#fff;border:1px solid #e5e9ed;border-radius:12px;padding:22px}
.panel h2{font-size:17px;margin:0}.panel .desc{font-size:11px;color:#8a949c;margin:6px 0 20px}
.table{border:1px solid #e8ecef;border-radius:9px;overflow:auto}
.row{display:grid;grid-template-columns:1.2fr 1.4fr 1fr 1.2fr 0.8fr;padding:13px 15px;font-size:12px;border-bottom:1px solid #edf0f2;min-width:700px}
.row:last-child{border:0}.head{background:#f8fafb;color:#818c95;font-weight:700}
.badge{display:inline-block;padding:4px 7px;border-radius:12px;background:#e6f5f0;color:#0b6b57;font-size:10px;font-weight:700}
.empty{padding:35px;text-align:center;color:#8b959d;font-size:13px}
.kv{display:flex;justify-content:space-between;padding:13px 0;border-bottom:1px solid #edf0f2;font-size:12px}.kv:last-child{border:0}.kv span:first-child{color:#8a949c}
.security{background:#15232a;color:#dce7ea;border-radius:10px;padding:17px;font-size:12px;line-height:1.7;margin-top:17px}
@media(max-width:850px){.sidebar{display:none}.main{margin-left:0}.cards{grid-template-columns:1fr}.row{min-width:700px}}
</style>
</head>
<body>

<aside class="sidebar">
<div class="logo"><div class="logoMark">R</div>RailGuard</div>
<div class="section">Monitoring</div>
<div class="item active">Live submissions</div>
<div class="section">History</div>
<form action="/clear" method="POST" onsubmit="return confirm('Clear all demonstration history?');">
<button class="clearBtn" type="submit">Clear History</button>
</form>
</aside>

<main class="main">
<div class="topbar">
<div class="title"><h1>Security Console</h1><p>ESP32 captive-portal awareness demonstration</p></div>
<div class="live">LIVE | REFRESH 3s</div>
</div>

<div class="warning">
<b>DEMONSTRATION MODE</b> - Synthetic values only. Records are stored temporarily in ESP32 RAM and can be removed with Clear History.
</div>

<div class="cards">
<div class="stat"><div class="k">Network</div><div class="v">OPEN</div><div class="s">Railway_Free_WiFi</div></div>
<div class="stat"><div class="k">Submissions</div><div class="v">)rawliteral";
  html += String(recordCount);
  html += R"rawliteral(</div><div class="s">Stored in device RAM</div></div>
<div class="stat"><div class="k">Connected devices</div><div class="v">)rawliteral";
  html += String(WiFi.softAPgetStationNum());
  html += R"rawliteral(</div><div class="s">Maximum 8 devices</div></div>
</div>

<section class="panel">
<h2>Submission history</h2>
<div class="desc">Each synthetic test submission is recorded with the ESP32 elapsed-time timestamp.</div>
<div class="table">
<div class="row head">
<span>Time</span><span>Field</span><span>Value</span><span>Category</span><span>Status</span>
</div>
)rawliteral";

  if (recordCount == 0) {
    html += R"rawliteral(
<div class="empty">No demonstration submissions recorded.<br><br>Waiting for a synthetic test submission...</div>
)rawliteral";
  } else {
    for (int i = recordCount - 1; i >= 0; i--) {
      html += "<div class='row'><span>" + escapeHTML(records[i].timestamp) + "</span><span>Aadhaar / ID</span><span>" + escapeHTML(records[i].aadhaar) + "</span><span>Demo credential</span><span><b class='badge'>DEMO</b></span></div>";
      html += "<div class='row'><span>" + escapeHTML(records[i].timestamp) + "</span><span>PNR</span><span>" + escapeHTML(records[i].pnr) + "</span><span>Demo credential</span><span><b class='badge'>DEMO</b></span></div>";
      html += "<div class='row'><span>" + escapeHTML(records[i].timestamp) + "</span><span>Mobile</span><span>" + escapeHTML(records[i].phone) + "</span><span>Demo credential</span><span><b class='badge'>DEMO</b></span></div>";
      html += "<div class='row'><span>" + escapeHTML(records[i].timestamp) + "</span><span>Ticket</span><span>" + escapeHTML(records[i].ticket) + "</span><span>Demo credential</span><span><b class='badge'>DEMO</b></span></div>";
    }
  }

  html += R"rawliteral(
</div>
</section>

<div style="height:18px"></div>

<section class="panel">
<h2>Network overview</h2>
<div class="desc">Local demonstration environment</div>
<div class="kv"><span>SSID</span><b>Railway_Free_WiFi</b></div>
<div class="kv"><span>Security</span><b>OPEN</b></div>
<div class="kv"><span>Gateway</span><b>192.168.4.1</b></div>
<div class="kv"><span>DNS redirect</span><b>ACTIVE</b></div>
<div class="kv"><span>External upload</span><b>NONE</b></div>
<div class="kv"><span>Storage</span><b>ESP32 RAM</b></div>
<div class="security">The purpose of this demonstration is to show why an unknown public Wi-Fi captive portal should not be trusted with sensitive information. Use synthetic data only.</div>
</section>

</main>
</body>
</html>
)rawliteral";

  return html;
}

void handleRoot() {
  server.send(200, "text/html", portalPage());
}

void handleConnect() {
  if (server.hasArg("aadhaar") && server.hasArg("pnr") &&
      server.hasArg("phone") && server.hasArg("ticket")) {

    if (recordCount < MAX_RECORDS) {
      records[recordCount].aadhaar = server.arg("aadhaar");
      records[recordCount].pnr = server.arg("pnr");
      records[recordCount].phone = server.arg("phone");
      records[recordCount].ticket = server.arg("ticket");
      records[recordCount].timestamp = timestampNow();
      recordCount++;
    } else {
      // Keep the newest 20 records.
      for (int i = 1; i < MAX_RECORDS; i++) {
        records[i - 1] = records[i];
      }
      records[MAX_RECORDS - 1].aadhaar = server.arg("aadhaar");
      records[MAX_RECORDS - 1].pnr = server.arg("pnr");
      records[MAX_RECORDS - 1].phone = server.arg("phone");
      records[MAX_RECORDS - 1].ticket = server.arg("ticket");
      records[MAX_RECORDS - 1].timestamp = timestampNow();
    }

    Serial.println();
    Serial.println("===== SYNTHETIC DEMO SUBMISSION =====");
    Serial.println("Timestamp : " + records[recordCount < MAX_RECORDS ? recordCount - 1 : MAX_RECORDS - 1].timestamp);
    Serial.println("Aadhaar/ID: " + server.arg("aadhaar"));
    Serial.println("PNR       : " + server.arg("pnr"));
    Serial.println("Phone     : " + server.arg("phone"));
    Serial.println("Ticket    : " + server.arg("ticket"));
    Serial.println("======================================");
  }

  server.send(200, "text/html", successPage());
}

void handleDashboard() {
  server.send(200, "text/html", dashboardPage());
}

void handleClear() {
  for (int i = 0; i < MAX_RECORDS; i++) {
    records[i].aadhaar = "";
    records[i].pnr = "";
    records[i].phone = "";
    records[i].ticket = "";
    records[i].timestamp = "";
  }
  recordCount = 0;

  Serial.println("Demo history cleared.");
  server.sendHeader("Location", "/dashboard", true);
  server.send(303, "text/plain", "History cleared");
}

void handleCaptivePortal() {
  server.sendHeader("Location", "http://192.168.4.1/", true);
  server.send(302, "text/plain", "");
}

void handleNotFound() {
  server.sendHeader("Location", "http://192.168.4.1/", true);
  server.send(302, "text/plain", "");
}

void setup() {
  Serial.begin(115200);
  delay(800);

  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(apIP, gateway, subnet);

  // Open Wi-Fi with up to 8 simultaneous clients.
  WiFi.softAP(AP_SSID, NULL, 1, false, 8);

  delay(800);

  dnsServer.start(DNS_PORT, "*", apIP);

  server.on("/", HTTP_GET, handleRoot);
  server.on("/connect", HTTP_POST, handleConnect);
  server.on("/dashboard", HTTP_GET, handleDashboard);
  server.on("/clear", HTTP_POST, handleClear);

  server.on("/generate_204", HTTP_GET, handleCaptivePortal);
  server.on("/hotspot-detect.html", HTTP_GET, handleCaptivePortal);
  server.on("/connecttest.txt", HTTP_GET, handleCaptivePortal);
  server.on("/ncsi.txt", HTTP_GET, handleCaptivePortal);

  server.onNotFound(handleNotFound);
  server.begin();

  Serial.println();
  Serial.println("========================================");
  Serial.println("RAILCONNECT SECURITY DEMO READY");
  Serial.println("========================================");
  Serial.println("SSID          : Railway_Free_WiFi");
  Serial.println("Security      : OPEN / NO PASSWORD");
  Serial.println("Max clients   : 8");
  Serial.println("Portal        : http://192.168.4.1/");
  Serial.println("Dashboard     : http://192.168.4.1/dashboard");
  Serial.println("Clear history : Dashboard -> Clear History");
  Serial.println("Timestamp     : ESP32 uptime T+HH:MM:SS");
  Serial.println("========================================");
}

void loop() {
  dnsServer.processNextRequest();
  server.handleClient();
}
