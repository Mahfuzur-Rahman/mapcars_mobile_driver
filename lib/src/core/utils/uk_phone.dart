/// UK mobile numbers as typed next to the fixed "+44" field.
///
/// This is the same rule as the web (`web/src/lib/phone.ts`) and the customer
/// app. The API is still the authority: it repairs the same forms, and rejects
/// anything that isn't a UK mobile.
library;

/// The national digits of a UK mobile ("7" + 9 digits), or null if [input]
/// can't be one.
String? ukMobileDigits(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('44')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = digits.substring(1);
  return RegExp(r'^7\d{9}$').hasMatch(digits) ? digits : null;
}

/// "+447400123456" for a valid UK mobile, or null.
String? ukMobileE164(String input) {
  final digits = ukMobileDigits(input);
  return digits == null ? null : '+44$digits';
}

/// The part after "+44", for refilling the field next to the fixed prefix.
String nationalPart(String e164) => e164.startsWith('+44') ? e164.substring(3) : e164;
