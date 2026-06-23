import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';
import '../models/player_info.dart';
import '../models/session_data.dart';

class StorageService {
  static final StorageService _instance = StorageService._();
  static StorageService get instance => _instance;
  StorageService._();

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

  String get role => _prefs?.getString('role') ?? 'player';
  set role(String v) => _prefs?.setString('role', v);

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
  }

  Future<void> removeDevice(String id) async {
    final devices = getDevices();
    devices.removeWhere((d) => d.id == id);
    await _prefs?.setString('devices', jsonEncode(devices.map((d) => d.toJson()).toList()));
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
  }

  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
