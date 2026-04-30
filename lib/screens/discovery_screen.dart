import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'user_search_screen.dart';
import 'creator_profile_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  String _sortBy = 'createdAt';

  Future<void> _joinQuest(BuildContext context, Map<String, dynamic> data, String templateId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String? architectId = data['creatorUid'] ?? data['creatorId'];

    try {
      final batch = FirebaseFirestore.instance.batch();
      final personalRef = FirebaseFirestore.instance.collection('challenges').doc();

      batch.set(personalRef, {
        'name': data['name'],
        'participantId': user.uid,
        'creatorId': architectId,
        'templateId': templateId,
        'totalDays': data['totalDays'] ?? 30,
        'progress': 0.0,
        'daysCompleted': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'startDate': FieldValue.serverTimestamp(),
        'isTemplate': false,
        'type': 'Personal Copy',
        'tasks': data['tasks'] ?? [],
        'lastCompletedAt': null,
      });

      final templateRef = FirebaseFirestore.instance.collection('challenges').doc(templateId);
      batch.update(templateRef, {'joinCount': FieldValue.increment(1)});

      if (architectId != null && architectId != user.uid) {
        final architectRef = FirebaseFirestore.instance.collection('users').doc(architectId);
        batch.update(architectRef, {'totalXP': FieldValue.increment(50)});
      }

      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QUEST JOINED! +50 XP SENT TO ARCHITECT"), backgroundColor: DairaTheme.accentOrange),
        );
      }
    } catch (e) {
      debugPrint("Join error: $e");
    }
  }

  Future<void> _toggleKudos(String challengeId, Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final String? receiverId = data['creatorUid'] ?? data['creatorId'];
    if (receiverId == null) return;

    final String kudosId = "${uid}_$challengeId";
    final docRef = FirebaseFirestore.instance.collection('alerts').doc(kudosId);
    final templateRef = FirebaseFirestore.instance.collection('challenges').doc(challengeId);

    HapticFeedback.mediumImpact();

    try {
      final doc = await docRef.get();
      final batch = FirebaseFirestore.instance.batch();

      if (doc.exists) {
        batch.delete(docRef);
        batch.update(templateRef, {'kudosCount': FieldValue.increment(-1)});
      } else {
        batch.set(docRef, {
          'userId': receiverId,
          'senderId': uid,
          'challengeId': challengeId,
          'type': 'kudos',
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.update(templateRef, {'kudosCount': FieldValue.increment(1)});
        if (receiverId != uid) {
          final receiverRef = FirebaseFirestore.instance.collection('users').doc(receiverId);
          batch.update(receiverRef, {'totalXP': FieldValue.increment(10)});
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint("❌ FIREBASE ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(
        title: const Text("DISCOVER", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 14)),
        backgroundColor: DairaTheme.surfaceGraphite,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_rounded, color: DairaTheme.accentOrange),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserSearchScreen())),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildEnhancedLiveIntel(),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TRENDING QUESTS", style: TextStyle(color: DairaTheme.accentOrange, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),

                  Theme(
                    data: Theme.of(context).copyWith(
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                    ),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: DairaTheme.surfaceGraphite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          dropdownColor: DairaTheme.surfaceGraphite,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: DairaTheme.accentOrange, size: 14),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                          borderRadius: BorderRadius.circular(12),
                          alignment: AlignmentDirectional.center,
                          onChanged: (value) {
                            if (value != null) setState(() => _sortBy = value);
                          },
                          items: const [
                            DropdownMenuItem(value: 'createdAt', child: Text("NEWEST")),
                            DropdownMenuItem(value: 'kudosCount', child: Text("MOST LIKED")),
                            DropdownMenuItem(value: 'joinCount', child: Text("MOST POPULAR")),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: _sortBy == 'createdAt'
                  ? FirebaseFirestore.instance
                  .collection('challenges')
                  .where('isTemplate', isEqualTo: true)
                  .orderBy('createdAt', descending: true)
                  .snapshots()
                  : FirebaseFirestore.instance
                  .collection('challenges')
                  .where('isTemplate', isEqualTo: true)
                  .orderBy(_sortBy, descending: true)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.only(top: 50.0),
                    child: CircularProgressIndicator(color: DairaTheme.accentOrange),
                  ));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("NO QUESTS FOUND", style: TextStyle(color: DairaTheme.slateGrey, fontSize: 10)));
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    return _buildQuestCard(context, doc.data() as Map<String, dynamic>, doc.id);
                  },
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestCard(BuildContext context, Map<String, dynamic> data, String id) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final String kudosId = "${currentUser?.uid}_$id";
    int kudosCount = data['kudosCount'] ?? 0;
    int joinCount = data['joinCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: DairaTheme.surfaceGraphite,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    final cId = data['creatorUid'] ?? data['creatorId'];
                    if (cId != null) {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatorProfileScreen(
                            creatorId: cId,
                            creatorName: data['createdBy'] ?? "Legend",
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: DairaTheme.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: DairaTheme.accentOrange.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_rounded, size: 10, color: DairaTheme.accentOrange),
                        const SizedBox(width: 6),
                        Text(
                          "FORGED BY ${data['createdBy']?.toString().toUpperCase() ?? 'LEGEND'}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 12, color: DairaTheme.accentOrange),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.groups_rounded, size: 12, color: DairaTheme.slateGrey),
                      const SizedBox(width: 4),
                      Text("$joinCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(data['name'] ?? "Quest", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('alerts').doc(kudosId).snapshots(),
                  builder: (context, snapshot) {
                    bool hasLiked = snapshot.hasData && snapshot.data!.exists;
                    return Row(
                      children: [
                        Text("$kudosCount", style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(hasLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: DairaTheme.accentOrange, size: 20),
                          onPressed: () => _toggleKudos(id, data),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: DairaTheme.accentOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () => _joinQuest(context, data, id),
                child: const Text("JOIN QUEST", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedLiveIntel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Icon(Icons.sensors_rounded, color: Colors.redAccent, size: 12),
              SizedBox(width: 6),
              Text("LIVE INTEL", style: TextStyle(color: DairaTheme.slateGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 110,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('activity').orderBy('timestamp', descending: true).limit(10).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var act = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  DateTime? time = (act['timestamp'] as Timestamp?)?.toDate();
                  String timeLabel = time != null ? "${DateTime.now().difference(time).inMinutes}m ago" : "LIVE";

                  return Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 15),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DairaTheme.surfaceGraphite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: DairaTheme.accentOrange.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(act['username']?.toString().toUpperCase() ?? "UNKNOWN",
                                style: const TextStyle(color: DairaTheme.accentOrange, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1)),
                            Text(timeLabel, style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 7, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("Day ${act['day']}: ${act['battleCry']}",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}