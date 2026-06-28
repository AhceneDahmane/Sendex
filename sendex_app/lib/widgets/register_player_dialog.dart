import 'package:flutter/material.dart';
import '../models/player_info.dart';

class RegisterPlayerDialog extends StatefulWidget {
  final PlayerInfo? existing;

  const RegisterPlayerDialog({super.key, this.existing});

  @override
  State<RegisterPlayerDialog> createState() => _RegisterPlayerDialogState();
}

class _RegisterPlayerDialogState extends State<RegisterPlayerDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _clubCtrl;
  late TextEditingController _lengthCtrl;
  late TextEditingController _widthCtrl;
  late String _sport;
  late String _position;
  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _clubCtrl = TextEditingController(text: e?.club ?? '');
    _lengthCtrl = TextEditingController(text: '${e?.fieldLength ?? PlayerInfo.defaultLength(e?.sport ?? 'Football')}');
    _widthCtrl = TextEditingController(text: '${e?.fieldWidth ?? PlayerInfo.defaultWidth(e?.sport ?? 'Football')}');
    _sport = e?.sport ?? 'Football';
    _position = e?.position ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clubCtrl.dispose();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    super.dispose();
  }

  void _updateDefaults() {
    _lengthCtrl.text = '${PlayerInfo.defaultLength(_sport)}';
    _widthCtrl.text = '${PlayerInfo.defaultWidth(_sport)}';
  }

  @override
  Widget build(BuildContext context) {
    final positions = PlayerInfo.positionsForSport(_sport);

    return AlertDialog(
      title: Text(_editing ? "Edit Player" : "Register Player"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: "Player Name *",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _clubCtrl,
              decoration: const InputDecoration(
                labelText: "Club (optional)",
                prefixIcon: Icon(Icons.groups),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _sport,
              decoration: const InputDecoration(
                labelText: "Sport",
                prefixIcon: Icon(Icons.sports_soccer),
                border: OutlineInputBorder(),
              ),
              items: PlayerInfo.sports
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _sport = v;
                  _position = '';
                  _updateDefaults();
                });
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _position.isNotEmpty && positions.contains(_position)
                  ? _position
                  : null,
              decoration: const InputDecoration(
                labelText: "Position",
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text("— None —")),
                ...positions
                    .map((p) => DropdownMenuItem(value: p, child: Text(p))),
              ],
              onChanged: (v) => setState(() => _position = v ?? ''),
            ),
            const SizedBox(height: 14),
            const Divider(),
            Text("Field Dimensions (meters)",
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lengthCtrl,
                    decoration: const InputDecoration(
                      labelText: "Length (m)",
                      prefixIcon: Icon(Icons.straighten),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _widthCtrl,
                    decoration: const InputDecoration(
                      labelText: "Width (m)",
                      prefixIcon: Icon(Icons.straighten),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, PlayerInfo(
              name: name,
              club: _clubCtrl.text.trim(),
              sport: _sport,
              position: _position,
              fieldLength: double.tryParse(_lengthCtrl.text),
              fieldWidth: double.tryParse(_widthCtrl.text),
            ));
          },
          child: Text(_editing ? "Save" : "Register"),
        ),
      ],
    );
  }
}
