import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme.dart';
import 'creator_profile_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  int _calculateLevel(int xp) => (xp / 100).floor() + 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(
        backgroundColor: DairaTheme.surfaceGraphite,
        centerTitle: true,
        title: const Text("HALL OF LEGENDS",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 16)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('totalXP', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: DairaTheme.accentOrange));

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: users.length,
            itemBuilder: (context, index) {
              var doc = users[index];
              var data = doc.data() as Map<String, dynamic>;
              String userId = doc.id;
              int xp = data['totalXP'] ?? 0;
              int streak = data['streak'] ?? 0;
              int level = _calculateLevel(xp);
              String username = data['username'] ?? "Champion";

              bool isTopThree = index < 3;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DairaTheme.surfaceGraphite,
                  borderRadius: BorderRadius.circular(24),
                  border: isTopThree
                      ? Border.all(color: DairaTheme.accentOrange.withValues(alpha: 0.5), width: 2)
                      : Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatorProfileScreen(
                          creatorId: userId,
                          creatorName: username,
                        ),
                      ),
                    );
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 45, height: 45,
                    decoration: BoxDecoration(
                      color: isTopThree ? DairaTheme.accentOrange : DairaTheme.graphite,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text("${index + 1}",
                          style: TextStyle(
                              color: isTopThree ? Colors.black : Colors.white24,
                              fontWeight: FontWeight.w900
                          )
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(username,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      if (isTopThree) const Icon(Icons.stars_rounded, color: DairaTheme.accentOrange, size: 16),
                    ],
                  ),
                  subtitle: Text("LEVEL $level ARCHITECT",
                      style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("$xp XP",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: DairaTheme.accentOrange, size: 12),
                          Text("$streak", style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}