/// State of one bKash number request, as the requester sees it.
///
/// The number only exists here once the other person accepts; it's copied in
/// from their profile, which nobody else can read.
class BkashShare {
  final String  status; // 'pending' | 'accepted' | 'declined'
  final String? number;

  /// Accepted before numbers were shared this way, so there's no number to
  /// show. Treated like "not requested yet" so it can be asked for again.
  final bool legacy;

  const BkashShare({required this.status, this.number, this.legacy = false});

  factory BkashShare.fromMap(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'pending';
    return BkashShare(
      status: status,
      number: data['number'] as String?,
      legacy: status == 'accepted' && !data.containsKey('number'),
    );
  }

  bool get isPending  => status == 'pending';
  bool get isAccepted => status == 'accepted' && !legacy;
}
