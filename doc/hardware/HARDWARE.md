# Sendex — Documentation Hardware

## Architecture générale

```
 ┌─────────────┐     BLE (FFF0/FFF1/FFF2)  ┌─────────────┐
 │   ESP32      │ ◄───────────────────────► │  App Flutter │
 │ (brassière)   │                          │  (iPhone)    │
 └──────┬───────┘                          └──────────────┘
        │
   ┌────┴──────────┐
   │ GPS           │ NEO-6M (SoftwareSerial RX=16, TX=17)
   │ FC optique    │ MAX30102 (I2C 0x57, SDA=21, SCL=22)
   │ Accéléromètre │ MPU6050 (I2C 0x68, même bus)
   │ Batterie      │ Li-Po 3.7V + TP4056 (ADC GPIO 35)
   │ Bouton princ. │ GPIO 7 — hold 3s toggle session
   │ Bouton BOOT   │ GPIO 0 — tap → batterie sur LED bleue
   │ LED verte     │ GPIO 8 — GPS fix / session
   │ LED bleue     │ GPIO 9 — PWM HR zone / batterie
   └───────────────┘
```

## Liste des composants

| # | Composant | Référence | Qty | Prix unitaire | Rôle |
|---|---|---|---|---|---|---|
| 1 | **ESP32** | ESP32-WROOM-32 / DevKitC | 1 | ~8€ | Microcontrôleur + BLE |
| 2 | **GPS** | NEO-6M (ou NEO-8M) | 1 | ~10-15€ | Position, vitesse, altitude |
| 3 | **FC optique** | MAX30102 | 1 | ~5-8€ | Fréquence cardiaque |
| 4 | **Accéléromètre** | MPU6050 | 1 | ~3-5€ | Accélération 3 axes |
| 5 | **Batterie** | Li-Po 3.7V 2000mAh | 1 | ~10€ | Alimentation |
| 6 | **Chargeur** | TP4056 (avec protection) | 1 | ~2-3€ | Charge Li-Po via USB-C |
| 7 | **Bouton principal** | Poussoir 6x6x5mm | 1 | ~0.5€ | Start/Stop session (hold 3s) |
| 8 | **LED verte** | 5mm 20mA | 1 | ~0.1€ | GPS fix / session active |
| 9 | **LED bleue** | 5mm 20mA | 1 | ~0.1€ | FC zone / batterie |
| 10 | **Résistances** | 220Ω (LEDs), 100kΩ (diviseur) | 4 | ~0.1€ | Limitation courant, pont diviseur |
| 11 | **Plaque prototype** | PCB 5x7cm | 1 | ~2€ | Support de soudure |
| 12 | **Câbles** | Dupont M/F, F/F | 20 | ~0.1€ | Connexions |

**Budget total** : ~40-52€ par brassière (hors vêtement)

---

## Schéma de câblage

### ESP32 (brochage utilisé)

```
 GPIO  ──────────────────────────────────────────────────────────────
 │  D16 (RX2)  ◄──── TX du NEO-6M (GPS)
 │  D17 (TX2)  ────► RX du NEO-6M (GPS)
 │  D21 (SDA)  ◄──► SDA du MAX30102 + MPU6050 (I2C bus)
 │  D22 (SCL)  ◄──► SCL du MAX30102 + MPU6050 (I2C bus)
 │  D7          ◄──── Bouton principal (INPUT_PULLUP, hold 3s)
 │  D0 (BOOT)  ◄──── Bouton carte (INPUT_PULLUP, tap → batterie)
 │  D8          ──── R=220Ω ── LED verte ── GND (session / fix GPS)
 │  D9 (PWM)   ──── R=220Ω ── LED bleue  ── GND (HR zone / batterie)
 │  D35 (ADC)  ◄──── Diviseur batterie
 │  VIN        ◄──── TP4056 OUT+ (4.2V)
 │  3.3V       ────► VCC NEO-6M + MAX30102 + MPU6050
 │  GND        ────► GND tous modules
 └───────────────────────────────────────────────────────────────────
```

### Alimentation

