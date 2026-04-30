import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  String _searchQuery = "";


  void _triggerSelectionSheet(BuildContext context, String targetUid, String targetUsername) {
    final currentUser = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      backgroundColor: DairaTheme.graphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "CHOOSE QUEST FOR $targetUsername",
                style: const TextStyle(
                  color: DairaTheme.accentOrange,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot>(

                stream: FirebaseFirestore.instance
                    .collection('challenges')
                    .where('participantId', isEqualTo: currentUser?.uid)
                    .where('isTemplate', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final myQuests = snapshot.data!.docs;

                  if (myQuests.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text("You aren't currently in any quests.",
                            style: TextStyle(color: DairaTheme.slateGrey)),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: myQuests.length,
                    itemBuilder: (context, index) {
                      var qData = myQuests[index].data() as Map<String, dynamic>;

                      return ListTile(
                        onTap: () {

                          _finalizeInvitation(targetUid, targetUsername, myQuests[index].id, qData);
                          Navigator.pop(context);
                        },
                        leading: const Icon(Icons.bolt_rounded, color: DairaTheme.accentOrange),
                        title: Text(qData['name'] ?? "Quest",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("${qData['totalDays']} Days",
                            style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 11)),
                        trailing: const Icon(Icons.send_rounded, color: DairaTheme.accentOrange, size: 20),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }


  Future<void> _finalizeInvitation(String tUid, String tName, String qId, Map<String, dynamic> qData) async {
    final authUser = FirebaseAuth.instance.currentUser;

    try {
      await FirebaseFirestore.instance.collection('alerts').add({
        'userId': tUid,
        'senderId': authUser?.uid,
        'senderName': authUser?.displayName ?? "Champion",
        'type': 'invite',
        'title': "Quest Invitation",
        'message': "sent you an invite for ${qData['name']}",
        'questName': qData['name'],
        'challengeId': qId,
        'tasks': qData['tasks'] ?? [],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Invite sent: ${qData['name']} to $tName")),
        );
      }
    } catch (e) {
      debugPrint("Invite error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(
        backgroundColor: DairaTheme.surfaceGraphite,
        elevation: 0,
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Search by username...",
            hintStyle: TextStyle(color: DairaTheme.slateGrey),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: DairaTheme.accentOrange),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        ),
      ),
      body: _searchQuery.isEmpty
          ? _buildEmptyState("Search for other champions")
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('username_lowercase', isGreaterThanOrEqualTo: _searchQuery)
            .where('username_lowercase', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
            .limit(8)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final results = snapshot.data!.docs
              .where((doc) => doc.id != FirebaseAuth.instance.currentUser?.uid)
              .toList();

          if (results.isEmpty) return _buildEmptyState("No users found");

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              var uData = results[index].data() as Map<String, dynamic>;
              String uName = uData['username'] ?? "User";

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: DairaTheme.surfaceGraphite,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.white)),
                  title: Text(uName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DairaTheme.accentOrange,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    // CRITICAL CHECK: Does this call _triggerSelectionSheet?
                    onPressed: () => _triggerSelectionSheet(context, results[index].id, uName),
                    child: const Text("INVITE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(child: Text(msg, style: const TextStyle(color: DairaTheme.slateGrey)));
  }
}