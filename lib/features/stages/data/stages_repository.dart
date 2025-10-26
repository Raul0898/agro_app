import 'package:cloud_firestore/cloud_firestore.dart';

class StagesRepository {
  final _db = FirebaseFirestore.instance;
  final String companyId;
  final String fieldId;
  final String workflowId;
  StagesRepository({required this.companyId, required this.fieldId, required this.workflowId});

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('companies').doc(companyId)
          .collection('fields').doc(fieldId)
          .collection('workflows').doc(workflowId)
          .collection('stages');

  Stream<List<Map<String, dynamic>>> watchAll() {
    return _col.orderBy('order').snapshots().map(
          (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    );
  }

  Future<void> add({required String id, required String title, int order = 1, List<String> prerequisites = const []}) {
    return _col.doc(id).set({
      'title': title,
      'order': order,
      'prerequisites': prerequisites,
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleComplete(String id, bool completed) => _col.doc(id).update({'completed': completed});
  Future<void> delete(String id) => _col.doc(id).delete();
}
