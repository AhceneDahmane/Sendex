# Sendex — Documentation Hardware

## Architecture générale

```
 ┌─────────────┐     BLE (FFF0/FFF1)     ┌─────────────┐
 │   ESP32     │ ◄──────────────────────► │  App Flutter │
 │ (brassière) │                          │  (iPhone)    │
 └──────┬──────┘                          └─────────────┘
        │
   ┌────┴────┐
   │ GPS     │ NEO-6M / NEO-8M
   │ FC      │ MAX30102 (optique) ou Polar H10 (ceinture)
   │ Batterie│ Li-Po 3.7V + TP4056
   │ Bouton  │ Start/Stop session (hold 3s)
   │ LEDs    │ Verte (veille) / Bleue (session active)
   └─────────┘
```

## Liste des composants

| # | Composant | Référence | Qty | Prix unitaire | Rôle |
|---|---|---|---|---|---|
| 1 | **ESP32** | ESP32-WROOM-32 / DevKitC | 1 | ~8€ | Microcontrôleur + BLE |
| 2 | **GPS** | NEO-6M (ou NEO-8M) | 1 | ~10-15€ | Position, vitesse, altitude |
| 3 | **FC optique** | MAX30102 | 1 | ~5-8€ | Fréquence cardiaque |
| 4 | **Batterie** | Li-Po 3.7V 2000mAh | 1 | ~10€ | Alimentation |
| 5 | **Chargeur** | TP4056 (avec protection) | 1 | ~2-3€ | Charge Li-Po via USB-C |
| 6 | **Bouton** | Poussoir 6x6x5mm | 1 | ~0.5€ | Start/Stop session |
| 7 | **LED verte** | 5mm 20mA | 1 | ~0.1€ | Indicateur veille |
| 8 | **LED bleue** | 5mm 20mA | 1 | ~0.1€ | Indicateur session active |
| 9 | **Résistances** | 220Ω (LEDs), 100kΩ (diviseur) | 4 | ~0.1€ | Limitation courant, pont diviseur |
| 10 | **Plaque prototype** | PCB 5x7cm | 1 | ~2€ | Support de soudure |
| 11 | **Câbles** | Dupont M/F, F/F | 20 | ~0.1€ | Connexions |

**Budget total** : ~35-45€ par brassière (hors vêtement)

---

## Schéma de câblage

### ESP32 (brochage utilisé)

```
 GPIO  ───────────────────────────────────────────────────────────
 │  D16 (RX2)  ◄──── TX du NEO-6M (GPS)
 │  D17 (TX2)  ────► RX du NEO-6M (GPS)
 │  D21 (SDA)  ◄──► SDA du MAX30102 (I2C)
 │  D22 (SCL)  ◄──► SCL du MAX30102 (I2C)
 │  D7          ◄──── Bouton poussoir ── GND (INPUT_PULLUP interne)
 │  D8          ──── R=220Ω ── LED verte ── GND
 │  D9          ──── R=220Ω ── LED bleue  ── GND
 │  D35 (ADC)   ◄──── Diviseur batterie
 │  VIN         ◄──── TP4056 OUT+ (4.2V)
 │  3.3V        ────► VCC NEO-6M + VIN MAX30102
 │  GND         ────► GND tous modules
 └────────────────────────────────────────────────────────────────
```

### Alimentation

```
┌─────────────────────────────────────────────────────┐
│                   Batterie Li-Po                     │
│                  3.7V 2000mAh                        │
│                  [+]       [-]                       │
└──────────────────┬─────────┬─────────────────────────┘
                   │         │
                   ▼         ▼
              ┌─────────────────────┐
              │      TP4056         │
              │                     │
              │  BAT+    ── [+]     │
              │  BAT-    ── [-]     │
              │  OUT+    ── 4.2V    │
              │  OUT-    ── GND     │
              │  IN+/USB+ ── 5V USB │
              │  IN-/USB- ── GND    │
              └──────┬──────────────┘
                     │ 4.2V
                     ▼
              ┌──────────────┐
              │   ESP32 VIN  │
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
┌────────────────────────────────────────────┐
│              NEO-6M / NEO-8M               │
│                                            │
│   VCC ──── ESP32 3.3V                      │
│   GND ──── ESP32 GND                       │
│   TX  ──── ESP32 GPIO16 (RX2)              │
│   RX  ──── ESP32 GPIO17 (TX2)              │
│                                            │
│   Antenne ── patch céramique 18x18mm       │
└────────────────────────────────────────────┘
```

> **Note** : Le NEO-6M fonctionne en 3.3V mais supporte le 5V sur VCC. Alimenter en 3.3V pour éviter tout risque sur les GPIO de l'ESP32.

