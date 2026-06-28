import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';
import '../models/player_info.dart';
import '../models/session_data.dart';
import '../models/subscription_info.dart';

class StorageService {
  static final StorageService _instance = StorageService._();
  static StorageService get instance => _instance;
  StorageService._();

  // ── Change notifier for cross-screen refresh ──────────────
  static final sessionNotifier = ChangeNotifier();
  static final deviceNotifier = ChangeNotifier();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? get playerName => _prefs?.getString('playerName');
  set playerName(String? name) {
    if (name == null) {
      _prefs?.remove('playerName');
    } else {
      _prefs?.setString('playerName', name);
    }
  }

  bool get isLoggedIn => _prefs?.getBool('loggedIn') ?? false;
  set isLoggedIn(bool v) => _prefs?.setBool('loggedIn', v);

  bool get onboardingDone => _prefs?.getBool('onboardingDone') ?? false;
  set onboardingDone(bool v) => _prefs?.setBool('onboardingDone', v);

  String get role => _prefs?.getString('role') ?? 'player';
  set role(String v) => _prefs?.setString('role', v);

  // ── Unit preferences ──────────────────────────────────────
  String get speedUnit => _prefs?.getString('speedUnit') ?? 'km/h';
  set speedUnit(String v) => _prefs?.setString('speedUnit', v);

  String get distanceUnit => _prefs?.getString('distanceUnit') ?? 'm';
  set distanceUnit(String v) => _prefs?.setString('distanceUnit', v);

  double convertSpeed(double kmh) {
    return speedUnit == 'm/s' ? kmh / 3.6 : kmh;
  }

  String speedSuffix() => speedUnit;
  String distanceSuffix() => distanceUnit;

  String formatSpeed(double kmh) {
    final v = convertSpeed(kmh);
    return "${v.toStringAsFixed(1)} ${speedSuffix()}";
  }

  String formatDistance(double meters) {
    if (distanceUnit == 'km') {
      return meters >= 1000
          ? "${(meters / 1000).toStringAsFixed(2)} km"
          : "${meters.toStringAsFixed(0)} m";
    }
    return "${meters.toStringAsFixed(0)} m";
  }

  // ── Password change ──────────────────────────────────────
  Future<bool> changePassword(String email, String oldPassword, String newPassword) async {
    final accounts = _getAccounts();
    final account = accounts[email];
    if (account == null || account['password'] != oldPassword) return false;
    account['password'] = newPassword;
    await _saveAccounts(accounts);
    return true;
  }

  // ── Delete account ────────────────────────────────────────
  Future<void> deleteAccount(String email) async {
    final accounts = _getAccounts();
    accounts.remove(email);
    await _saveAccounts(accounts);
    logout();
  }

  // ── Export all data ──────────────────────────────────────
  String exportAllAsCsv() {
    final buf = StringBuffer();
    for (final d in getDevices()) {
      for (final s in getSessions(d.id)) {
        buf.writeln("Player,${s.playerName},Device,${d.name},Date,${s.startTime.toIso8601String()}");
        buf.writeln("Duration (s),${s.duration.inSeconds}");
        buf.writeln("Max Speed (km/h),${s.maxSpeed}");
        buf.writeln("Avg Speed (km/h),${s.avgSpeed}");
        buf.writeln("Total Distance (m),${s.totalDistance}");
        buf.writeln("Sprint Count,${s.sprintCount}");
        buf.writeln("Avg HR (bpm),${s.avgHeartRate}");
        buf.writeln("Max HR (bpm),${s.maxHeartRate}");
        buf.writeln("Intensity Index (%),${s.intensityIndex}");
        buf.writeln("Workload,${s.workload}");
        buf.writeln();
      }
    }
    return buf.toString();
  }

