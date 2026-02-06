#include <ArduinoBLE.h>
#include <Arduino_BMI270_BMM150.h>
#include <Arduino_APDS9960.h>
#include <Arduino_HS300x.h>
#include <Arduino_LPS22HB.h>
#include <PDM.h>

BLEService uartService("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
BLECharacteristic rxChar("6E400002-B5A3-F393-E0A9-E50E24DCCA9E", BLEWrite | BLEWriteWithoutResponse, 244);
BLECharacteristic txChar("6E400003-B5A3-F393-E0A9-E50E24DCCA9E", BLENotify, 244);

const int LED_PIN = LED_BUILTIN;

// Flags de inicialização dos sensores
bool imuOK = false;
bool apdsOK = false;
bool hsOK = false;
bool baroOK = false;
bool pdmOK = false;

// ===== Áudio (PDM) =====
// buffer de samples (16-bit)
short sampleBuffer[256];

// número de amostras recebidas no callback
volatile int samplesRead = 0;

// última intensidade calculada (RMS e pico)
volatile float lastAudioRms = 0.0f;   // escala aproximada 0..1
volatile int   lastAudioPeak = 0;     // 0..32767
volatile bool  audioFresh = false;

void onPDMdata() {
  int bytesAvailable = PDM.available();
  if (bytesAvailable <= 0) return;

  if (bytesAvailable > (int)sizeof(sampleBuffer)) {
    bytesAvailable = sizeof(sampleBuffer);
  }

  PDM.read(sampleBuffer, bytesAvailable);
  samplesRead = bytesAvailable / 2; // 2 bytes por sample (16-bit)

  if (samplesRead <= 0) return;

  long long sumSq = 0;
  int peak = 0;

  for (int i = 0; i < samplesRead; i++) {
    int v = sampleBuffer[i];
    int av = (v >= 0) ? v : -v;
    if (av > peak) peak = av;
    sumSq += (long long)v * (long long)v;
  }

  float meanSq = (float)sumSq / (float)samplesRead;
  float rms = sqrt(meanSq) / 32768.0f;  // normaliza ~0..1

  lastAudioPeak = peak;
  lastAudioRms = rms;
  audioFresh = true;
}

void sendLine(const String &s) {
  txChar.writeValue((const uint8_t*)s.c_str(), s.length());
}

void sendGyroscope() {
  if (!imuOK) {
    sendLine("{\"type\":\"gyroscope\",\"error\":\"not_initialized\"}\n");
    return;
  }

  float x = 0.0f, y = 0.0f, z = 0.0f;
  if (IMU.gyroscopeAvailable()) {
    IMU.readGyroscope(x, y, z);

    String out = "{\"type\":\"gyroscope\",\"x\":";
    out += String(x, 4);
    out += ",\"y\":";
    out += String(y, 4);
    out += ",\"z\":";
    out += String(z, 4);
    out += "}\n";
    sendLine(out);
  } else {
    sendLine("{\"type\":\"gyroscope\",\"error\":\"unavailable\"}\n");
  }
}

void sendProximity() {
  if (!apdsOK) {
    sendLine("{\"type\":\"proximity\",\"error\":\"not_initialized\"}\n");
    return;
  }

  if (APDS.proximityAvailable()) {
    int proximity = APDS.readProximity(); // 0..255

    String out = "{\"type\":\"proximity\",\"value\":";
    out += String(proximity);
    out += "}\n";
    sendLine(out);
    Serial.println(out);
  } else {
    sendLine("{\"type\":\"proximity\",\"error\":\"unavailable\"}\n");
    Serial.println("{\"type\":\"proximity\",\"error\":\"unavailable\"}");
  }
}

void sendTemperature() {
  if (!hsOK) {
    sendLine("{\"type\":\"temperature\",\"error\":\"not_initialized\"}\n");
    return;
  }

  float t = HS300x.readTemperature();

  if (isnan(t)) {
    sendLine("{\"type\":\"temperature\",\"error\":\"unavailable\"}\n");
    return;
  }

  String out = "{\"type\":\"temperature\",\"c\":";
  out += String(t, 2);
  out += "}\n";
  sendLine(out);
}

void sendHumidity() {
  if (!hsOK) {
    sendLine("{\"type\":\"humidity\",\"error\":\"not_initialized\"}\n");
    return;
  }

  float h = HS300x.readHumidity();

  if (isnan(h)) {
    sendLine("{\"type\":\"humidity\",\"error\":\"unavailable\"}\n");
    return;
  }

  String out = "{\"type\":\"humidity\",\"rh\":";
  out += String(h, 2);
  out += "}\n";
  sendLine(out);
}

void sendPressure() {
  if (!baroOK) {
    sendLine("{\"type\":\"pressure\",\"error\":\"not_initialized\"}\n");
    return;
  }

  float p = BARO.readPressure(); // hPa (float)

  if (isnan(p)) {
    sendLine("{\"type\":\"pressure\",\"error\":\"unavailable\"}\n");
    return;
  }

  String out = "{\"type\":\"pressure\",\"hpa\":";
  out += String(p, 2);
  out += "}\n";
  sendLine(out);
}

// Envia ambiente em pacote único
void sendEnvironment() {
  if (!hsOK || !baroOK) {
    sendLine("{\"type\":\"environment\",\"error\":\"not_initialized\"}\n");
    return;
  }

  float t = HS300x.readTemperature();
  float h = HS300x.readHumidity();
  float p = BARO.readPressure();

  if (isnan(t) || isnan(h) || isnan(p)) {
    sendLine("{\"type\":\"environment\",\"error\":\"unavailable\"}\n");
    return;
  }

  String out = "{\"type\":\"environment\",\"c\":";
  out += String(t, 2);
  out += ",\"rh\":";
  out += String(h, 2);
  out += ",\"hpa\":";
  out += String(p, 2);
  out += "}\n";
  sendLine(out);
}

// Envia intensidade de áudio
// rms: 0..1 (aprox), level: 0..100, peak: 0..32767
void sendAudio() {
  if (!pdmOK) {
    sendLine("{\"type\":\"audio\",\"error\":\"not_initialized\"}\n");
    return;
  }

  // Se ainda não houve callback PDM
  if (!audioFresh && samplesRead == 0) {
    sendLine("{\"type\":\"audio\",\"error\":\"unavailable\"}\n");
    return;
  }

  float rms = lastAudioRms;
  if (rms < 0.0f) rms = 0.0f;
  if (rms > 1.0f) rms = 1.0f;

  int level = (int)(rms * 100.0f + 0.5f);
  if (level < 0) level = 0;
  if (level > 100) level = 100;

  int peak = lastAudioPeak;
  if (peak < 0) peak = 0;
  if (peak > 32767) peak = 32767;

  String out = "{\"type\":\"audio\",\"rms\":";
  out += String(rms, 4);
  out += ",\"level\":";
  out += String(level);
  out += ",\"peak\":";
  out += String(peak);
  out += "}\n";
  sendLine(out);
}

void handleRx() {
  if (!rxChar.written()) return;

  int len = rxChar.valueLength();
  if (len <= 0) return;

  uint8_t buf[245];
  if (len > 244) len = 244;
  rxChar.readValue(buf, len);

  String cmd = "";
  cmd.reserve(len);
  for (int i = 0; i < len; i++) cmd += (char)buf[i];
  cmd.trim();
  cmd.toUpperCase();

  if (cmd == "LED ON") {
    digitalWrite(LED_PIN, HIGH);
    sendLine("LED ON\n");

  } else if (cmd == "LED OFF") {
    digitalWrite(LED_PIN, LOW);
    sendLine("LED OFF\n");

  } else if (cmd == "GIROSCOPE" || cmd == "GYROSCOPE") {
    sendGyroscope();

  } else if (cmd == "PROXIMITY") {
    sendProximity();

  } else if (cmd == "TEMPERATURE" || cmd == "TEMP") {
    sendTemperature();

  } else if (cmd == "HUMIDITY" || cmd == "HUM") {
    sendHumidity();

  } else if (cmd == "PRESSURE" || cmd == "PRES" || cmd == "BARO") {
    sendPressure();

  } else if (cmd == "TH" || cmd == "TEMP_HUM" || cmd == "ENV" || cmd == "ENVIRONMENT") {
    sendEnvironment();

  } else if (cmd == "AUDIO" || cmd == "SOUND" || cmd == "MIC") {
    sendAudio();

  } else {
    sendLine("ECHO: " + cmd + "\n");
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.begin(115200);
  // sem while(!Serial) para não travar standalone

  if (!BLE.begin()) {
    while (1) {}
  }

  imuOK = IMU.begin();
  if (!imuOK) {
    Serial.println("Failed to initialize IMU!");
  }

  apdsOK = APDS.begin();
  if (!apdsOK) {
    Serial.println("Error initializing APDS9960 sensor!");
  }

  hsOK = HS300x.begin();
  if (!hsOK) {
    Serial.println("Failed to initialize humidity/temperature sensor!");
  }

  baroOK = BARO.begin();
  if (!baroOK) {
    Serial.println("Failed to initialize pressure sensor!");
  }

  // Inicialização do microfone PDM
  PDM.onReceive(onPDMdata);
  // PDM.setGain(30); // opcional: ajuste de ganho (padrão costuma ser 20)
  pdmOK = PDM.begin(1, 16000); // mono, 16 kHz
  if (!pdmOK) {
    Serial.println("Failed to start PDM!");
  }

  BLE.setLocalName("Nano33BLE-UART");
  BLE.setDeviceName("Nano33BLE-UART");
  BLE.setAdvertisedService(uartService);

  uartService.addCharacteristic(rxChar);
  uartService.addCharacteristic(txChar);
  BLE.addService(uartService);

  BLE.advertise();

  Serial.println("BLE pronto. Nome: Nano33BLE-UART");
  Serial.println("Aguardando conexão...");
}

void loop() {
  BLEDevice central = BLE.central();

  if (central) {
    Serial.print("Conectado: ");
    Serial.println(central.address());

    while (central.connected()) {
      handleRx();
    }

    Serial.println("Desconectado.");
    digitalWrite(LED_PIN, LOW);
  }
}