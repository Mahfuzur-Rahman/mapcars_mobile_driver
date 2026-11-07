import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../../messages/chat_party.dart';
import '../../messages/models/chat_message.dart';
import '../../messages/providers/chat_inbox.dart';
import '../../messages/providers/chat_thread.dart';
import '../../messages/providers/unread_provider.dart';
import '../../messages/services/messages_service.dart';
import '../providers/trip_realtime_controller.dart';

/// One trip's chat with its passenger — the active job's (`/chat`) or any past
/// one (`/messages/:tripId`). Header and `canSend` come from the conversation,
/// live messages from `ChatInbox`. While this is on screen its messages are read.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.tripId,
    this.backFallback = '/messages',
    this.attachRealtime = false,
  });

  final String tripId;

  /// Where Back goes when there is nothing to pop (e.g. opened from a push).
  final String backFallback;

  /// The in-trip `/chat` route only: opened straight from the menu or after a
  /// restart, the realtime controller has no active trip yet, so attach it.
  /// Never for a past trip from the Messages list — that would make it "active".
  final bool attachRealtime;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  /// Captured in initState: `ref.read` throws from `dispose`.
  late final ChatInbox _inbox;

  @override
  void initState() {
    super.initState();
    _inbox = ref.read(chatInboxProvider);
    // Before the fetch, so a message landing mid-fetch doesn't raise a badge
    // for a chat that is already on screen.
    _inbox.openTripId = widget.tripId;
    ref.read(unreadProvider.notifier).clear(widget.tripId);
    Future.microtask(() async {
      if (widget.attachRealtime) {
        await ref.read(tripRealtimeProvider.notifier).attach(widget.tripId);
      }
      await ref.read(chatThreadProvider(widget.tripId).notifier).load();
      try {
        await ref.read(messagesServiceProvider).markRead(widget.tripId);
      } catch (_) {
        // Self-heals on the next open.
      }
    });
  }

  @override
  void dispose() {
    if (_inbox.openTripId == widget.tripId) _inbox.openTripId = null;
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    ref.read(chatThreadProvider(widget.tripId).notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(chatThreadProvider(widget.tripId));
    final conversation = thread.conversation;

    ref.listen<List<ChatMessage>>(
      chatThreadProvider(widget.tripId).select((s) => s.messages),
      (_, __) => _scrollToBottom(),
    );

    return Scaffold(
      backgroundColor: Brand.bg,
      body: Column(
        children: [
          _Header(
            name: (conversation?.counterpartName.isNotEmpty ?? false)
                ? conversation!.counterpartName
                : kCounterpartFallback,
            subtitle: conversation?.routeLabel ?? '',
            onBack: () => backOr(context, widget.backFallback),
          ),
          Expanded(child: _body(thread)),
          if (conversation != null && thread.canSend) ...[
            _QuickReplies(onTap: _send),
            _Composer(controller: _ctrl, onSend: () => _send()),
          ] else if (conversation != null)
            const ChatClosedBar(),
        ],
      ),
    );
  }

  Widget _body(ChatThreadState thread) {
    if (thread.loading && thread.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Brand.blue));
    }
    if (thread.error && thread.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Couldn't load messages.",
                style: tw(FontWeight.w700, 14, Brand.sub)),
            const SizedBox(height: 12),
            McGhostButton('Try again',
                full: false,
                onTap: () =>
                    ref.read(chatThreadProvider(widget.tripId).notifier).load()),
          ],
        ),
      );
    }
    if (thread.messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.\nSend one below!',
          textAlign: TextAlign.center,
          style: tw(FontWeight.w600, 14, Brand.faint),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: thread.messages.length,
      itemBuilder: (context, i) => _Bubble(
        message: thread.messages[i],
        isMine: thread.messages[i].senderType == kMe,
      ),
    );
  }
}

/// Replaces the composer once the chat has closed. History stays readable.
class ChatClosedBar extends StatelessWidget {
  const ChatClosedBar({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
            16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: Brand.paper,
          boxShadow: Brand.sheetShadow,
        ),
        child: Text(
          'This chat has closed',
          textAlign: TextAlign.center,
          style: tw(FontWeight.w700, 14, Brand.sub),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// UI widgets — unchanged layout, now driven by real data
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.subtitle, required this.onBack});
  final String name;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 56, 12, 12),
      decoration: const BoxDecoration(
        color: Brand.paper,
        boxShadow: Brand.cardShadow,
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Ico('back', size: 24, color: Brand.ink),
            ),
          ),
          const SizedBox(width: 6),
          const McAvatar(size: 42, color: Brand.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: tw(FontWeight.w900, 16)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tw(FontWeight.w600, 12, Brand.sub)),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Brand.fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Ico('phone', size: 20, color: Brand.ink)),
            ),
          ),
          const SizedBox(width: 8),
          const McMenuButton(),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(message.sentAtUtc.toLocal());
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: isMine ? Brand.blue : Brand.paper,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: Brand.cardShadow,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.content,
                style: tw(FontWeight.w600, 14.5,
                    isMine ? Colors.white : Brand.ink)),
            const SizedBox(height: 3),
            Text(timeStr,
                style: tw(FontWeight.w600, 10,
                    isMine ? Colors.white.withValues(alpha: 0.7) : Brand.faint)),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat.Hm().format(dt);
    }
    return DateFormat('d MMM, HH:mm').format(dt);
  }
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.onTap});
  final ValueChanged<String> onTap;

  static const _presets = ['On my way', "I'm outside", 'Running late', 'Here now'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) =>
            McChip(_presets[i], onTap: () => onTap(_presets[i])),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Brand.paper,
        boxShadow: Brand.sheetShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Brand.bg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Brand.line, width: 1.5),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                cursorColor: Brand.blue,
                style: tw(FontWeight.w600, 15, Brand.ink),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: InputBorder.none,
                  hintText: 'Message…',
                  hintStyle: tw(FontWeight.w600, 15, Brand.faint),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSend,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Brand.blue,
                shape: BoxShape.circle,
              ),
              child: const Center(child: Ico('send', size: 20, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
