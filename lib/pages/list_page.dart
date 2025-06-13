import 'package:flutter/material.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final List<String> _listItems = [];
  int? _editingIndex;
  final TextEditingController _editController = TextEditingController();

  void _addListItem() {
    setState(() {
      _listItems.add('Item ${_listItems.length + 1}');
    });
  }

  void _startEditing(int index) {
    _editController.text = _listItems[index];
    setState(() {
      _editingIndex = index;
    });
  }

  void _finishEditing(String value) {
    if (_editingIndex != null) {
      setState(() {
        _listItems[_editingIndex!] = value;
        _editingIndex = null;
      });
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: _listItems.length,
        itemBuilder: (context, index) {
          if (_editingIndex == index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outline_blank),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _editController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                      ),
                      onSubmitted: _finishEditing,
                      onEditingComplete: () => _finishEditing(_editController.text),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => _finishEditing(_editController.text),
                  ),
                ],
              ),
            );
          }
          return ListTile(
            title: Text(_listItems[index]),
            leading: const Icon(Icons.check_box_outline_blank),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _startEditing(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      _listItems.removeAt(index);
                    });
                  },
                ),
              ],
            ),
            onTap: () => _startEditing(index),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addListItem,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }
} 