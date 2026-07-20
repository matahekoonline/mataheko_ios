import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';

/// Firestore-backed category management. Collection: `categories`.
/// Mirrors HeroBannerService's pattern exactly.
class CategoryService {
  CategoryService._();
  static final CategoryService instance = CategoryService._();

  final CollectionReference<Map<String, dynamic>> _collection =
  FirebaseFirestore.instance.collection('categories');

  /// Home screen grid: active categories only, ordered. Filtered client-side
  /// (not via a second `where`) for the same reason as HeroBannerService —
  /// avoids needing a composite index for `where` + `orderBy`.
  Stream<List<Category>> activeCategoriesStream() {
    return _collection.orderBy('order').snapshots().map((snap) => snap.docs
        .map((d) => Category.fromMap(d.id, d.data()))
        .where((c) => c.active)
        .toList());
  }

  /// Admin manage screen: every category, active or not.
  Stream<List<Category>> allCategoriesStream() {
    return _collection.orderBy('order').snapshots().map((snap) =>
        snap.docs.map((d) => Category.fromMap(d.id, d.data())).toList());
  }

  /// Reserves a Firestore doc id without writing anything yet — lets the
  /// add screen upload the icon to a path matching the eventual doc id
  /// before the document itself exists.
  String newCategoryId() => _collection.doc().id;

  Future<void> createCategoryWithId(Category category) async {
    await _collection.doc(category.id).set(category.toMap());
  }

  Future<void> updateCategory(Category category) async {
    await _collection.doc(category.id).set(category.toMap());
  }

  Future<void> deleteCategory(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> setActive(String id, bool active) async {
    await _collection.doc(id).update({'active': active});
  }

  /// Persists a new relative order for a full reordered list (called after
  /// drag-and-drop reordering in ManageCategoriesScreen).
  Future<void> reorder(List<Category> orderedCategories) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < orderedCategories.length; i++) {
      batch.update(_collection.doc(orderedCategories[i].id), {'order': i});
    }
    await batch.commit();
  }

  /// One-time convenience to migrate your existing hardcoded `categories`
  /// list into Firestore so the admin screen doesn't start empty.
  Future<void> seedCategories(List<String> names) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < names.length; i++) {
      final docRef = _collection.doc();
      batch.set(docRef, Category(id: docRef.id, name: names[i], order: i).toMap());
    }
    await batch.commit();
  }
}