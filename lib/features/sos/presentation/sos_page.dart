import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
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
  bool _syncing = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPending();
    });
  }

  Future<void> _syncPending() async {
    if (_syncing) {
      return;
    }

    setState(() {
      _syncing = true;
    });

    try {
      await widget.repository.syncPending();
    } catch (error, stackTrace) {
      debugPrint('SOS sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to sync SOS data.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _sendSos() async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    try {
      await widget.repository.create(
        id: id,
        type: 'emergency',
        message: 'Emergency SOS',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS sent.'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Create SOS failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send SOS.'),
        ),
      );
    }
  }

  Future<void> _editSos({
    required String id,
    required String currentMessage,
  }) async {
    final controller = TextEditingController(
      text: currentMessage,
    );

    try {
      final newMessage = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit SOS'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(
                    controller.text.trim(),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (!mounted || newMessage == null) {
        return;
      }

      await widget.repository.update(
        id: id,
        type: 'emergency',
        message: newMessage.isEmpty ? null : newMessage,
        status: 'active',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS updated.'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Update SOS failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update SOS.'),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteSos(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete SOS?'),
          content: const Text(
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

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
    } catch (error, stackTrace) {
      debugPrint('Delete SOS failed: $error');
      debugPrintStack(stackTrace: stackTrace);

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

  Widget _buildMySosList() {
    return StreamBuilder<List<SosMessage>>(
      stream: widget.repository.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Failed to load SOS data.',
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final sosList = snapshot.data ?? [];

        if (sosList.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No SOS messages yet.',
              ),
            ),
          );
        }

        return Column(
          children: sosList.map(
            (sos) {
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.warning,
                    color: Colors.red,
                  ),
                  title: Text(
                    sos.message?.isNotEmpty == true
                        ? sos.message!
                        : 'Emergency SOS',
                  ),
                  subtitle: Text(
                    'Status: ${sos.status}\n'
                    'Sync: ${sos.syncState}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _editSos(
                            id: sos.id,
                            currentMessage: sos.message ?? '',
                          );
                          break;

                        case 'delete':
                          _deleteSos(sos.id);
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ];
                    },
                  ),
                ),
              );
            },
          ).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS'),
        actions: [
          IconButton(
            tooltip: 'Sync',
            onPressed: _syncing ? null : _syncPending,
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync),
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
      body: RefreshIndicator(
        onRefresh: _syncPending,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _sendSos,
                icon: const Icon(Icons.sos),
                label: const Text(
                  'SEND SOS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'My SOS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildMySosList(),
          ],
        ),
      ),
    );
  }
}