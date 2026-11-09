@TestOn('browser')
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tour_expense_tracker/firebase_options.dart';

void main() {
  test('the browser test can reach the emulators', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.web.copyWith(projectId: 'demo-taka-koi', storageBucket: 'demo-taka-koi.appspot.com'),
    );
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'nafis@taka.test', password: 'demo-pass-2468');
    final snap = await FirebaseFirestore.instance.doc('groups/g-coxs').get();
    expect(snap.exists, isTrue);
  });
}
