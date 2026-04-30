import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

class CreateChallengePage extends StatefulWidget {
  const CreateChallengePage({super.key});

  @override
  State<CreateChallengePage> createState() => _CreateChallengePageState();
}

class _CreateChallengePageState extends State<CreateChallengePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  List<TextEditingController> _taskControllers = [];

  double _selectedDays = 7;
  bool _isPublic = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _updateTaskFields(7);
  }

  void _updateTaskFields(int days) {
    if (_taskControllers.length < days) {
      for (int i = _taskControllers.length; i < days; i++) {
        _taskControllers.add(TextEditingController());
      }
    } else if (_taskControllers.length > days) {
      for (int i = _taskControllers.length - 1; i >= days; i--) {
        _taskControllers[i].dispose();
        _taskControllers.removeAt(i);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    for (var controller in _taskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _createQuest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _nameController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final String creatorName = userDoc.data()?['username'] ?? "Champion";
      List<String> dailyTasks = _taskControllers.map((c) => c.text.trim()).toList();

      final batch = FirebaseFirestore.instance.batch();
      final int totalDays = _selectedDays.toInt();

      final personalRef = FirebaseFirestore.instance.collection('challenges').doc();
      final templateRef = FirebaseFirestore.instance.collection('challenges').doc();

      final Map<String, dynamic> questData = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'totalDays': totalDays,
        'createdBy': creatorName,
        'creatorId': user.uid,
        'creatorUid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'Manual',
        'status': 'active',
        'tasks': dailyTasks,
        'kudosCount': 0,
        'joinCount': 0,
      };

      batch.set(personalRef, {
        ...questData,
        'participantId': user.uid,
        'isTemplate': false,
        'daysCompleted': 0,
        'progress': 0.0,
        'startDate': FieldValue.serverTimestamp(),
        'templateId': _isPublic ? templateRef.id : null,
      });

      if (_isPublic) {
        batch.set(templateRef, {
          ...questData,
          'participantId': null,
          'isTemplate': true,
        });

        final followersQuery = await FirebaseFirestore.instance
            .collection('social')
            .where('followingId', isEqualTo: user.uid)
            .get();

        for (var followerDoc in followersQuery.docs) {
          final String followerId = followerDoc.data()['followerId'];
          final alertRef = FirebaseFirestore.instance.collection('alerts').doc();

          batch.set(alertRef, {
            'userId': followerId,
            'senderId': user.uid,
            'senderName': creatorName,
            'type': 'new_quest',
            'title': 'NEW MANUAL FORGE',
            'message': '$creatorName just forged: ${_nameController.text.trim()}',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'challengeId': templateRef.id,
          });
        }
      }

      await batch.commit();
      if (mounted) Navigator.pop(context);

    } catch (e) {
      debugPrint("🔥 Forge Error: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(
        title: const Text("FORGE NEW QUEST", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: DairaTheme.surfaceGraphite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Quest Name")),
            const SizedBox(height: 20),
            TextField(controller: _descController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("Overall Goal")),
            const SizedBox(height: 30),

            Text("DURATION: ${_selectedDays.toInt()} DAYS", style: _labelStyle()),
            Slider(
              value: _selectedDays,
              min: 7, max: 30,
              divisions: 23,
              activeColor: DairaTheme.accentOrange,
              onChanged: (v) {
                setState(() {
                  _selectedDays = v;
                  _updateTaskFields(v.toInt());
                });
              },
            ),

            const SizedBox(height: 20),
            _buildSectionLabel("DEFINE DAILY MISSIONS"),
            const SizedBox(height: 10),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _taskControllers.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _taskControllers[index],
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: Text("Day ${index + 1}", style: const TextStyle(color: DairaTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                      hintText: "Enter mission...",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: DairaTheme.surfaceGraphite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isPublic ? "PUBLIC QUEST" : "PRIVATE QUEST", style: _labelStyle()),
                    Text(_isPublic ? "Visible in Discovery" : "Only you can see this", style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 10)),
                  ],
                ),
                Switch(value: _isPublic, activeColor: DairaTheme.accentOrange, onChanged: (v) => setState(() => _isPublic = v)),
              ],
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createQuest,
                style: ElevatedButton.styleFrom(backgroundColor: DairaTheme.accentOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text("FORGE QUEST", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: DairaTheme.slateGrey),
    filled: true, fillColor: DairaTheme.surfaceGraphite,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
  );

  Widget _buildSectionLabel(String text) => Text(text, style: const TextStyle(color: DairaTheme.accentOrange, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));

  TextStyle _labelStyle() => const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1);
}