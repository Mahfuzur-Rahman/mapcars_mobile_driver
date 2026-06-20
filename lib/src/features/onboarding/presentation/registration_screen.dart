import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const fields = [
      ['user', 'Full legal name', 'James Kowalski'],
      ['cal', 'Date of birth', '14 / 03 / 1990'],
      ['pin', 'Home address', '22 Elm Road, London E2'],
      ['doc', 'National Insurance no.', 'QQ 12 34 56 C'],
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
                  const McTitle('Your details', size: 24),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(3, (i) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: i == 0 ? Brand.blue : Brand.line,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text('Step 1 of 3 · Personal info', style: tw(FontWeight.w600, 13, Brand.sub)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const McAvatar(size: 84),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Brand.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: const Center(child: Ico('camera', size: 14, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final fl in fields) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 6),
                        child: Text(fl[1], style: tw(FontWeight.w800, 12, Brand.sub)),
                      ),
                      McField(icon: fl[0], value: fl[2], editable: true),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 6),
                    McButton('Continue', icon: 'chevR', onTap: () => context.go('/documents')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
