// Wire compatibility across the Rider -> Customer rename.
//
// The API speaks the old vocabulary until migration 031 and the new one after,
// and a mobile build cannot be swapped in the moment that happens — a store
// release is days. So this build has to understand both, and every case below
// is one that would fail SILENTLY rather than throw:
//
//   * a sender type that stops matching means the unread badge quietly stops
//     counting, and chat goes back to being invisible;
//   * a trip status that falls through to `unknown` means a cancelled job stays
//     on screen looking live;
//   * a passenger object read from the wrong key means the driver's pickup card
//     shows no name at all.
//
// None of those surface as an error, which is exactly why they are pinned here.

import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_driver/src/features/drive/models/chat_message.dart';
import 'package:mapcars_driver/src/features/drive/services/trip_service.dart';

Map<String, dynamic> _msgJson(String senderType) => {
      'id': 'm1',
      'tripId': 't1',
      'senderType': senderType,
      'senderId': 's1',
      'content': 'Which entrance?',
      'sentAtUtc': '2026-09-01T12:00:00Z',
    };

Map<String, dynamic> _tripJson({Map<String, dynamic>? extra}) => {
      'id': 't1',
      'status': 'Requested',
      'pickupAddress': 'A',
      'dropoffAddress': 'B',
      'pickupLat': 51.5,
      'pickupLng': -0.1,
      'dropoffLat': 51.6,
      'dropoffLng': -0.2,
      'createdAtUtc': '2026-09-01T12:00:00Z',
      ...?extra,
    };

void main() {
  group('chat sender type', () {
    test('the legacy passenger spelling is folded onto the new one', () {
      expect(ChatMessage.fromJson(_msgJson('rider')).senderType, 'customer');
    });

    test('the new spelling passes through unchanged', () {
      expect(ChatMessage.fromJson(_msgJson('customer')).senderType, 'customer');
    });

    test('driver is untouched by the folding', () {
      expect(ChatMessage.fromJson(_msgJson('driver')).senderType, 'driver');
    });

    test('a message from the passenger counts as unread under EITHER spelling',
        () {
      // This is the assertion that actually protects the badge: whichever word
      // the API is using that week, otherParty is only ever 'customer'.
      for (final wire in ['rider', 'customer']) {
        expect(
          unreadAfter(
            current: 0,
            message: ChatMessage.fromJson(_msgJson(wire)),
            otherParty: 'customer',
            chatOpen: false,
          ),
          1,
          reason: 'sender type "$wire" should have counted as unread',
        );
      }
    });
  });

  group('trip status', () {
    test('both cancelled-by-passenger spellings parse to the same state', () {
      expect(TripStatus.fromJson('CancelledByRider'),
          TripStatus.cancelledByCustomer);
      expect(TripStatus.fromJson('CancelledByCustomer'),
          TripStatus.cancelledByCustomer);
    });

    test('an unrecognised status is still unknown, not a crash', () {
      expect(TripStatus.fromJson('SomethingNew'), TripStatus.unknown);
      expect(TripStatus.fromJson(null), TripStatus.unknown);
    });
  });

  group('nested passenger object', () {
    test('reads the new key', () {
      final t = Trip.fromJson(_tripJson(extra: {
        'customer': {'name': 'Ada', 'rating': 4.9},
      }));
      expect(t.customer?.name, 'Ada');
    });

    test('falls back to the legacy key', () {
      final t = Trip.fromJson(_tripJson(extra: {
        'rider': {'name': 'Ada', 'rating': 4.9},
      }));
      expect(t.customer?.name, 'Ada');
    });

    test('prefers the new key when the API sends both', () {
      // The API dual-emits during the transition. Whichever it sends, the
      // driver must see a name rather than a blank pickup card.
      final t = Trip.fromJson(_tripJson(extra: {
        'customer': {'name': 'New', 'rating': 5.0},
        'rider': {'name': 'Old', 'rating': 4.0},
      }));
      expect(t.customer?.name, 'New');
    });

    test('absent passenger stays null rather than throwing', () {
      expect(Trip.fromJson(_tripJson()).customer, isNull);
    });
  });
}
