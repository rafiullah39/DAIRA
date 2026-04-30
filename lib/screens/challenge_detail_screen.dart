import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({super.key});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  bool _isSubmitting = false;
  Timer? _timer;
  String _timeUntilNext = "CALCULATING...";
  bool _canSubmit = false;
  final TextEditingController _battleCryController = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _battleCryController.dispose();
    super.dispose();
  }


  Map<String, String> _getMissionContent(dynamic task) {
    if (task == null) return {"title": "NO MISSION", "details": "", "intel": ""};
    if (task is Map) {
      final Map<String, dynamic> taskMap = Map<String, dynamic>.from(task);
      return {
        "title": taskMap['title']?.toString() ?? "Mission Objective",
        "details": taskMap['details']?.toString() ?? "",
        "intel": taskMap['intel']?.toString() ?? "Standard tactical protocol applies."
      };
    }
    return {"title": task.toString(), "details": "", "intel": ""};
  }


  void _showMissionBriefing(BuildContext context, Map<String, String> content, int day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DairaTheme.surfaceGraphite,
      isScrollControlled: true, // Allows it to be taller if text is long
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: DairaTheme.surfaceGraphite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("DAY $day TACTICAL INTEL",
                      style: const TextStyle(color: DairaTheme.accentOrange, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2)),
                  IconButton(
                    icon: const Icon(Icons.close, color: DairaTheme.slateGrey),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Text(content['title']!,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(content['details']!,
                  style: const TextStyle(color: DairaTheme.accentOrange, fontSize: 14, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white10, height: 40),
              const Text("THE BRIEFING:",
                  style: TextStyle(color: DairaTheme.slateGrey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    content['intel']!,
                    style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DairaTheme.accentOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("READY TO FORGE",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _handleDelete(String docId, String questName, bool deleteGlobal, String? templateId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();

    try {
      batch.delete(FirebaseFirestore.instance.collection('challenges').doc(docId));
      if (deleteGlobal && templateId != null) {
        batch.delete(FirebaseFirestore.instance.collection('challenges').doc(templateId));
      }
      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deleteGlobal ? "QUEST ERASED FROM HISTORY" : "QUEST REMOVED FROM DASHBOARD"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  void _showDeleteDialog(String docId, String questName, Map<String, dynamic> data) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    bool isArchitect = uid == data['creatorId'];
    String? templateId = data['templateId'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DairaTheme.surfaceGraphite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("TERMINATE QUEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
        content: const Text("Choose the scale of deletion. This action cannot be undone.",
            style: TextStyle(color: DairaTheme.slateGrey, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: DairaTheme.slateGrey))),
          TextButton(onPressed: () => _handleDelete(docId, questName, false, null), child: const Text("DELETE FOR ME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          if (isArchitect)
            TextButton(
                onPressed: () => _handleDelete(docId, questName, true, templateId),
                child: const Text("DELETE EVERYWHERE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
            ),
        ],
      ),
    );
  }


  void _checkStreakReset(String docId, Timestamp? lastCompletedAt, int currentDays) async {
    if (lastCompletedAt == null || currentDays == 0) return;
    final DateTime lastTime = lastCompletedAt.toDate();
    final DateTime now = DateTime.now();
    if (now.difference(lastTime).inHours >= 48) {
      await FirebaseFirestore.instance.collection('challenges').doc(docId).update({
        'daysCompleted': 0,
        'progress': 0.0,
        'lastCompletedAt': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("STREAK BROKEN: Progress reset to Day 0"), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _startCountdown(Timestamp? lastCompletedAt) {
    _timer?.cancel();
    if (lastCompletedAt == null) {
      if (mounted) setState(() { _canSubmit = true; _timeUntilNext = "READY TO FORGE"; });
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final DateTime now = DateTime.now();
      final DateTime lastDate = lastCompletedAt.toDate();
      final DateTime nextMidnight = DateTime(lastDate.year, lastDate.month, lastDate.day + 1);

      final Duration remaining = nextMidnight.difference(now);

      if (remaining.isNegative) {
        timer.cancel();
        if (mounted) setState(() { _canSubmit = true; _timeUntilNext = "READY TO FORGE"; });
      } else {
        if (mounted) {
          setState(() {
            _canSubmit = false;
            String hours = remaining.inHours.toString().padLeft(2, '0');
            String minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
            String seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
            _timeUntilNext = "${hours}H ${minutes}M ${seconds}S";
          });
        }
      }
    });
  }

  Future<void> _submitProgress(String docId, int currentDays, int totalDays, String questName) async {
    if (!_canSubmit || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser;
    final String cry = _battleCryController.text.trim();

    try {

      int baseXP = 10;
      int commitmentBonus = (totalDays / 10).floor();
      int totalXPToGain = baseXP + commitmentBonus;

      int newDays = currentDays + 1;
      double newProgress = (newDays / totalDays).clamp(0.0, 1.0);


      await FirebaseFirestore.instance.collection('challenges').doc(docId).update({
        'daysCompleted': newDays,
        'progress': newProgress,
        'lastCompletedAt': FieldValue.serverTimestamp(),
      });

      if (user != null) {

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'streak': FieldValue.increment(1),
          'totalXP': FieldValue.increment(totalXPToGain),
          'lastGlobalCheckIn': FieldValue.serverTimestamp(),
        });


        await FirebaseFirestore.instance.collection('activity').add({
          'username': user.displayName ?? "Champion",
          'questName': questName,
          'day': newDays,
          'battleCry': cry.isNotEmpty ? cry : "NO EXCUSES.",
          'timestamp': FieldValue.serverTimestamp(),
          'userId': user.uid,
          'type': 'check-in',
          'xpGained': totalXPToGain,
        });
      }

      _battleCryController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("FORGED! +$totalXPToGain XP EARNED."),
                backgroundColor: DairaTheme.accentOrange
            )
        );
      }
    } catch (e) {
      debugPrint("Submission Error: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final String docId = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("QUEST STATUS", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('challenges').doc(docId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
              var data = snapshot.data!.data() as Map<String, dynamic>;
              return IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
                onPressed: () => _showDeleteDialog(docId, data['name'] ?? "", data),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('challenges').doc(docId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator(color: DairaTheme.accentOrange));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          int daysDone = data['daysCompleted'] ?? 0;
          int totalDays = data['totalDays'] ?? 30;
          double progress = (data['progress'] ?? 0.0).toDouble();
          Timestamp? lastDone = data['lastCompletedAt'];
          String questName = data['name'] ?? "Quest";
          List<dynamic> taskList = data['tasks'] ?? [];

          Map<String, String> currentMission = {"title": "LEGEND ACHIEVED", "details": "Mission complete.", "intel": ""};

          if (taskList.isNotEmpty && daysDone < taskList.length) {
            currentMission = _getMissionContent(taskList[daysDone]);
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkStreakReset(docId, lastDone, daysDone);
            if (_timer == null || !_timer!.isActive) _startCountdown(lastDone);
          });

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(questName, progress, daysDone, totalDays),
                const SizedBox(height: 30),

                // MISSION CARD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GestureDetector(
                    onTap: () => _showMissionBriefing(context, currentMission, daysDone + 1),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: DairaTheme.surfaceGraphite,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: DairaTheme.accentOrange.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shield_rounded, color: DairaTheme.accentOrange, size: 14),
                                  const SizedBox(width: 8),
                                  Text("DAY ${daysDone + 1} MISSION",
                                      style: const TextStyle(color: DairaTheme.accentOrange, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
                                ],
                              ),
                              const Icon(Icons.info_outline_rounded, color: DairaTheme.accentOrange, size: 18),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(currentMission['title']!,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.2)),
                          if (currentMission['details']!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(currentMission['details']!,
                                style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500)),
                          ],
                          const SizedBox(height: 20),
                          const Text("TAP TO READ FULL BRIEFING",
                              style: TextStyle(color: DairaTheme.accentOrange, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: TextField(
                    controller: _battleCryController,
                    maxLength: 50,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "YOUR BATTLE CRY...",
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                      counterStyle: const TextStyle(color: DairaTheme.slateGrey, fontSize: 10),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: DairaTheme.accentOrange)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _buildMainButton(docId, daysDone, totalDays, questName),
                const SizedBox(height: 40),
                _buildStreakWarning(),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(String name, double progress, int done, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
                value: progress,
                backgroundColor: DairaTheme.surfaceGraphite,
                color: DairaTheme.accentOrange,
                minHeight: 12
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$done / $total DAYS CONQUERED",
                  style: const TextStyle(color: DairaTheme.slateGrey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
              Text("${(progress * 100).toInt()}%",
                  style: const TextStyle(color: DairaTheme.accentOrange, fontWeight: FontWeight.w900, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(String docId, int done, int total, String questName) {
    bool isFinished = done >= total;
    return Column(
      children: [
        Text(isFinished ? "LEGEND ACHIEVED" : _timeUntilNext,
            style: TextStyle(color: _canSubmit ? DairaTheme.accentOrange : Colors.white24, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 3)),
        const SizedBox(height: 30),
        GestureDetector(
          onTap: (isFinished || !_canSubmit) ? null : () => _submitProgress(docId, done, total, questName),
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _canSubmit ? DairaTheme.accentOrange : DairaTheme.surfaceGraphite,
              border: Border.all(color: _canSubmit ? Colors.white : Colors.white10, width: 2),
              boxShadow: _canSubmit ? [BoxShadow(color: DairaTheme.accentOrange.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 5)] : [],
            ),
            child: Center(
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Icon(isFinished ? Icons.emoji_events_rounded : Icons.bolt_rounded,
                  size: 80, color: _canSubmit ? Colors.black : DairaTheme.slateGrey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakWarning() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.1))
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
          SizedBox(width: 12),
          Expanded(child: Text("DANGER: Missing 48 hours resets this quest to zero.",
              style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
        ],
      ),
    );
  }
}