import 'package:cloud_firestore/cloud_firestore.dart';

class FieldsRepository {
  final _db = FirebaseFirestore.instance;
  final String companyId;
  FieldsRepository({required this.companyId});

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('companies').doc(companyId).collection('fields');

  Stream<List<Map<String, dynamic>>> watchAll() {
    return _col.orderBy('name').snapshots().map(
          (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    );
  }

  Future<void> add({required String name, String? crop}) {
    return _col.add({'name': name, 'crop': crop, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> update({required String id, required String name, String? crop}) {
    return _col.doc(id).update({'name': name, 'crop': crop});
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
