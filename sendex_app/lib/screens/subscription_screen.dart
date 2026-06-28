import 'package:flutter/material.dart';
import '../models/subscription_info.dart';
import '../services/storage_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _storage = StorageService.instance;
  late SubscriptionInfo _sub;

  @override
  void initState() {
    super.initState();
    _sub = _storage.getSubscription();
  }

  void _startTrial() {
    _sub = SubscriptionInfo(
      isActive: true,
      isTrial: true,
      trialEnd: DateTime.now().add(const Duration(days: 60)),
    );
    _storage.saveSubscription(_sub);
    setState(() {});
  }

  void _subscribe() {
    _sub = SubscriptionInfo(
      isActive: true,
      isTrial: false,
      paidUntil: DateTime.now().add(const Duration(days: 365)),
    );
    _storage.saveSubscription(_sub);
    setState(() {});
  }

  void _logout() {
    _storage.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Subscription"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_sub.isActive && !_sub.isExpired) ...[
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 12),
            Text(
              _sub.isTrial ? "Trial Active" : "Subscribed",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "${_sub.daysRemaining} days remaining",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
            if (_sub.isTrial)
              Text(
                "Your 60-day free trial ends ${_sub.trialEnd!.day}/${_sub.trialEnd!.month}/${_sub.trialEnd!.year}",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            const SizedBox(height: 24),
            if (_sub.isTrial)
              FilledButton.icon(
                onPressed: _subscribe,
                icon: const Icon(Icons.payment),
                label: const Text("Subscribe Now – £44/year"),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              ),
          ] else ...[
            Icon(Icons.lock_open, color: Colors.orange, size: 64),
            const SizedBox(height: 12),
            const Text(
              "60-Day Free Trial",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Test every feature before subscribing.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[400]),
            ),
            const SizedBox(height: 32),

            // Pricing card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text("Annual Subscription", style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("£", style: TextStyle(fontSize: 20)),
                        Text("44", style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text("/year", style: TextStyle(color: Colors.grey[400])),
                        ),
                      ],
                    ),
                    Text("£3.67 per month", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _startTrial,
                      icon: const Icon(Icons.card_giftcard),
                      label: const Text("Start 60-Day Free Trial"),
                      style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Features list
          Text("What's included", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _feature(Icons.speed, "18 core performance metrics"),
          _feature(Icons.map, "GPS tracking & heatmaps"),
          _feature(Icons.flash_on, "Sprint analysis"),
          _feature(Icons.favorite, "Heart rate monitoring"),
          _feature(Icons.compare_arrows, "Compare with teammates"),
          _feature(Icons.picture_as_pdf, "PDF & CSV export"),
          _feature(Icons.group, "Unlimited team members"),
          _feature(Icons.storage, "Session history"),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green[400]),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
