import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../providers/unread_provider.dart';

/// Home-screen shortcut to Messages, carrying the total unread count.
class InboxButton extends ConsumerWidget {
  const InboxButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadProvider.select((s) => s.total));
    return McBadge(
      count: unread,
      child: McCircleButton('msg',
          semanticLabel: unread == 0 ? 'Messages' : 'Messages, $unread unread',
          onTap: () => context.push('/messages')),
    );
  }
}
