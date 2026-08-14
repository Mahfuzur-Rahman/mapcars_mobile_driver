import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class UnderReviewScreen extends StatelessWidget {
  const UnderReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      ['Identity verified', true],
      ['PHV licence checked', true],
      ['Insurance review', false],
      ['Background check', false],
    ];
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
          child: Column(
            children: [
              Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Brand.blue.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Brand.blue, Color(0xFF12939F)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(child: Ico('clock', size: 34, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const McTitle('Application under\nreview', size: 24, align: TextAlign.center),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      "Thanks James! We're checking your documents. This usually takes 24–48 hours.",
                      textAlign: TextAlign.center,
                      style: tw(FontWeight.w600, 15, Brand.sub),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              McCard(
                padding: 16,
                child: Column(
                  children: List.generate(items.length, (i) {
                    final ok = items[i][1] as bool;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        border: i < items.length - 1
                            ? const Border(bottom: BorderSide(color: Brand.fill))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: ok ? Brand.green : Brand.fill,
                              shape: BoxShape.circle,
                              border: ok ? null : Border.all(color: Brand.line, width: 2),
                            ),
                            child: ok ? const Center(child: Ico('check', size: 14, color: Colors.white)) : null,
                          ),
                          const SizedBox(width: 12),
                          Text(items[i][0] as String, style: tw(FontWeight.w700, 14.5, ok ? Brand.ink : Brand.sub)),
                          if (!ok) ...[
                            const Spacer(),
                            Text('In progress', style: tw(FontWeight.w700, 12, Brand.faint)),
                          ],
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const Spacer(),
              const McGhostButton('Contact support', icon: 'msg'),
              const SizedBox(height: 12),
              McButton('Continue to app', kind: BtnKind.grad, onTap: () => context.go('/home')),
            ],
          ),
        ),
      ),
    );
  }
}
