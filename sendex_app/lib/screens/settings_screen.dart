import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService.instance;
  late String _speedUnit;
  late String _distanceUnit;

  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  bool _savingPwd = false;

  @override
  void initState() {
    super.initState();
    _speedUnit = _storage.speedUnit;
    _distanceUnit = _storage.distanceUnit;
  }

  @override
  void dispose() {
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    super.dispose();
  }

  void _exportAll() async {
    final csv = _storage.exportAllAsCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All data copied to clipboard as CSV")),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final email = _storage.currentEmail;
    if (email == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("All your data will be permanently deleted. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete", style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _storage.deleteAccount(email);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Future<void> _changePassword() async {
    final email = _storage.currentEmail;
    if (email == null) return;

    final oldPwd = _currentPwdCtrl.text.trim();
    final newPwd = _newPwdCtrl.text.trim();
    if (oldPwd.isEmpty || newPwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill both fields")));
      return;
    }
    if (newPwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New password must be 6+ characters")));
      return;
    }

    setState(() => _savingPwd = true);
    final ok = await _storage.changePassword(email, oldPwd, newPwd);
    setState(() => _savingPwd = false);

    if (!mounted) return;
    if (ok) {
      _currentPwdCtrl.clear();
      _newPwdCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password changed")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Current password is wrong")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── Units ────────────────────────────────────────
          _sectionTitle(cs, "Units"),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    title: const Text("Speed"),
                    subtitle: Text(_speedUnit),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'km/h', label: Text("km/h")),
                        ButtonSegment(value: 'm/s', label: Text("m/s")),
                      ],
                      selected: {_speedUnit},
                      onSelectionChanged: (v) => setState(() {
                        _speedUnit = v.first;
                        _storage.speedUnit = _speedUnit;
                      }),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text("Distance"),
                    subtitle: Text(_distanceUnit),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'm', label: Text("m")),
                        ButtonSegment(value: 'km', label: Text("km")),
                      ],
                      selected: {_distanceUnit},
                      onSelectionChanged: (v) => setState(() {
                        _distanceUnit = v.first;
                        _storage.distanceUnit = _distanceUnit;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Change password ──────────────────────────────
          if (_storage.currentEmail != null) ...[
            _sectionTitle(cs, "Change Password"),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _currentPwdCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Current password",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPwdCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "New password (6+ chars)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: _savingPwd ? null : _changePassword,
                        child: _savingPwd
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text("Update Password"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Export ───────────────────────────────────────
          _sectionTitle(cs, "Data"),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text("Export All Data"),
                  subtitle: const Text("Copies all sessions as CSV to clipboard"),
                  onTap: _exportAll,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_forever, color: cs.error),
                  title: Text("Delete Account", style: TextStyle(color: cs.error)),
                  subtitle: Text("Permanently delete all data", style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── About link ───────────────────────────────────
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("About Sendex"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AboutScreen())),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ColorScheme cs, String title) {
    return Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface));
  }
}

// ── About screen (inline for simplicity) ─────────────────────

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("About Sendex")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Version
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.sensors, color: cs.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Sendex", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 2),
                        Text("Version 1.0.0", style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
                        Text("GPS Athletic Performance Tracker", style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.4))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Quick guide
          _sectionTitle(cs, "Quick Guide"),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _guideStep(cs, "1", "Add a device", "Scan for your Sendex vest via Bluetooth or add a simulator in the Devices tab."),
                  const Divider(height: 20),
                  _guideStep(cs, "2", "Assign to a player", "In Club tab, register a player and link the device to them."),
                  const Divider(height: 20),
                  _guideStep(cs, "3", "Start a session", "Tap the device from Devices → Start Session. The vest records GPS, speed, and heart rate in real time."),
                  const Divider(height: 20),
                  _guideStep(cs, "4", "Review & export", "Sessions appear in History and Trends. Export individual or all data as CSV/PDF."),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Contact
          _sectionTitle(cs, "Contact"),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text("support@getsendex.com"),
                  subtitle: const Text("Email support"),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text("getsendex.com"),
                  subtitle: const Text("Website"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ColorScheme cs, String title) {
    return Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface));
  }

  Widget _guideStep(ColorScheme cs, String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          child: Center(child: Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6), height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
