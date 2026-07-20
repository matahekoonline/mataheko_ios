import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import 'category_form_screen.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: StreamBuilder<List<Category>>(
        stream: CategoryService.instance.allCategoriesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data!;
          if (categories.isEmpty) {
            return const Center(child: Text('No categories yet. Tap + to add one.'));
          }
          return _ReorderableCategoryList(categories: categories);
        },
      ),
    );
  }
}

/// Holds a local mutable copy of the list so drag-and-drop feels instant,
/// then persists the new order to Firestore via CategoryService.reorder.
class _ReorderableCategoryList extends StatefulWidget {
  final List<Category> categories;
  const _ReorderableCategoryList({required this.categories});

  @override
  State<_ReorderableCategoryList> createState() => _ReorderableCategoryListState();
}

class _ReorderableCategoryListState extends State<_ReorderableCategoryList> {
  late List<Category> _local;

  @override
  void initState() {
    super.initState();
    _local = List.of(widget.categories);
  }

  @override
  void didUpdateWidget(covariant _ReorderableCategoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep in sync with live Firestore updates (e.g. active toggle from
    // elsewhere), but don't fight an in-progress drag.
    _local = List.of(widget.categories);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _local.removeAt(oldIndex);
      _local.insert(newIndex, item);
    });
    await CategoryService.instance.reorder(_local);
  }

  Future<void> _delete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Remove "${category.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await CategoryService.instance.deleteCategory(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      itemCount: _local.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final category = _local[index];
        return Card(
          key: ValueKey(category.id),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              backgroundImage: category.hasIcon ? NetworkImage(category.iconUrl!) : null,
              child: category.hasIcon ? null : const Icon(Icons.category),
            ),
            title: Text(category.name),
            subtitle: Text(category.active ? 'Active' : 'Hidden'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: category.active,
                  onChanged: (v) => CategoryService.instance.setActive(category.id, v),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CategoryFormScreen(existing: category)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _delete(category),
                ),
                const Icon(Icons.drag_handle),
              ],
            ),
          ),
        );
      },
    );
  }
}