### Fréquence cardiaque — MAX30102

```
┌────────────────────────────────────────────┐
│                MAX30102                     │
│                                            │
│   VIN  ──── ESP32 3.3V                     │
│   GND  ──── ESP32 GND                      │
│   SDA  ──── ESP32 GPIO21                   │
│   SCL  ──── ESP32 GPIO22                   │
│                                            │
│   INT  ──── (optionnel, GPIO libre)        │
│   RD   ──── (non connecté)                 │
│   IRD  ──── (non connecté)                 │
└────────────────────────────────────────────┘
```

> **Alternative Polar H10** : remplacer le MAX30102 par la ceinture Polar H10 qui communique directement en BLE (ne passe pas par l'ESP32 — l'app Flutter se connecte directement).

### Bouton + LEDs

```
┌────────────────────────────────────────┐
│              ESP32                     │
│                                        │
│   GPIO7 ────── Bouton ────── GND       │
│           (INPUT_PULLUP interne)       │
│                                        │
│   GPIO8 ──── R=220Ω ──── LED verte ── GND
│   GPIO9 ──── R=220Ω ──── LED bleue  ── GND
└────────────────────────────────────────┘
```

---

## Protocole BLE

| Service | UUID | Caractéristique | UUID | Propriétés |
|---|---|---|---|---|
| Données | `FFF0` | `FFF1` | Notify |
| Batterie | `180F` | `2A19` | Read, Notify |

### Format du JSON notifié (chaque seconde)

```json
{
  "lat":  48.856600,
  "lng":  2.352200,
  "speed": 12.5,
  "alt":   42.0,
  "hr":    145,
  "sat":   8,
  "hdop":  1.2,
  "bat":   85
}
```

| Champ | Type | Unité | Source |
|---|---|---|---|
| `lat` | double | degrés décimaux | GPS |
| `lng` | double | degrés décimaux | GPS |
| `speed` | float | km/h | GPS |
| `alt` | float | mètres | GPS |
| `hr` | int | bpm | MAX30102 |
| `sat` | int | — | GPS (nombre de satellites) |
| `hdop` | float | — | GPS (précision, <2 = bonne) |
| `bat` | int | % | ADC + TP4056 |

---

## Comportement attendu

| État | LED verte | LED bleue | BLE | GPS | FC |
|---|---|---|---|---|---|
| **Veille** (defaut) | ON | OFF | Advertising | OFF (low power) | OFF |
| **Session active** | OFF | ON | Notify chaque 1s | ON (1Hz) | ON (1Hz) |
| **Batterie faible** <20% | Clignote lente | — | Advertising toujours | — | — |

**Bouton** : hold 3s → toggle veille ↔ session

---

## ⚠️ Recommandations hardware

1. **Condensateur 100µF** entre VCC et GND du GPS (filtrage des pics de courant GPS)
2. **Résistance pull-up 4.7kΩ** sur SDA/SCL si le module MAX30102 ne les intègre pas
3. **Diode de roue libre 1N4007** aux bornes du TP4056 si utilisation d'une batterie 18650
4. **Boîtier étanche** imprimé 3D pour protéger l'électronique sur le terrain
5. **Câble silicone** souple 26AWG pour supporter les mouvements du joueur
6. **Pochette velcro** cousue sur la brassière pour loger le boîtier (dos, entre omoplates)

---

## Améliorations possibles

| Amélioration | Composant | Prix | Bénéfice |
|---|---|---|---|
| GPS multi-GNSS | **NEO-9M** | +5€ | Meilleure précision, fix plus rapide |
| IMU 9-DOF | **MPU9250** | +8€ | Accéléromètre + gyro + magnétomètre pour détection d'impacts |
| Stockage SD | Module microSD | +5€ | Buffer local si perte BLE |
| Cardiaque ceinture | Polar H10 | +60€ | Précision médicale vs optique |
| 4G | SIM7000G | +15€ | Transmission en temps réel sans téléphone |
| Batterie plus grande | 4000mAh | +5€ | Autonomie 12h+ |

---

## Firmware

Le code ESP32 est dans `src/sendex_esp32.ino` — flasher avec Arduino IDE ou PlatformIO.

**Bibliothèques requises** (Arduino IDE) :
- `TinyGPSPlus` (Mikal Hart)
- `BLEDevice` (intégré ESP32)

**MAX30102** (optionnel) :
- `SparkFun MAX3010x Pulse and Proximity Sensor Library`

**Tests** :
- `screen /dev/ttyUSB0 115200` pour voir les logs série
- L'app Sendex scanne les devices BLE nommés "Sendex-Vest"
