import 'package:cloud_firestore/cloud_firestore.dart';

class WorkflowsRepository {
  final _db = FirebaseFirestore.instance;
  final String companyId;
  final String fieldId;
  WorkflowsRepository({required this.companyId, required this.fieldId});

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('companies').doc(companyId)
          .collection('fields').doc(fieldId)
          .collection('workflows');

  Stream<List<Map<String, dynamic>>> watchAll() {
    return _col.orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    );
  }

  Future<void> add({required String name}) {
    return _col.add({'name': name, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> rename(String id, String name) => _col.doc(id).update({'name': name});
  Future<void> delete(String id) => _col.doc(id).delete();
}
