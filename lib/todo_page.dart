import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _titleController = TextEditingController();
  final _userId = Supabase.instance.client.auth.currentUser!.id;
  XFile? _pickedImage;
  bool _isLoading = false;
  bool _isPublic = false;
  final _picker = ImagePicker();

  Future<void> _pickImageFromGallery() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _pickedImage = image);
    }
  }

  Future<void> _pickImageFromCamera() async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() => _pickedImage = image);
    }
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';

    final path = await Supabase.instance.client.storage
        .from('task-photos')
        .uploadBinary(fileName, bytes);

    if (path == null) {
      throw Exception('Image upload failed');
    }

    final publicUrl = Supabase.instance.client.storage
        .from('task-photos')
        .getPublicUrl(fileName);

    return publicUrl;
  }

  Future<void> _addTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un título para la tarea.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_pickedImage != null) {
        imageUrl = await _uploadImage(_pickedImage!);
      }

      await Supabase.instance.client.from('todos').insert({
        'user_id': _userId,
        'title': title,
        'is_complete': false,
        'photo_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
        'tarea_publica': _isPublic,
      });

      _titleController.clear();
      setState(() {
        _pickedImage = null;
        _isPublic = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar tarea: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadTodos() async {
    final res = await Supabase.instance.client
        .from('todos')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> _toggleTodo(String id, bool isComplete) async {
    await Supabase.instance.client
        .from('todos')
        .update({'is_complete': !isComplete})
        .eq('id', id);
    setState(() {});
  }

  Future<void> _deleteTodo(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de eliminar esta tarea?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    await Supabase.instance.client.from('todos').delete().eq('id', id);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tarea eliminada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
          )
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Nueva tarea',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.edit),
                            ),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            title: const Text('Compartir tarea'),
                            value: _isPublic,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) => setState(() => _isPublic = val ?? false),
                          ),
                          if (_pickedImage != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_pickedImage!.path),
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Galería'),
                                onPressed: _pickImageFromGallery,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Cámara'),
                                onPressed: _pickImageFromCamera,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: ElevatedButton.icon(
                                    icon: _isLoading
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.add),
                                    label: Text(_isLoading ? 'Agregando...' : 'Agregar'),
                                    onPressed: _isLoading ? null : _addTask,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadTodos(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 50),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final todos = snapshot.data ?? [];
                      if (todos.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 50),
                          child: Center(
                            child: Text(
                              'No hay tareas aún.',
                              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600], fontSize: 16),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: todos.length,
                        itemBuilder: (context, index) {
                          final todo = todos[index];
                          final isComplete = todo['is_complete'] as bool;
                          final createdAt = DateTime.parse(todo['created_at']);
                          final isPublic = todo['tarea_publica'] as bool? ?? false;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: todo['photo_url'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        todo['photo_url'],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: isComplete ? Colors.green[300] : Colors.grey[300],
                                      child: Icon(
                                        isComplete ? Icons.check : Icons.task_alt,
                                        color: Colors.white,
                                      ),
                                    ),
                              title: Text(
                                todo['title'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  decoration:
                                      isComplete ? TextDecoration.lineThrough : TextDecoration.none,
                                ),
                              ),
                              subtitle: Text(
                                '${DateFormat.yMMMd().add_jm().format(createdAt)}${isPublic ? " • Compartida" : ""}',
                                style: TextStyle(
                                  color: isComplete ? Colors.grey : null,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: isComplete,
                                    onChanged: (_) => _toggleTodo(todo['id'], isComplete),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar tarea',
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red[400],
                                    onPressed: () => _deleteTodo(todo['id']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
