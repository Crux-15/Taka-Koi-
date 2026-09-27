import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Sends OTP emails via the EmailJS REST API.
class EmailService {
  static const _serviceId  = 'service_26nigmr';
  static const _templateId = 'template_ol2mjd8';
  static const _publicKey  = 'ty8WJZj7LDToXpIHg';
  static const _apiUrl     = 'https://api.emailjs.com/api/v1.0/email/send';

  /// Generates a random 6-digit numeric OTP.
  static String generateOtp() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  /// Sends [otp] to [toEmail].
  /// Returns null on success, or an error message string on failure.
  static Future<String?> sendOtp({
    required String toEmail,
    required String toName,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          // EmailJS REST API requires an origin header from non-browser clients.
          // 'localhost' is always whitelisted by default in EmailJS accounts.
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _templateId,
          'user_id':     _publicKey,
          'template_params': {
            'to_name':  toName.isNotEmpty ? toName : 'User',
            'to_email': toEmail,
            'otp_code': otp,
          },
        }),
      );

      if (response.statusCode == 200) return null; // null = success

      // Return the actual server error so we can diagnose it
      final body = response.body.isNotEmpty ? response.body : 'Unknown error';
      return 'EmailJS error (${response.statusCode}): $body';
    } catch (e) {
      return 'Network error: $e';
    }
  }
}
