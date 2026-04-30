import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class CreatorProfileScreen extends StatefulWidget {
  final String creatorId;
  final String creatorName;

  const CreatorProfileScreen({
    super.key,
    required this.creatorId,
    required this.creatorName,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  bool _isFollowing = false;
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  void _checkIfFollowing() async {
    final doc = await FirebaseFirestore.instance
        .collection('social')
        .doc("${_currentUid}_${widget.creatorId}")
        .get();
    if (mounted) setState(() => _isFollowing = doc.exists);
  }

  Future<void> _joinQuest(BuildContext context, Map<String, dynamic> data, String templateId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final personalRef = FirebaseFirestore.instance.collection('challenges').doc();

      batch.set(personalRef, {
        'name': data['name'],
        'participantId': user.uid,
        'creatorId': widget.creatorId,
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

      if (widget.creatorId != user.uid) {
        final architectRef = FirebaseFirestore.instance.collection('users').doc(widget.creatorId);
        batch.update(architectRef, {'totalXP': FieldValue.increment(50)});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QUEST JOINED! +50 XP SENT TO ARCHITECT"), backgroundColor: DairaTheme.accentOrange),
        );
      }
    } catch (e) {
      debugPrint("❌ JOIN FAILED: $e");
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUid.isEmpty || _currentUid == widget.creatorId) return;

    final docId = "${_currentUid}_${widget.creatorId}";
    final socialRef = FirebaseFirestore.instance.collection('social').doc(docId);

    final alertRef = FirebaseFirestore.instance.collection('alerts').doc("${_currentUid}_follow_${widget.creatorId}");

    HapticFeedback.mediumImpact();

    try {
      final batch = FirebaseFirestore.instance.batch();

      if (_isFollowing) {
        batch.delete(socialRef);
        batch.delete(alertRef);

        await batch.commit();
        if (mounted) setState(() => _isFollowing = false);
      } else {
        batch.set(socialRef, {
          'followerId': _currentUid,
          'followingId': widget.creatorId,
          'timestamp': FieldValue.serverTimestamp(),
        });


        batch.set(alertRef, {
          'userId': widget.creatorId,
          'senderId': _currentUid,
          'type': 'follow',
          'message': 'is now following your professional progress.',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        await batch.commit();
        if (mounted) setState(() => _isFollowing = true);
      }
    } catch (e) {
      debugPrint("❌ FOLLOW ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.creatorId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                var data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data == null) return const SizedBox();

                int xp = data['totalXP'] ?? 0;

                int level = (xp / 100).floor() + 1;

                return Column(
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: DairaTheme.accentOrange,
                      child: Text(widget.creatorName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                    const SizedBox(height: 16),
                    Text(widget.creatorName.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    Text("LEVEL $level ARCHITECT",
                        style: const TextStyle(color: DairaTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2)),
                    const SizedBox(height: 20),

                    if (_currentUid != widget.creatorId)
                      SizedBox(
                        width: 160,
                        child: ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing ? Colors.transparent : DairaTheme.accentOrange,
                            side: const BorderSide(color: DairaTheme.accentOrange),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_isFollowing ? "FOLLOWING" : "FOLLOW",
                              style: TextStyle(color: _isFollowing ? DairaTheme.accentOrange : Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 40),
            _buildSectionHeader("NETWORK (FOLLOWERS)"),
            _buildFollowersList(),
            const SizedBox(height: 30),
            _buildSectionHeader("BLUEPRINTS & TEMPLATES"),
            _buildQuestsList(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title,
              style: const TextStyle(color: DairaTheme.slateGrey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2))),
    );
  }

  Widget _buildFollowersList() {
    return SizedBox(
      height: 80,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('social').where('followingId', isEqualTo: widget.creatorId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("NO NETWORK YET", style: TextStyle(color: Colors.white10, fontSize: 10)));
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final followerId = snapshot.data!.docs[index]['followerId'];
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(followerId).snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();
                  final uData = userSnap.data!.data() as Map<String, dynamic>?;
                  if (uData == null) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: CircleAvatar(
                      backgroundColor: DairaTheme.surfaceGraphite,
                      child: Text((uData['username'] ?? "C")[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildQuestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('challenges')
          .where('isTemplate', isEqualTo: true)
          .where('creatorId', isEqualTo: widget.creatorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Text("NO PUBLIC TEMPLATES YET", style: TextStyle(color: Colors.white10, fontSize: 10)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final q = doc.data() as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: DairaTheme.surfaceGraphite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ListTile(
                title: Text(q['name'] ?? "Quest",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                subtitle: Text("${q['totalDays'] ?? 0} DAY MISSION",
                    style: const TextStyle(color: DairaTheme.accentOrange, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                trailing: ElevatedButton(
                  onPressed: () => _joinQuest(context, q, doc.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DairaTheme.accentOrange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(60, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("JOIN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}