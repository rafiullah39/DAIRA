import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _handleDelete(
      BuildContext context,
      String docId,
      String questName,
      bool deleteGlobal,
      String? templateId
      ) async {
    final batch = FirebaseFirestore.instance.batch();
    try {
      batch.delete(FirebaseFirestore.instance.collection('challenges').doc(docId));

      if (deleteGlobal && templateId != null) {
        batch.delete(FirebaseFirestore.instance.collection('challenges').doc(templateId));
      }

      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Quest Terminated."),
              backgroundColor: Colors.orange
          ),
        );
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  void _confirmDelete(BuildContext context, String docId, String questName, Map<String, dynamic> data) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    bool isArchitect = uid == data['creatorId'];
    String? templateId = data['templateId'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DairaTheme.surfaceGraphite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("DELETE QUEST?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Remove '$questName' from your dashboard?",
            style: const TextStyle(color: DairaTheme.slateGrey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL")
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleDelete(context, docId, questName, false, null);
            },
            child: const Text("DELETE FOR ME", style: TextStyle(color: Colors.white)),
          ),
          if (isArchitect)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleDelete(context, docId, questName, true, templateId);
              },
              child: const Text("DELETE EVERYWHERE",
                  style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(
        backgroundColor: DairaTheme.surfaceGraphite,
        elevation: 2,
        centerTitle: true,
        title: const Text(
          "DAIRA",
          style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.emoji_events_outlined, color: DairaTheme.accentOrange), onPressed: () => Navigator.pushNamed(context, '/leaderboard')),
          IconButton(icon: const Icon(Icons.account_circle_outlined, color: DairaTheme.accentOrange), onPressed: () => Navigator.pushNamed(context, '/profile')),
          // UPDATED: Changed icon to insights and set navigation to community_pulse
          IconButton(
            icon: const Icon(Icons.insights_rounded, color: DairaTheme.accentOrange),
            onPressed: () => Navigator.pushNamed(context, '/community_pulse'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildDynamicHeroSection(uid),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Expanded(child: _buildQuickAction(context, "AI Forge", Icons.bolt_rounded, '/ai_create')),
                  const SizedBox(width: 15),
                  Expanded(child: _buildQuickAction(context, "New Quest", Icons.add_rounded, '/create_challenge')),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 10, 24, 15),
              child: Text("MY ACTIVE QUESTS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: DairaTheme.accentOrange)),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('challenges')
                  .where('participantId', isEqualTo: uid)
                  .where('isTemplate', isEqualTo: false)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error syncing data.", style: TextStyle(color: Colors.white)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: DairaTheme.accentOrange));

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        // Corrected: Passing the whole data map to check creatorId
                        _confirmDelete(context, doc.id, data['name'] ?? "Quest", data);
                        return false;
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 30),
                      ),
                      child: _buildModernChallengeCard(context, doc.id, data),
                    );
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

  Widget _buildDynamicHeroSection(String? uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        String name = "Champion";
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
          name = userData['username'] ?? "Champion";
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('challenges')
              .where('participantId', isEqualTo: uid)
              .where('isTemplate', isEqualTo: false)
              .snapshots(),
          builder: (context, questSnapshot) {
            int totalQuests = 0;
            int completedToday = 0;

            if (questSnapshot.hasData) {
              totalQuests = questSnapshot.data!.docs.length;
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);

              for (var doc in questSnapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                Timestamp? lastDone = data['lastCompletedAt'];
                if (lastDone != null && lastDone.toDate().isAfter(todayStart)) {
                  completedToday++;
                }
              }
            }

            bool allDone = totalQuests > 0 && completedToday == totalQuests;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: DairaTheme.surfaceGraphite,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Welcome back,", style: TextStyle(color: DairaTheme.slateGrey, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: allDone ? Colors.green.withValues(alpha: 0.1) : DairaTheme.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: allDone ? Colors.green.withValues(alpha: 0.5) : DairaTheme.accentOrange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            allDone ? Icons.check_circle_rounded : Icons.bolt_rounded,
                            color: allDone ? Colors.greenAccent : DairaTheme.accentOrange,
                            size: 22
                        ),
                        const SizedBox(width: 6),
                        Text(
                            "$completedToday / $totalQuests",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickAction(BuildContext context, String title, IconData icon, String route) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: DairaTheme.accentOrange,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: () => Navigator.pushNamed(context, route),
      icon: Icon(icon, size: 20),
      label: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }

  Widget _buildModernChallengeCard(BuildContext context, String id, Map<String, dynamic> data) {
    double progress = (data['progress'] ?? 0.0).toDouble().clamp(0.0, 1.0);

    String missionTitle = "No mission set";
    List<dynamic> tasks = data['tasks'] ?? [];
    int totalTasks = tasks.length;

    int currentTaskIndex = (progress * totalTasks).floor();

    if (currentTaskIndex >= totalTasks && totalTasks > 0) {
      currentTaskIndex = totalTasks - 1;
    }

    int currentDay = currentTaskIndex + 1;

    if (tasks.isNotEmpty) {
      if (progress >= 1.0) {
        missionTitle = "Quest Completed! 🎉";
        currentDay = totalTasks;
      } else {
        var taskData = tasks[currentTaskIndex];
        if (taskData is Map) {
          missionTitle = taskData['taskName']?['title']?.toString() ??
              taskData['title']?.toString() ?? "Mission Objective";
        } else {
          missionTitle = taskData.toString();
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: DairaTheme.surfaceGraphite,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(24),
        onTap: () => Navigator.pushNamed(context, '/detail', arguments: id),
        title: Text(data['name'] ?? 'Untitled Quest',
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: DairaTheme.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "DAY $currentDay: $missionTitle",
                style: const TextStyle(
                  color: DairaTheme.accentOrange,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: DairaTheme.accentOrange,
                  backgroundColor: Colors.white.withValues(alpha: 0.05)
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("VIEW PROGRESS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: DairaTheme.accentOrange)),
                Icon(Icons.arrow_forward_rounded, size: 16, color: DairaTheme.accentOrange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 40, color: DairaTheme.slateGrey),
            SizedBox(height: 15),
            Text("No active quests found.", style: TextStyle(color: DairaTheme.slateGrey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}