import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/mc.dart';
import '../../auth/providers/auth_notifier.dart';

class DriverSettingsScreen extends ConsumerWidget {
  const DriverSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <(String, List<(String, String, VoidCallback)>)>[
      ('Account', [
        ('user', 'Personal info', () => context.push('/profile/edit')),
        ('lock', 'Change password', () => context.push('/settings/change-password')),
        ('bank', 'Payout method', () => context.push('/payouts')),
        ('doc', 'Documents', () => context.push('/documents')),
      ]),
      ('Driving', [
        ('nav', 'Navigation app', () => _showNavigationAppPicker(context)),
        ('bell', 'Sound & alerts', () => _showSoundAlertsPicker(context)),
        ('globe', 'Language', () => _showLanguagePicker(context)),
      ]),
      ('Support & Community', [
        ('shield', 'Safety toolkit', () => _showSafetyToolkit(context)),
        ('msg', 'Help centre', () => _showHelpCentre(context)),
        ('globe', 'Community & Socials', () => _showCommunitySocials(context)),
      ]),
    ];

    return Scaffold(
      backgroundColor: Brand.bg,
      bottomNavigationBar: const _DriverTabBar(active: 'account'),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: McNavHeader(title: 'Settings', fallback: '/home'),
              ),
              const SizedBox(height: 16),
              for (final (label, rows) in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(label, style: tw(FontWeight.w800, 12, Brand.sub, 0.5)),
                ),
                const SizedBox(height: 8),
                McCard(
                  padding: 0,
                  child: Column(
                    children: [
                      for (int i = 0; i < rows.length; i++)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: rows[i].$3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              border: i < rows.length - 1
                                  ? const Border(bottom: BorderSide(color: Brand.fill))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Ico(rows[i].$1, size: 20, color: Brand.sub),
                                const SizedBox(width: 14),
                                Expanded(child: Text(rows[i].$2, style: tw(FontWeight.w700, 15))),
                                const Ico('chevR', size: 18, color: Brand.faint),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              const SizedBox(height: 6),
              McDangerButton(
                'Log out',
                icon: 'logout',
                onTap: () => _confirmLogout(context, ref),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text('MAP CARS Driver · v1.0.0',
                    style: tw(FontWeight.w600, 12, Brand.faint)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showNavigationAppPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const McTitle('Navigation app', size: 20),
          const SizedBox(height: 6),
          Text('Choose your preferred navigation provider',
              style: tw(FontWeight.w600, 13.5, Brand.sub)),
          const SizedBox(height: 16),
          _SettingSelectTile(
            icon: 'nav',
            title: 'Google Maps (Default)',
            subtitle: 'Real-time traffic & turn guidance',
            selected: true,
            onTap: () {
              Navigator.pop(ctx);
              _toast(context, 'Navigation app set to Google Maps');
            },
          ),
          const SizedBox(height: 10),
          _SettingSelectTile(
            icon: 'globe',
            title: 'Waze',
            subtitle: 'Live police, hazard & road alerts',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _toast(context, 'Navigation app set to Waze');
            },
          ),
          const SizedBox(height: 10),
          _SettingSelectTile(
            icon: 'shield',
            title: 'In-App Navigation',
            subtitle: 'Built-in GPS map with trip overlays',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _toast(context, 'Navigation app set to In-App Navigation');
            },
          ),
        ],
      ),
    ),
  );
}

void _showSoundAlertsPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (context, setSheetState) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const McTitle('Sound & alerts', size: 20),
              const SizedBox(height: 6),
              Text('Customize audio chimes and alert notifications',
                  style: tw(FontWeight.w600, 13.5, Brand.sub)),
              const SizedBox(height: 16),
              _SettingToggleTile(
                icon: 'bell',
                title: 'Trip request alerts',
                subtitle: 'Loud chime when a new request arrives',
                value: true,
                onChanged: (v) {},
              ),
              const SizedBox(height: 10),
              _SettingToggleTile(
                icon: 'nav',
                title: 'Voice navigation guidance',
                subtitle: 'Spoken turn-by-turn directions',
                value: true,
                onChanged: (v) {},
              ),
              const SizedBox(height: 10),
              _SettingToggleTile(
                icon: 'shield',
                title: 'Speed limit warnings',
                subtitle: 'Audible alert when exceeding speed limits',
                value: false,
                onChanged: (v) {},
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _showLanguagePicker(BuildContext context) {
  final languages = [
    ('English (UK)', 'Default', true),
    ('English (US)', 'American English', false),
    ('Polski', 'Polish', false),
    ('Română', 'Romanian', false),
    ('Urdu / اردو', 'Urdu', false),
    ('Español', 'Spanish', false),
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const McTitle('App language', size: 20),
          const SizedBox(height: 6),
          Text('Select your preferred display language',
              style: tw(FontWeight.w600, 13.5, Brand.sub)),
          const SizedBox(height: 16),
          for (final (name, desc, active) in languages) ...[
            _SettingSelectTile(
              icon: 'globe',
              title: name,
              subtitle: desc,
              selected: active,
              onTap: () {
                Navigator.pop(ctx);
                _toast(context, 'Language changed to $name');
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
}

void _showSafetyToolkit(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const McTitle('Driver safety toolkit', size: 20),
          const SizedBox(height: 6),
          Text('Quick access to emergency services & safety protection',
              style: tw(FontWeight.w600, 13.5, Brand.sub)),
          const SizedBox(height: 16),
          _SettingSelectTile(
            icon: 'shield',
            title: 'Emergency 999 Assistance',
            subtitle: 'Direct call to emergency response',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _toast(context, 'Dialing 999 Emergency Services…');
            },
          ),
          const SizedBox(height: 10),
          _SettingSelectTile(
            icon: 'user',
            title: 'Share trip status',
            subtitle: 'Share live GPS location with trusted contact',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _toast(context, 'Live location link copied to clipboard');
            },
          ),
          const SizedBox(height: 10),
          _SettingSelectTile(
            icon: 'doc',
            title: 'Dashcam & Audio recording',
            subtitle: 'Safety recording guidance & privacy terms',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _toast(context, 'Audio/Dashcam safety guidelines opened');
            },
          ),
        ],
      ),
    ),
  );
}