```
┌────────────────────────────────────────────┐
│              Batterie Li-Po                  │
│             3.7V 2000mAh                     │
│             [+]       [-]                    │
└─────────────┬─────────┬──────────────────────┘
              │         │
              ▼         ▼
         ┌──────────────────────┐
         │       TP4056         │
         │                      │
         │  BAT+    ── [+]      │
         │  BAT-    ── [-]      │
         │  OUT+    ── 4.2V     │
         │  OUT-    ── GND      │
         │  IN+/USB+ ── 5V USB  │
         │  IN-/USB- ── GND     │
         └───────┬──────────────┘
                 │ 4.2V
                 ▼
          ┌──────────────┐
          │  ESP32 VIN   │
          └──────────────┘
```

### Diviseur de tension (mesure batterie)

```
Batterie (+) ─── R1=100kΩ ───┬─── GPIO35 (ADC ESP32 0-3.3V)
                              │
                             R2=100kΩ
                              │
                             GND

Tension ADC = Vbatt × (R2 / (R1 + R2)) = Vbatt / 2
→ 4.2V max ⇒ 2.1V sur ADC (< 3.3V ✓)
```

### GPS — NEO-6M / NEO-8M

```
 NEO-6M                   ESP32
 ┌────────────────┐
 │  VCC ───────── ESP32 3.3V
 │  GND ───────── ESP32 GND
 │  TX  ───────── GPIO16 (RX2)
 │  RX  ───────── GPIO17 (TX2)
 │  Antenne ──── patch céramique 18x18mm
 └────────────────┘
```

> **Note** : Le NEO-6M fonctionne en 3.3V mais supporte le 5V sur VCC. Alimenter en 3.3V pour éviter tout risque sur les GPIO de l'ESP32.

### Capteurs I2C (MAX30102 + MPU6050)

Les deux capteurs partagent le même bus I2C (SDA=21, SCL=22) — adresses différentes (0x57 et 0x68).

```
 MAX30102 (0x57)         MPU6050 (0x68)          ESP32
 ┌──────────────┐   ┌──────────────┐
 │  VIN ────────┤   │  VCC ────────┤─────── 3.3V
 │  GND ────────┤   │  GND ────────┤─────── GND
 │  SDA ────────┼───┤  SDA ────────┼─────── GPIO21
 │  SCL ────────┼───┤  SCL ────────┼─────── GPIO22
 │  INT  ───────┤   │  INT ────────┤ (optionnel)
 └──────────────┘   └──────────────┘
```

> **Alternative Polar H10** : remplacer le MAX30102 par la ceinture Polar H10 qui communique directement en BLE (ne passe pas par l'ESP32 — l'app Flutter se connecte directement).

### Boutons + LEDs

```
 ESP32
 ┌──────────────────────────────────────────┐
 │  GPIO7 ────── Bouton principal ──── GND  │
 │          (INPUT_PULLUP, hold 3s session)  │
 │                                           │
 │  GPIO0 ────── Bouton BOOT (carte) ────   │
 │          (INPUT_PULLUP, tap → batterie)   │
 │                                           │
 │  GPIO8 ──── R=220Ω ──── LED verte ─── GND│
 │  GPIO9 ──── R=220Ω ──── LED bleue  ─── GND│
 │          (PWM 5kHz, HR zone feedback)      │
 └──────────────────────────────────────────┘
```

---

## Protocole BLE

| Service | UUID | Caractéristique | UUID | Propriétés |
|---|---|---|---|---|
| Données | `FFF0` | `FFF1` (data) | Notify | JSON GPS + capteurs 1/s |
| Commandes | `FFF0` | `FFF2` (cmd) | Write, Notify | START / STOP / STATUS / PING / SLEEP |
| Batterie | `180F` | `2A19` | Read, Notify | Niveau batterie % |

### Format du JSON notifié (chaque seconde en session)

```json
{
  "v":  "v1.3.0",
  "lat":  48.856600,
  "lng":  2.352200,
  "speed": 12.5,
  "alt":   42.0,
  "hr":    145,
  "sat":   8,
  "hdop":  1.2,
  "bat":   85,
  "accel": 0.32
}
```

| Champ | Type | Unité | Source |
|---|---|---|---|
| `v` | string | — | Version firmware |
| `lat` | double | degrés décimaux | GPS |
| `lng` | double | degrés décimaux | GPS |
| `speed` | float | km/h | GPS |
| `alt` | float | mètres | GPS |
| `hr` | int | bpm | MAX30102 |
| `sat` | int | — | GPS (nombre de satellites) |
| `hdop` | float | — | GPS (précision, <2 = bonne) |
| `bat` | int | % | ADC + TP4056 |
| `accel` | float | G | MPU6050 (signée : +accélération, -décélération) |

