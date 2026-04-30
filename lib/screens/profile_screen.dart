import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme.dart';
import 'creator_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get user => FirebaseAuth.instance.currentUser;
  final TextEditingController _usernameController = TextEditingController();
  bool _isUpdating = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _usernameController.text = user?.displayName ?? "";
  }


  void _showSocialSheet({required bool isFollowers}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DairaTheme.surfaceGraphite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text(
                    isFollowers ? "THE VANGUARD (FOLLOWERS)" : "ARCHITECTS TRACKED (FOLLOWING)",
                    style: const TextStyle(color: DairaTheme.accentOrange, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('social')
                          .where(isFollowers ? 'followingId' : 'followerId', isEqualTo: user!.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: DairaTheme.accentOrange));
                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              isFollowers ? "NO FOLLOWERS YET." : "YOU AREN'T TRACKING ANYONE.",
                              style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final String targetUserId = isFollowers ? docs[index]['followerId'] : docs[index]['followingId'];

                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').doc(targetUserId).snapshots(),
                              builder: (context, userSnap) {
                                if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox();
                                final data = userSnap.data!.data() as Map<String, dynamic>;
                                final String name = data['username'] ?? "Champion";

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => CreatorProfileScreen(creatorId: targetUserId, creatorName: name)));
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: DairaTheme.accentOrange,
                                    child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text("${data['totalXP'] ?? 0} XP", style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 10)),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white10, size: 14),
                                );
                              },
                            );
                          },
                        );
                      },
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


  void _showLogoutDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Logout",
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DairaTheme.surfaceGraphite,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 32),
                  ),
                  const SizedBox(height: 20),
                  const Text("ABANDON THE FORGE?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  const Text("Your progress is secured, but your active sessions will terminate.", textAlign: TextAlign.center, style: TextStyle(color: DairaTheme.slateGrey, fontSize: 12)),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("STAY", style: TextStyle(color: DairaTheme.slateGrey, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          },
                          child: const Text("LOGOUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _updateUsername() async {
    if (_usernameController.text.trim().isEmpty) return;
    setState(() => _isUpdating = true);
    try {
      String newName = _usernameController.text.trim();
      await user?.updateDisplayName(newName);
      await user?.reload();
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'username': newName,
        'username_lowercase': newName.toLowerCase(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("IDENTITY SYNCED")));
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      setState(() => _isUpdating = true);
      try {
        final directory = await getApplicationDocumentsDirectory();
        final String fileName = "avatar_${user!.uid}_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}";
        final File permanentFile = await File(image.path).copy('${directory.path}/$fileName');
        await user?.updatePhotoURL(permanentFile.path);
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'avatarUrl': permanentFile.path});
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint("Error: $e");
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: DairaTheme.graphite,
      appBar: AppBar(
        title: const Text("RANK & IDENTITY", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 12)),
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildIdentityCard(user!),
            const SizedBox(height: 25),
            Row(
              children: [
                _buildModernStatCard("TOTAL XP", Icons.auto_awesome_rounded, FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(), isUserDoc: true, dataKey: 'totalXP'),
                const SizedBox(width: 8),
                _buildModernStatCard("VANGUARD", Icons.groups_rounded, FirebaseFirestore.instance.collection('social').where('followingId', isEqualTo: user!.uid).snapshots(), isUserDoc: false, onTap: () => _showSocialSheet(isFollowers: true)),
                const SizedBox(width: 8),
                _buildModernStatCard("FOLLOWING", Icons.person_add_alt_1_rounded, FirebaseFirestore.instance.collection('social').where('followerId', isEqualTo: user!.uid).snapshots(), isUserDoc: false, onTap: () => _showSocialSheet(isFollowers: false)),
              ],
            ),
            const SizedBox(height: 40),
            _buildSectionLabel("IDENTITY SETTINGS"),
            const SizedBox(height: 15),
            _buildCustomTextField(_usernameController, "Username", Icons.alternate_email_rounded),
            const SizedBox(height: 25),
            _buildPrimaryButton("SYNC UPDATES", _updateUsername),
            const SizedBox(height: 60),
            TextButton.icon(
              onPressed: _showLogoutDialog,
              icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 18),
              label: const Text("END SESSION", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard(User user) {
    bool hasLocalImage = user.photoURL != null && File(user.photoURL!).existsSync();
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          int xp = 0;
          if (snapshot.hasData && snapshot.data!.exists) {
            xp = (snapshot.data!.data() as Map<String, dynamic>)['totalXP'] ?? 0;
          }
          int level = (xp / 100).floor() + 1;
          return Container(
            width: double.infinity, padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [DairaTheme.surfaceGraphite, DairaTheme.graphite], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(30), border: Border.all(color: DairaTheme.accentOrange.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isUpdating ? null : _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(radius: 55, backgroundColor: DairaTheme.accentOrange, backgroundImage: hasLocalImage ? FileImage(File(user.photoURL!)) : null, child: !hasLocalImage ? Text(user.displayName?[0].toUpperCase() ?? "A", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black)) : null),
                      if (!_isUpdating) Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: DairaTheme.accentOrange, shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(user.displayName ?? "Champion", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                const SizedBox(height: 8),
                Text("LEVEL $level ARCHITECT", style: const TextStyle(color: DairaTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 140, child: LinearProgressIndicator(value: (xp % 100) / 100, backgroundColor: Colors.white10, color: DairaTheme.accentOrange, minHeight: 4))),
              ],
            ),
          );
        }
    );
  }

  Widget _buildModernStatCard(String label, IconData icon, Stream stream, {required bool isUserDoc, String? dataKey, VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: DairaTheme.surfaceGraphite, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.02))),
          child: Column(
            children: [
              Icon(icon, color: DairaTheme.slateGrey, size: 14),
              const SizedBox(height: 6),
              StreamBuilder(
                  stream: stream,
                  builder: (context, snapshot) {
                    String val = "0";
                    if (snapshot.hasData) {
                      if (isUserDoc) {
                        var doc = snapshot.data as DocumentSnapshot;
                        val = (doc.data() as Map<String, dynamic>?)?[dataKey]?.toString() ?? "0";
                      } else {
                        val = (snapshot.data as QuerySnapshot).docs.length.toString();
                      }
                    }
                    return Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white));
                  }
              ),
              Text(label, style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTextField(TextEditingController controller, String hint, IconData icon) => TextField(controller: controller, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), decoration: InputDecoration(prefixIcon: Icon(icon, color: DairaTheme.accentOrange, size: 18), filled: true, fillColor: DairaTheme.surfaceGraphite, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)));
  Widget _buildPrimaryButton(String label, VoidCallback onTap) => SizedBox(width: double.infinity, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: DairaTheme.accentOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: _isUpdating ? null : onTap, child: _isUpdating ? const CircularProgressIndicator(color: Colors.black) : Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 2))));
  Widget _buildSectionLabel(String text) => Align(alignment: Alignment.centerLeft, child: Text(text, style: const TextStyle(color: DairaTheme.slateGrey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)));
}