  Map<String, Map<String, dynamic>> _getAccounts() {
    final raw = _prefs?.getString('accounts');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as Map<String, dynamic>).map(
        (ik, iv) => MapEntry(ik, iv as dynamic),
      )),
    );
  }

  Future<void> _saveAccounts(Map<String, Map<String, dynamic>> accounts) async {
    await _prefs?.setString('accounts', jsonEncode(accounts));
  }

  Future<bool> register(String email, String password, String role, String displayName) async {
    final accounts = _getAccounts();
    if (accounts.containsKey(email)) return false;
    accounts[email] = {'password': password, 'role': role, 'displayName': displayName};
    await _saveAccounts(accounts);
    return true;
  }

  Future<bool> login(String email, String password) async {
    final accounts = _getAccounts();
    final account = accounts[email];
    if (account == null || account['password'] != password) return false;
    final displayName = account['displayName'] as String;
    final userRole = account['role'] as String;

    currentEmail = email;
    playerName = displayName;
    role = userRole;
    isLoggedIn = true;

    if (userRole == 'player') {
      await addPlayer(displayName);
    }
    return true;
  }

  String? get currentEmail => _prefs?.getString('currentEmail');
  set currentEmail(String? email) {
    if (email == null) {
      _prefs?.remove('currentEmail');
    } else {
      _prefs?.setString('currentEmail', email);
    }
  }

  void logout() {
    isLoggedIn = false;
    playerName = null;
    currentEmail = null;
  }

  List<PlayerInfo> getPlayerInfoList() {
    final infoRaw = _prefs?.getString('player_info_map');
    final infoMap = infoRaw != null
        ? (jsonDecode(infoRaw) as Map<String, dynamic>).map((k, v) =>
            MapEntry(k, PlayerInfo.fromJson(v as Map<String, dynamic>)))
        : <String, PlayerInfo>{};

    // Backward compat: old `players` key stored just names as strings
    final oldNames = _prefs?.getString('players');
    if (oldNames != null) {
      final names = (jsonDecode(oldNames) as List<dynamic>).cast<String>();
      for (final n in names) {
        infoMap.putIfAbsent(n, () => PlayerInfo(name: n));
      }
      _prefs?.remove('players');
    }

    return infoMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<String> getPlayers() {
    return getPlayerInfoList().map((p) => p.name).toList();
  }

  PlayerInfo? getPlayerInfo(String name) {
    final infoRaw = _prefs?.getString('player_info_map');
    if (infoRaw == null) return null;
    final map = jsonDecode(infoRaw) as Map<String, dynamic>;
    if (!map.containsKey(name)) return null;
    return PlayerInfo.fromJson(map[name] as Map<String, dynamic>);
  }

  Future<void> savePlayerInfo(PlayerInfo info) async {
    final infoRaw = _prefs?.getString('player_info_map');
    final map = infoRaw != null
        ? (jsonDecode(infoRaw) as Map<String, dynamic>).map((k, v) =>
            MapEntry(k, PlayerInfo.fromJson(v as Map<String, dynamic>)))
        : <String, PlayerInfo>{};
    map[info.name] = info;
    await _prefs?.setString(
        'player_info_map', jsonEncode(map.map((k, v) => MapEntry(k, v.toJson()))));
  }

  Future<void> deletePlayerInfo(String name) async {
    final infoRaw = _prefs?.getString('player_info_map');
    if (infoRaw == null) return;
    final map = (jsonDecode(infoRaw) as Map<String, dynamic>).map((k, v) =>
        MapEntry(k, PlayerInfo.fromJson(v as Map<String, dynamic>)));
    map.remove(name);
    await _prefs?.setString(
        'player_info_map', jsonEncode(map.map((k, v) => MapEntry(k, v.toJson()))));
  }

  Future<void> addPlayer(String name) async {
    final existing = getPlayerInfo(name);
    if (existing == null) {
      await savePlayerInfo(PlayerInfo(name: name));
    }
  }

  List<DeviceInfo> getDevices() {
    final raw = _prefs?.getString('devices');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  List<DeviceInfo> getDevicesForPlayer(String playerName) {
    return getDevices().where((d) => d.ownerName == playerName).toList();
  }

  Future<void> saveDevice(DeviceInfo device) async {
    final devices = getDevices();
    devices.removeWhere((d) => d.id == device.id);
    devices.add(device);
    await _prefs?.setString('devices', jsonEncode(devices.map((d) => d.toJson()).toList()));
    deviceNotifier.notifyListeners();
  }

  Future<void> removeDevice(String id) async {
    final devices = getDevices();
    devices.removeWhere((d) => d.id == id);
    await _prefs?.setString('devices', jsonEncode(devices.map((d) => d.toJson()).toList()));
    deviceNotifier.notifyListeners();
  }

  List<SessionData> getSessions(String deviceId) {
    final key = 'sessions_$deviceId';
    final raw = _prefs?.getString(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => SessionData.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveSession(String deviceId, SessionData session) async {
    final sessions = getSessions(deviceId);
    sessions.insert(0, session);
    final key = 'sessions_$deviceId';
    await _prefs?.setString(key, jsonEncode(sessions.map((s) => s.toJson()).toList()));
    sessionNotifier.notifyListeners();
  }

  Future<void> deleteSession(String deviceId, String sessionId) async {
    final sessions = getSessions(deviceId);
    sessions.removeWhere((s) => s.id == sessionId);
    final key = 'sessions_$deviceId';
    await _prefs?.setString(key, jsonEncode(sessions.map((s) => s.toJson()).toList()));
    sessionNotifier.notifyListeners();
  }

  Future<void> clearAll() async {
    await _prefs?.clear();
  }

  SubscriptionInfo getSubscription() {
    final raw = _prefs?.getString('subscription');
    if (raw == null) {
      return SubscriptionInfo(isActive: false);
    }
    return SubscriptionInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSubscription(SubscriptionInfo sub) async {
    await _prefs?.setString('subscription', jsonEncode(sub.toJson()));
  }
}
