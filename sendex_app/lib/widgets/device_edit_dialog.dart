import 'package:flutter/material.dart';
import '../models/device_info.dart';

class DeviceEditDialog extends StatefulWidget {
  final DeviceInfo? device;

  const DeviceEditDialog({super.key, this.device});

  @override
  State<DeviceEditDialog> createState() => _DeviceEditDialogState();
}

class _DeviceEditDialogState extends State<DeviceEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _macCtrl;
  late int _selectedColor;
  bool get _isEditing => widget.device != null;

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _nameCtrl = TextEditingController(text: d?.name ?? "Sendex Simulator");
    _macCtrl = TextEditingController(text: d?.address ?? DeviceInfo.randomMac());
    _selectedColor = d?.colorValue ?? DeviceInfo.presetColors[0];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _macCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? "Edit Device" : "Add Simulated Device"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: "Device Name",
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _macCtrl,
              decoration: const InputDecoration(
                labelText: "MAC Address",
                prefixIcon: Icon(Icons.memory),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Color", style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DeviceInfo.presetColors.map((c) {
                final selected = _selectedColor == c;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: Color(c).withValues(alpha: 0.6), blurRadius: 8)]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            final mac = _macCtrl.text.trim();
            if (name.isEmpty || mac.isEmpty) return;
            Navigator.pop(context, (name, mac, _selectedColor));
          },
          child: Text(_isEditing ? "Save" : "Add"),
        ),
      ],
    );
  }
}