### Commandes BLE (FFF2 Write)

| Commande | Effet | Réponse |
|---|---|---|
| `START` | Démarre la session | `OK:START` ou `ERR:ALREADY_STARTED` |
| `STOP` | Arrête la session | `OK:STOP` ou `ERR:NOT_STARTED` |
| `STATUS` | État instantané | JSON court (bat, hr, sat, v, accel) |
| `PING` | Test connexion | `PONG v1.3.0` |
| `SLEEP` | Force deep sleep | `OK:SLEEP` |

---

## Comportement attendu

| État | LED verte (GPIO 8) | LED bleue (GPIO 9, PWM) | BLE | GPS | Capteurs |
|---|---|---|---|---|---|
| **Veille, fix GPS** | Clignote lent (1s) | OFF | Advertising | ON (low) | OFF |
| **Veille, pas de fix** | Clignote rapide (500ms) | OFF | Advertising | ON (search) | OFF |
| **Session, FC <120** | ON fixe | Pulse lent (2s cycle) | Notify 1/s | ON (1Hz) | Tous 1Hz |
| **Session, FC 120-150** | ON fixe | Pulse moyen (1s cycle) | Notify 1/s | ON (1Hz) | Tous 1Hz |
| **Session, FC >150** | ON fixe | Pulse rapide (400ms) | Notify 1/s | ON (1Hz) | Tous 1Hz |
| **Batterie <10%** | OFF | OFF (forced sleep) | OFF (deep sleep) | OFF | OFF |
| **BOOT tap** | — | Clignote N fois (N = bat%/10) | — | — | — |

**Bouton principal (GPIO 7)** : hold 3s → toggle veille ↔ session
**Bouton BOOT (GPIO 0)** : tap < 1s → batterie sur LED bleue

### Anti-stationary filter
- Si déplacement < 3m ET vitesse < 0.5 km/h → pas d'envoi
- Force-send toutes les 30s (keepalive)
- Économise NVS et batterie pendant les pauses

---

## ⚠️ Recommandations hardware

1. **Condensateur 100µF** entre VCC et GND du GPS (filtrage des pics de courant GPS)
2. **Résistance pull-up 4.7kΩ** sur SDA/SCL si les modules I2C ne les intègrent pas
3. **Diode de roue libre 1N4007** aux bornes du TP4056 si utilisation d'une batterie 18650
4. **Boîtier étanche** imprimé 3D pour protéger l'électronique sur le terrain
5. **Câble silicone** souple 26AWG pour supporter les mouvements du joueur
6. **Pochette velcro** cousue sur la brassière pour loger le boîtier (dos, entre omoplates)

---

## Améliorations possibles

| Amélioration | Composant | Prix | Bénéfice |
|---|---|---|---|
| GPS multi-GNSS | **NEO-9M** | +5€ | Meilleure précision, fix plus rapide |
| Gyroscope | déjà dans MPU6050 | — | Rotation 3 axes (à activer côté firmware) |
| Stockage SD | Module microSD | +5€ | Buffer local si perte BLE (déjà fait via NVS) |
| Cardiaque ceinture | Polar H10 | +60€ | Précision médicale vs optique |
| 4G | SIM7000G | +15€ | Transmission en temps réel sans téléphone |
| Batterie plus grande | 4000mAh | +5€ | Autonomie 12h+ |

---

## Firmware

Le code ESP32 est dans `src/sendex_esp32.ino` (version v1.3.0) — flasher avec Arduino IDE ou PlatformIO.

**Bibliothèques requises** (Arduino IDE) :
- `TinyGPSPlus` (Mikal Hart)
- `BLEDevice` / `BLEUtils` / `BLEServer` / `BLE2902` (intégré ESP32)
- `esp_pm.h` (intégré ESP32 — power management)

**Capteurs** (bibliothèques Arduino, optionnelles — fallback simulation si absent) :
- `Wire.h` (intégré) pour MAX30102 + MPU6050

**Tests** :
- `screen /dev/ttyUSB0 115200` pour voir les logs série
- L'app Sendex scanne les devices BLE nommés "Sendex-Vest"
