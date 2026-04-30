import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'creator_profile_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _handleAccept(BuildContext context, String alertId, Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      await FirebaseFirestore.instance.collection('challenges').add({
        'name': data['questName'],
        'participantId': uid,
        'totalDays': data['days'] ?? 30,
        'progress': 0.0,
        'daysCompleted': 0,
        'isTemplate': false,
        'createdAt': FieldValue.serverTimestamp(),
        'startDate': FieldValue.serverTimestamp(),
        'type': 'Collaborative',
        'tasks': data['tasks'] ?? [],
      });
      await FirebaseFirestore.instance.collection('alerts').doc(alertId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QUEST FORGED: Added to Dashboard"), backgroundColor: DairaTheme.accentOrange),
        );
      }
    } catch (e) {
      debugPrint("Accept Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(
        title: const Text("INTEL & ALERTS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
        backgroundColor: DairaTheme.surfaceGraphite,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .where('userId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Signal Interrupted."));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: DairaTheme.accentOrange));

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return _buildEmptyState();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Text("RECENT ACTIVITY", style: TextStyle(color: DairaTheme.accentOrange, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return _buildModernAlertTile(context, docs[index].id, data);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernAlertTile(BuildContext context, String alertId, Map<String, dynamic> data) {
    String type = data['type'] ?? 'notification';
    bool isInvite = type == 'invite';
    bool isKudos = type == 'kudos';
    bool isNewForge = type == 'new_quest';
    bool isFollow = type == 'follow';

    String senderId = data['senderId'] ?? "";


    IconData iconData = Icons.notifications;
    Color iconColor = DairaTheme.accentOrange;

    if (isInvite) iconData = Icons.bolt_rounded;
    if (isKudos) { iconData = Icons.favorite_rounded; iconColor = Colors.pinkAccent; }
    if (isNewForge) iconData = Icons.auto_awesome;
    if (isFollow) { iconData = Icons.person_add_rounded; iconColor = Colors.cyanAccent; }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DairaTheme.surfaceGraphite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSenderName(senderId, _getActionText(type)),
                    const SizedBox(height: 4),
                    Text(data['message'] ?? "", style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),


          if (isInvite) ...[
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DairaTheme.accentOrange,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _handleAccept(context, alertId, data),
                    child: const Text("ACCEPT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => FirebaseFirestore.instance.collection('alerts').doc(alertId).delete(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("DECLINE", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],

          if (isNewForge) ...[
            const SizedBox(height: 15),
            _buildActionCardButton(
                context,
                alertId,
                "VIEW NEW QUEST",
                    () {
                  Navigator.pop(context);
                  FirebaseFirestore.instance.collection('alerts').doc(alertId).delete();
                }
            )
          ],

          if (isFollow) ...[
            const SizedBox(height: 15),
            _buildActionCardButton(
                context,
                alertId,
                "VIEW PROFILE",
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreatorProfileScreen(creatorId: senderId, creatorName: "Architect"))
                  );

                  FirebaseFirestore.instance.collection('alerts').doc(alertId).delete();
                }
            )
          ],
        ],
      ),
    );
  }


  Widget _buildActionCardButton(BuildContext context, String alertId, String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: DairaTheme.accentOrange.withOpacity(0.1),
          foregroundColor: DairaTheme.accentOrange,
          side: const BorderSide(color: DairaTheme.accentOrange, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
      ),
    );
  }

  String _getActionText(String? type) {
    switch (type) {
      case 'kudos': return "Liked your quest!";
      case 'invite': return "Invited you!";
      case 'new_quest': return "forged a new quest!";
      case 'follow': return "started following you!";
      default: return "sent you a notification";
    }
  }

  Widget _buildSenderName(String senderId, String actionText) {
    if (senderId.isEmpty) return Text(actionText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
      builder: (context, snapshot) {
        String displayName = "A champion";
        if (snapshot.hasData && snapshot.data!.exists) {
          displayName = (snapshot.data!.data() as Map<String, dynamic>)['username'] ?? "A champion";
        }

        return RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            children: [
              TextSpan(text: displayName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: DairaTheme.accentOrange, fontSize: 12)),
              TextSpan(text: " $actionText", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 40, color: DairaTheme.slateGrey),
          SizedBox(height: 15),
          Text("SILENCE IN THE FORGE", style: TextStyle(color: DairaTheme.slateGrey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
          Text("No active notifications", style: TextStyle(color: DairaTheme.slateGrey, fontSize: 12)),
        ],
      ),
    );
  }
}