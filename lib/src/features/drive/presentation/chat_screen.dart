import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/router/nav.dart';
import '../../../core/widgets/mc.dart';
import '../models/chat_message.dart';
import '../providers/trip_realtime_controller.dart';
import '../services/trip_service.dart';

/// In-trip chat with the current passenger.
///
/// Receives [Trip] via go_router `extra` (same pattern as `/nav-pickup`,
/// `/arrived`, `/driving`), or from `TripGate` when opened without one.
/// Messages are fetched from `GET /trips/{id}/messages` on mount, sent via
/// POST, and received live via the existing `messageReceived` SignalR push in
/// [TripRealtimeController].
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.trip});

  /// The trip being discussed — always a real one, supplied or resolved by
  /// `TripGate`.
  final Trip trip;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Attach before fetching: opened straight from the menu (or after a
    // restart) the controller has no active trip yet, and fetchMessages()
    // would no-op against a null id. Both calls are idempotent mid-trip.
    Future.microtask(() async {
      final realtime = ref.read(tripRealtimeProvider.notifier);
      await realtime.attach(widget.trip.id);
      await realtime.fetchMessages();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    ref.read(tripRealtimeProvider.notifier).sendMessage(text);
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
    final trip = widget.trip;
    final realtimeState = ref.watch(tripRealtimeProvider);
    final messages = realtimeState.chatMessages;

    // Rider name / subtitle from the trip. The API withholds rider details
    // until the trip is this driver's, so a name isn't guaranteed.
    final riderName = trip.rider?.name ?? 'Your rider';
    final riderSub = 'Passenger · ${trip.pickupAddress}';

    // Auto-scroll when new messages arrive.
    ref.listen<List<ChatMessage>>(
      tripRealtimeProvider.select((s) => s.chatMessages),
      (_, __) => _scrollToBottom(),
    );

    return Scaffold(
      backgroundColor: Brand.bg,
      body: Column(
        children: [
          _Header(
            name: riderName,
            subtitle: riderSub,
            onBack: () => backOr(context, '/nav-pickup'),
          ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet.\nSend one below!',
                      textAlign: TextAlign.center,
                      style: tw(FontWeight.w600, 14, Brand.faint),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => _Bubble(
                      message: messages[i],
                      isMine: messages[i].senderType == 'driver',
                    ),
                  ),
          ),
          _QuickReplies(onTap: _send),
          _Composer(controller: _ctrl, onSend: () => _send()),
        ],
      ),
    );
  }
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
