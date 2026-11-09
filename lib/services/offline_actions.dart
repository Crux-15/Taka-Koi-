import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/offline.dart';

/// Where an action's writes go: a transaction (online) or a batch (queued).
abstract class ActionWriter {
  void set(DocumentReference ref, Map<String, dynamic> data);
  void update(DocumentReference ref, Map<String, dynamic> data);
}

class _TxWriter implements ActionWriter {
  _TxWriter(this.tx);
  final Transaction tx;
  @override
  void set(DocumentReference ref, Map<String, dynamic> data) => tx.set(ref, data);
  @override
  void update(DocumentReference ref, Map<String, dynamic> data) => tx.update(ref, data);
}

class _BatchWriter implements ActionWriter {
  _BatchWriter(this.batch);
  final WriteBatch batch;
  @override
  void set(DocumentReference ref, Map<String, dynamic> data) => batch.set(ref, data);
  @override
  void update(DocumentReference ref, Map<String, dynamic> data) => batch.update(ref, data);
}

/// Runs an action that has to look at current data before writing (approving
/// an expense, confirming a payment, ...).
///
/// * Online: a transaction, so two people acting at once can't clash.
/// * Offline (or the server can't be reached): [decide] runs on this phone's
///   saved copy of the documents and its writes are queued. They sync when
///   the phone is back online, and the security rules check them then: if
///   someone else changed the same thing first, the queued change is refused
///   and the screen goes back to the real state.
///
/// [decide] gets the documents in the order of [reads] and must only write
/// through the given [ActionWriter]. Returns its result and whether the writes
/// were queued instead of confirmed by the server.
Future<({T result, bool queued})> decideAndWrite<T>(
  FirebaseFirestore db,
  List<DocumentReference> reads,
  T Function(List<DocumentSnapshot> docs, ActionWriter writer) decide,
) async {
  if (await isOnline()) {
    try {
      final result = await db.runTransaction<T>(timeout: transactionTimeout, (tx) async {
        final docs = <DocumentSnapshot>[];
        for (final ref in reads) {
          docs.add(await tx.get(ref));
        }
        return decide(docs, _TxWriter(tx));
      });
      return (result: result, queued: false);
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable' && e.code != 'deadline-exceeded') rethrow;
    } on TimeoutException {
      // fall through to the offline path
    }
  }

  final docs = <DocumentSnapshot>[];
  for (final ref in reads) {
    docs.add(await ref.get(const GetOptions(source: Source.cache)));
  }
  final batch  = db.batch();
  final result = decide(docs, _BatchWriter(batch));
  final synced = await saveOrQueue(batch.commit(), 'queued action');
  return (result: result, queued: !synced);
}
