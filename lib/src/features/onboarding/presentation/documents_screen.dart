import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const docs = [
      ['PHV driver licence', 'Uploaded · TfL 12345', 'done'],
      ['Private hire insurance', 'Uploaded · exp 03/27', 'done'],
      ['Vehicle V5C / MOT', 'Tap to upload', 'pending'],
      ['Profile photo', 'Add a clear headshot', 'add'],
    ];
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const McTitle('Upload documents', size: 24),
                  const SizedBox(height: 8),
                  Text('We verify these to keep riders safe. JPG or PDF.',
                      style: tw(FontWeight.w600, 14, Brand.sub)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                child: Column(
                  children: [
                    for (final d in docs) ...[
                      _docCard(d[0], d[1], d[2]),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 6),
                    McButton('Submit for review',
                        icon: 'check', kind: BtnKind.grad, onTap: () => context.go('/under-review')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docCard(String title, String sub, String state) {
    final done = state == 'done';
    final pending = state == 'pending';
    return McCard(
      padding: 14,
      color: done ? Brand.green.withValues(alpha: 0.047) : null,
      border: done
          ? Brand.green.withValues(alpha: 0.33)
          : pending
              ? Brand.blue
              : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: done ? Brand.green : Brand.fill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Ico(
                done ? 'check' : (pending ? 'upload' : 'camera'),
                size: 22,
                color: done ? Colors.white : Brand.sub,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tw(FontWeight.w900, 14.5, Brand.ink)),
                const SizedBox(height: 2),
                Text(sub, style: tw(FontWeight.w600, 12.5, done ? Brand.green : Brand.sub)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (done)
            Text('✓', style: tw(FontWeight.w800, 14, Brand.green))
          else
            Ico(state == 'add' ? 'plus' : 'chevR', size: 20, color: Brand.faint),
        ],
      ),
    );
  }
}
