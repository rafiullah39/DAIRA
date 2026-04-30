import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class CommunityPulseScreen extends StatelessWidget {
  const CommunityPulseScreen({super.key});

  Stream<int> _getInFlowCount() {
    final thirtyMinsAgo = DateTime.now().subtract(const Duration(minutes: 30));
    return FirebaseFirestore.instance
        .collection('activity')
        .where('timestamp', isGreaterThan: thirtyMinsAgo)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<double> _getFocusRate() {
    return FirebaseFirestore.instance.collection('users').snapshots().asyncMap((userSnap) async {
      final totalUsers = userSnap.docs.length;
      if (totalUsers == 0) return 0.0;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final activitySnap = await FirebaseFirestore.instance
          .collection('activity')
          .where('timestamp', isGreaterThan: startOfDay)
          .get();

      final uniqueFinishers = activitySnap.docs.map((doc) => doc['userId']).toSet().length;
      return (uniqueFinishers / totalUsers).clamp(0.0, 1.0);
    });
  }

  Stream<Map<int, int>> _getHourlyActivity() {
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    return FirebaseFirestore.instance
        .collection('activity')
        .where('timestamp', isGreaterThan: twentyFourHoursAgo)
        .snapshots()
        .map((snap) {
      Map<int, int> hourlyCounts = {};
      for (int i = 0; i < 12; i++) {
        int hour = (DateTime.now().hour - i) % 24;
        if (hour < 0) hour += 24;
        hourlyCounts[hour] = 0;
      }
      for (var doc in snap.docs) {
        final timestamp = (doc['timestamp'] as Timestamp).toDate();
        final hour = timestamp.hour;
        if (hourlyCounts.containsKey(hour)) {
          hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
        }
      }
      return hourlyCounts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("COMMUNITY PULSE",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 12, color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildGlobalWorkloadBar(),
            const SizedBox(height: 25),
            _buildRealTimeGraphCard(),
            const SizedBox(height: 25),
            _buildStatsRow(),
            const SizedBox(height: 40),
            _buildStreamHeader(),
            _buildMinimalistFeed(),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalWorkloadBar() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('challenges').where('isTemplate', isEqualTo: false).snapshots(),
        builder: (context, challengeSnap) {
          return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activity')
                  .where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)))
                  .snapshots(),
              builder: (context, activitySnap) {
                int totalActiveQuests = challengeSnap.hasData ? challengeSnap.data!.docs.length : 1;
                int totalCompletedToday = activitySnap.hasData ? activitySnap.data!.docs.length : 0;
                double progress = (totalCompletedToday / totalActiveQuests).clamp(0.0, 1.0);

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("GLOBAL WORKLOAD CLEARED", style: TextStyle(color: DairaTheme.slateGrey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        Text("${(progress * 100).toStringAsFixed(1)}%", style: const TextStyle(color: DairaTheme.accentOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.05),
                        color: DairaTheme.accentOrange,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text("$totalCompletedToday tasks finished out of $totalActiveQuests active goals",
                          style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 8)),
                    )
                  ],
                );
              }
          );
        }
    );
  }

  Widget _buildRealTimeGraphCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DairaTheme.surfaceGraphite,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Hourly Output", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          const Text("Activity distribution (24h Window)", style: TextStyle(color: DairaTheme.slateGrey, fontSize: 11)),
          const SizedBox(height: 40),

          StreamBuilder<Map<int, int>>(
            stream: _getHourlyActivity(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));

              final data = snapshot.data!;
              final sortedHours = data.keys.toList()..sort();
              final maxVal = data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: sortedHours.map((hour) {
                  int count = data[hour] ?? 0;
                  bool isPeak = count == maxVal && count > 0;
                  double barHeight = (count / maxVal) * 100;

                  return Column(
                    children: [
                      if (isPeak)
                        const Icon(Icons.flash_on_rounded, color: DairaTheme.accentOrange, size: 10),
                      Text(count.toString(), style: TextStyle(color: isPeak ? Colors.white : DairaTheme.accentOrange, fontSize: 8, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        width: 14,
                        height: barHeight + 4,
                        decoration: BoxDecoration(
                          color: isPeak ? DairaTheme.accentOrange : DairaTheme.accentOrange.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isPeak ? [BoxShadow(color: DairaTheme.accentOrange.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)] : [],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("${hour}h", style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 7, fontWeight: FontWeight.bold)),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        StreamBuilder<double>(
            stream: _getFocusRate(),
            builder: (context, snapshot) {
              String val = snapshot.hasData ? "${(snapshot.data! * 100).toStringAsFixed(0)}%" : "...";
              return _smallStatCard("FOCUS RATE", val, Icons.track_changes_rounded);
            }
        ),
        const SizedBox(width: 15),
        StreamBuilder<int>(
            stream: _getInFlowCount(),
            builder: (context, snapshot) {
              String count = snapshot.hasData ? snapshot.data.toString() : "...";
              return _smallStatCard("IN-FLOW", count, Icons.group_work_rounded);
            }
        ),
      ],
    );
  }

  Widget _smallStatCard(String label, String val, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DairaTheme.surfaceGraphite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: DairaTheme.accentOrange, size: 16),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamHeader() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text("MOMENTUM STREAM",
            style: TextStyle(color: DairaTheme.slateGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
    );
  }

  Widget _buildMinimalistFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('activity').orderBy('timestamp', descending: true).limit(10).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            DateTime time = (data['timestamp'] as Timestamp).toDate();
            final diff = DateTime.now().difference(time);
            String timeLabel = diff.inMinutes < 60 ? "${diff.inMinutes}m" : "${diff.inHours}h";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: DairaTheme.accentOrange),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "${data['username']} completed ${data['questName']}",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(timeLabel, style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 11)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}