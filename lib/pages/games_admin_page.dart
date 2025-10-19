import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coders_cup_minigame_admin/utils.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'add_game_page.dart';
import 'responses_page.dart';

class GamesAdminPage extends StatelessWidget {
  const GamesAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final gamesRef = FirebaseFirestore.instance.collection('games');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: gamesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No games'));

          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: isLandscape(context)
                  ? MediaQuery.of(context).size.width * 0.2
                  : MediaQuery.of(context).size.width * 0.05,
            ),
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final d = docs[i];
                final data = d.data();
                final name = (data['name'] as String?) ?? 'Unnamed';
                final limit = data['limit']?.toString() ?? '0';
                final active = (data['active'] as bool?) ?? true;
                return Opacity(
                  opacity: active ? 1.0 : 0.45,
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text(
                      'Limit: $limit • ${active ? 'Active' : 'Inactive'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final data = d.data();
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddGamePage(
                                  gameId: d.id,
                                  initialData: data,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete game?'),
                                content: Text(
                                  'Delete "$name" and all responses? This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            try {
                              // delete responses subcollection (best-effort batch)
                              final batch = FirebaseFirestore.instance.batch();
                              final responses = await FirebaseFirestore.instance
                                  .collection('games')
                                  .doc(d.id)
                                  .collection('responses')
                                  .limit(500)
                                  .get();
                              for (final r in responses.docs)
                                batch.delete(r.reference);

                              // attempt to delete associated storage files if paths exist
                              try {
                                final data = d.data();
                                final paths = <String?>[
                                  data['backgroundImagePath'] as String?,
                                  data['bottomLeftImagePath'] as String?,
                                  data['bottomRightImagePath'] as String?,
                                ];
                                for (final p in paths) {
                                  if (p != null && p.isNotEmpty) {
                                    await FirebaseStorage.instance
                                        .ref()
                                        .child(p)
                                        .delete();
                                  }
                                }
                              } catch (e) {
                                // best-effort: log but continue
                                // ignore storage delete errors
                              }

                              batch.delete(
                                FirebaseFirestore.instance
                                    .collection('games')
                                    .doc(d.id),
                              );
                              await batch.commit();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to delete: $e')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.list),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ResponsesPage(gameId: d.id, gameName: name),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddGamePage())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