void _showHelpCentre(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const McTitle('Help centre & support', size: 20),
          const SizedBox(height: 6),
          Text('Get help with trips, earnings, or driver queries',
              style: tw(FontWeight.w600, 13.5, Brand.sub)),
          const SizedBox(height: 16),
          _SettingSelectTile(
            icon: 'msg',
            title: 'WhatsApp Driver Support',
            subtitle: '+44 7389 077004 (Direct Coordinator)',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _openDriverUrl(context, 'https://wa.me/447389077004');
            },
          ),
          const SizedBox(height: 10),
          _SettingSelectTile(
            icon: 'phone',
            title: 'Driver Helpline',
            subtitle: '01243 252255 (Chichester Dispatch)',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _openDriverUrl(context, 'tel:01243252255');
            },
          ),
          const SizedBox(height: 10),
          _SettingSelectTile(
            icon: 'doc',
            title: 'Email Driver Operations',
            subtitle: 'info@mapcars.uk',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _openDriverUrl(context, 'mailto:info@mapcars.uk');
            },
          ),
        ],
      ),
    ),
  );
}

void _showCommunitySocials(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Brand.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const McTitle('Community & Socials', size: 20),
          const SizedBox(height: 6),
          Text('Follow official MAP CARS driver updates and announcements',
              style: tw(FontWeight.w600, 13.5, Brand.sub)),
          const SizedBox(height: 16),
          _SettingSelectTile(
            icon: 'globe',
            title: 'Facebook Official Page',
            subtitle: 'facebook.com/profile.php?id=61592078572248',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _openDriverUrl(context, 'https://www.facebook.com/profile.php?id=61592078572248');
            },
          ),
          const SizedBox(height: 10),
          _SettingSelectTile(
            icon: 'star',
            title: 'Instagram @map91868',
            subtitle: 'instagram.com/map91868',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _openDriverUrl(context, 'https://www.instagram.com/map91868/');
            },
          ),
          const SizedBox(height: 10),
          _SettingSelectTile(
            icon: 'msg',
            title: 'WhatsApp Community',
            subtitle: '+44 7389 077004',
            selected: false,
            onTap: () {
              Navigator.pop(ctx);
              _openDriverUrl(context, 'https://wa.me/447389077004');
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _openDriverUrl(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) _toast(context, 'Could not open link: $url');
    }
  } catch (e) {
    if (context.mounted) _toast(context, 'Error launching link: $e');
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _SettingSelectTile extends StatelessWidget {
  const _SettingSelectTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Brand.blue.withValues(alpha: 0.08) : Brand.fill.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Brand.blue : Brand.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Ico(icon, size: 20, color: selected ? Brand.blue : Brand.sub),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tw(FontWeight.w800, 14.5, selected ? Brand.blue : Brand.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: tw(FontWeight.w600, 12, Brand.sub)),
                ],
              ),
            ),
            if (selected) const Ico('check', size: 18, color: Brand.blue),
          ],
        ),
      ),
    );
  }
}

class _SettingToggleTile extends StatefulWidget {
  const _SettingToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_SettingToggleTile> createState() => _SettingToggleTileState();
}

class _SettingToggleTileState extends State<_SettingToggleTile> {
  late bool _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Brand.fill.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Brand.line),
      ),
      child: Row(
        children: [
          Ico(widget.icon, size: 20, color: Brand.sub),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: tw(FontWeight.w800, 14, Brand.ink)),
                const SizedBox(height: 2),
                Text(widget.subtitle, style: tw(FontWeight.w600, 12, Brand.sub)),
              ],
            ),
          ),
          Switch(
            value: _val,
            activeTrackColor: Brand.blue,
            onChanged: (v) {
              setState(() => _val = v);
              widget.onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You\'ll need to sign in again to go online.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancel', style: tw(FontWeight.w700, 14, Brand.sub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Log out', style: tw(FontWeight.w800, 14, Brand.blue)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await ref.read(authNotifierProvider.notifier).signOut();
  if (context.mounted) context.go('/intro');
}

class _DriverTabBar extends StatelessWidget {
  const _DriverTabBar({required this.active});
  final String active;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String, String)>[
      ('wheel', 'Drive', 'drive', '/home'),
      ('chart', 'Earnings', 'earn', '/earnings'),
      ('user', 'Account', 'account', '/profile'),
    ];
    return Container(
      height: 84,
      decoration: const BoxDecoration(
        color: Brand.paper,
        border: Border(top: BorderSide(color: Brand.fill)),
      ),
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          for (final (ic, label, key, route) in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.go(route),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Ico(ic, size: 24, color: key == active ? Brand.blue : Brand.faint),
                    const SizedBox(height: 3),
                    Text(label,
                        style: tw(FontWeight.w800, 11,
                            key == active ? Brand.blue : Brand.faint)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
