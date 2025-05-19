import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier.dart';

class SupplierRepository {
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _suppliersCollection;

  SupplierRepository() : _firestore = FirebaseFirestore.instance {
    _suppliersCollection = _firestore.collection('suppliers');
  }

  // Stream pro real-time aktualizaci dodavatelů.
  Stream<List<Supplier>> get suppliersStream {
    return _suppliersCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Supplier.fromJson(data);
      }).toList();
    });
  }

  Future<List<Supplier>> fetchSuppliers() async {
    final snapshot = await _suppliersCollection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Supplier.fromJson(data);
    }).toList();
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _suppliersCollection.doc(supplier.id).set(supplier.toJson());
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _suppliersCollection.doc(supplier.id).update(supplier.toJson());
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _suppliersCollection.doc(supplierId).delete();
  }
}
