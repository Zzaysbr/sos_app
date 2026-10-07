import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/sos_repository.dart';

class SosPage extends StatefulWidget {
  const SosPage({
    super.key,
    required this.repository,
    required this.user,
  });

  final SosRepository repository;
  final User user;

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  final _messageController = TextEditingController();

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();

    widget.repository.syncPending();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _createSos() async {
    if (_isCreating) {
      return;
    }

    final message = _messageController.text.trim();

    setState(() {
      _isCreating = true;
    });

    try {
      final id = DateTime.now().microsecondsSinceEpoch.toString();

      await widget.repository.create(
        id: id,
        type: 'emergency',
        message: message.isEmpty ? null : message,
      );

      if (!mounted) {
        return;
      }

      _messageController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS saved locally and synced when possible.'),
        ),
      );
    } on SosRepositoryException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create SOS.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _deleteSos(String id) async {
    try {
      await widget.repository.delete(id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS deleted.'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete SOS.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS'),
        actions: [
          IconButton(
            tooltip: 'Sync',
            onPressed: widget.repository.syncPending,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: widget.repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Database error.',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final messages = snapshot.data!;

          if (messages.isEmpty) {
            return const Center(
              child: Text(
                'No SOS messages',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final sos = messages[index];

              return Card(
                child: ListTile(
                  leading: Icon(
                    sos.status == 'active'
                        ? Icons.warning
                        : Icons.check_circle,
                  ),
                  title: Text(sos.type),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sos.message ?? 'No message',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sync: ${sos.syncState}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteSos(sos.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Emergency message',
                hintText: 'What happened?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isCreating ? null : _createSos,
                child: Text(
                  _isCreating ? 'Sending...' : 'SEND SOS',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}