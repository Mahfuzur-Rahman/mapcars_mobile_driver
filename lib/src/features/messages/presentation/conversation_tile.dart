import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/mc.dart';
import '../chat_party.dart';
import '../models/conversation.dart';

/// "09:05" today, "Yesterday", else "30 Oct". [utc] is converted to [now]'s zone.
String chatTimeLabel(DateTime utc, DateTime now) {
  final t = utc.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return DateFormat.Hm().format(t);
  if (diff == 1) return 'Yesterday';
  return DateFormat('d MMM').format(t);
}

String previewText(ConversationPreview p) =>
    p.senderType == kMe ? 'You: ${p.content}' : p.content;

/// One conversation in the Messages list. [unread] comes from the live
/// `unreadProvider`, not the row, so it drops to zero the moment a chat is read.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.unread,
    this.onTap,
  });

  final Conversation conversation;
  final int unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final hasUnread = unread > 0;
    final last = c.lastMessage;
    final name =
        c.counterpartName.isEmpty ? kCounterpartFallback : c.counterpartName;

    return mcTapSemantics(
      label: hasUnread ? '$name, $unread unread' : name,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _Initials(name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tw(
                                  hasUnread ? FontWeight.w900 : FontWeight.w800,
                                  15,
                                  Brand.ink)),
                        ),
                        if (last != null)
                          Text(chatTimeLabel(last.sentAtUtc, DateTime.now()),
                              style: tw(FontWeight.w700, 12,
                                  hasUnread ? Brand.blue : Brand.sub)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(c.routeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tw(FontWeight.w600, 12, Brand.sub)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(last == null ? '' : previewText(last),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tw(
                                  hasUnread ? FontWeight.w800 : FontWeight.w600,
                                  13.5,
                                  hasUnread ? Brand.ink : Brand.sub)),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          McCountPill(unread),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return Container(
      width: 48,
      height: 48,
      decoration:
          const BoxDecoration(color: Brand.blue, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials.isEmpty ? '?' : initials,
          style: tw(FontWeight.w900, 16, Colors.white)),
    );
  }
}
