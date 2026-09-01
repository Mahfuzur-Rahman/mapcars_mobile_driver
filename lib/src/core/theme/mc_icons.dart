import 'package:flutter/material.dart';

/// Maps the design's named icons (`Ico name="..."`) to Material icons, so screen
/// code can use the same names that appear in the JSX designs.
const Map<String, IconData> _kIcons = {
  'search': Icons.search,
  'pin': Icons.location_on_outlined,
  'dot': Icons.circle,
  'clock': Icons.schedule,
  'star': Icons.star_border,
  'starF': Icons.star,
  'card': Icons.credit_card,
  'user': Icons.person_outline,
  'phone': Icons.call,
  'chevR': Icons.chevron_right,
  'chevL': Icons.chevron_left,
  'chevD': Icons.keyboard_arrow_down,
  'back': Icons.arrow_back,
  'x': Icons.close,
  'plus': Icons.add,
  'menu': Icons.menu,
  'car': Icons.directions_car_filled_outlined,
  'nav': Icons.navigation,
  'shield': Icons.shield_outlined,
  'home': Icons.home_outlined,
  'heart': Icons.favorite_border,
  'cash': Icons.payments_outlined,
  'bolt': Icons.bolt,
  'gift': Icons.card_giftcard,
  'bell': Icons.notifications_outlined,
  'receipt': Icons.receipt_long_outlined,
  'msg': Icons.chat_bubble_outline,
  'mail': Icons.mail_outline,
  'lock': Icons.lock_outline,
  'send': Icons.send,
  'check': Icons.check,
  'cog': Icons.settings_outlined,
  'edit': Icons.edit_outlined,
  'plane': Icons.flight,
  'power': Icons.power_settings_new,
  'doc': Icons.description_outlined,
  'camera': Icons.photo_camera_outlined,
  'gallery': Icons.photo_library_outlined,
  'upload': Icons.file_upload_outlined,
  'bank': Icons.account_balance_outlined,
  'chart': Icons.bar_chart,
  'cal': Icons.calendar_today_outlined,
  'wheel': Icons.toll_outlined,
  'turn': Icons.turn_right,
  'wallet': Icons.account_balance_wallet_outlined,
  'trend': Icons.trending_up,
  'globe': Icons.language,
  'logout': Icons.logout,
  'alert': Icons.emergency_outlined,
  'access': Icons.accessible_outlined,
  'trash': Icons.delete_outline,
};

IconData icoData(String name) => _kIcons[name] ?? Icons.circle_outlined;

/// Convenience widget — `Ico('search', size: 20, color: ...)`.
class Ico extends StatelessWidget {
  const Ico(this.name, {super.key, this.size = 22, this.color});
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(icoData(name), size: size, color: color);
}
