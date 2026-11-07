import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mc.dart';
import '../models/conversation.dart';
import '../providers/conversations_provider.dart';
import '../providers/unread_provider.dart';
import 'conversation_tile.dart';

/// Every conversation, newest first — one per trip.
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(unreadProvider.notifier).refresh());
  }

  Future<void> _refresh() async {
    ref.invalidate(conversationsProvider);
    await Future.wait([
      ref
          .read(conversationsProvider.future)
          .catchError((_) => const <Conversation>[]),
      ref.read(unreadProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final unread = ref.watch(unreadProvider);

    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: McNavHeader(title: 'Messages', fallback: '/home'),
            ),
            Expanded(
              child: conversations.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Brand.blue)),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Couldn't load your messages.",
                          style: tw(FontWeight.w700, 14, Brand.sub)),
                      const SizedBox(height: 12),
                      McGhostButton('Try again', full: false, onTap: _refresh),
                    ],
                  ),
                ),
                data: (items) => RefreshIndicator(
                  color: Brand.blue,
                  onRefresh: _refresh,
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            const Center(
                                child:
                                    Ico('msg', size: 40, color: Brand.faint)),
                            const SizedBox(height: 12),
                            Text('No messages yet',
                                textAlign: TextAlign.center,
                                style: tw(FontWeight.w800, 16, Brand.ink)),
                            const SizedBox(height: 4),
                            Text('Chats from your trips will appear here.',
                                textAlign: TextAlign.center,
                                style: tw(FontWeight.w600, 13, Brand.sub)),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, indent: 76, color: Brand.line),
                          itemBuilder: (context, i) {
                            final c = items[i];
                            return ConversationTile(
                              conversation: c,
                              unread: unread.forTrip(c.tripId),
                              onTap: () => context
                                  .push('/messages/${c.tripId}')
                                  .then((_) =>
                                      ref.invalidate(conversationsProvider)),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
