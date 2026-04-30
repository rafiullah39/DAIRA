import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../theme.dart';

class AIForgeScreen extends StatefulWidget {
  const AIForgeScreen({super.key});

  @override
  State<AIForgeScreen> createState() => _AIForgeScreenState();
}

class _AIForgeScreenState extends State<AIForgeScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  double _selectedDays = 30;
  bool _isPublic = true;

  final String _apiKey = "AIzaSyB8o60w2u1QOwPOWlqVLr9Bf8f-D_YqNU4";

  String _getCleanJson(String text) {
    if (text.contains("```json")) {
      return text.split("```json")[1].split("```")[0].trim();
    } else if (text.contains("```")) {
      return text.split("```")[1].split("```")[0].trim();
    }
    return text.trim();
  }

  Future<void> _forgeAIQuest() async {
    final user = FirebaseAuth.instance.currentUser;
    final prompt = _promptController.text.trim();
    int totalDays = _selectedDays.toInt();

    if (user == null || prompt.isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final String creatorName = userDoc.data()?['username'] ?? "Champion";

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );

      final promptText = """
      Create a $totalDays-day challenge for: '$prompt'. 
      Return JSON with:
      1. 'challengeName': A powerful title.
      2. 'description': A brief overview.
      3. 'tasks': A list of $totalDays objects. Each object MUST have:
         - 'title': A short, punchy mission name.
         - 'details': A 1-sentence summary of the task.
         - 'intel': A detailed paragraph (3-4 sentences) explaining the 'Why' behind this task, the long-term benefits, and a motivational closing.
      """;

      final response = await model.generateContent([Content.text(promptText)]);
      final String cleanData = _getCleanJson(response.text!);
      final Map<String, dynamic> data = jsonDecode(cleanData);

      final List<dynamic> rawTasks = data['tasks'] as List;
      final List<Map<String, dynamic>> formattedTasks = rawTasks.asMap().entries.map((entry) {
        final val = entry.value;
        return {
          'day': entry.key + 1,
          'title': val['title']?.toString() ?? "Mission Objective",
          'details': val['details']?.toString() ?? "Focus on today's target.",
          'intel': val['intel']?.toString() ?? "No tactical briefing available.",
          'isCompleted': false,
        };
      }).toList();

      final batch = FirebaseFirestore.instance.batch();
      final personalRef = FirebaseFirestore.instance.collection('challenges').doc();
      final templateRef = FirebaseFirestore.instance.collection('challenges').doc();

      final questMap = {
        'name': data['challengeName'] ?? "Unnamed Quest",
        'description': data['description'] ?? "A journey forged by AI.",
        'totalDays': totalDays,
        'createdBy': creatorName,
        'creatorId': user.uid,
        'creatorUid': user.uid,
        'type': 'AI Forged',
        'tasks': formattedTasks,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'kudosCount': 0,
        'joinCount': 0,
      };


      batch.set(personalRef, {
        ...questMap,
        'isTemplate': false,
        'participantId': user.uid,
        'daysCompleted': 0,
        'progress': 0.0,
        'startDate': FieldValue.serverTimestamp(),
        'templateId': _isPublic ? templateRef.id : null,
      });

      if (_isPublic) {
        batch.set(templateRef, {
          ...questMap,
          'isTemplate': true,
          'participantId': null,
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
            'title': 'NEW FORGE DETECTED',
            'message': '$creatorName just forged: ${data['challengeName']}',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'challengeId': templateRef.id,
          });
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QUEST FORGED & VANGUARD NOTIFIED"), backgroundColor: DairaTheme.accentOrange),
        );
      }
    } catch (e) {
      debugPrint("Forge Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("FORGE FAILED: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(
        title: const Text("THE FORGE", style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900, fontSize: 14)),
        backgroundColor: DairaTheme.surfaceGraphite,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome, size: 60, color: DairaTheme.accentOrange),
            const SizedBox(height: 24),
            TextField(
              controller: _promptController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "What greatness shall we forge?",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: DairaTheme.surfaceGraphite,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: DairaTheme.accentOrange, width: 2)),
              ),
            ),
            const SizedBox(height: 30),

            Text("DURATION: ${_selectedDays.toInt()} DAYS", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            Slider(
              value: _selectedDays,
              min: 7,
              max: 90,
              divisions: 83,
              activeColor: DairaTheme.accentOrange,
              onChanged: (value) => setState(() => _selectedDays = value),
            ),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: DairaTheme.surfaceGraphite,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isPublic ? "PUBLIC DISCOVERY" : "PRIVATE FORGE",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(_isPublic ? "Visible to the community" : "Only visible to you",
                          style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 10)),
                    ],
                  ),
                  Switch(
                    value: _isPublic,
                    activeColor: DairaTheme.accentOrange,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _forgeAIQuest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DairaTheme.accentOrange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text("FORGE QUEST", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}