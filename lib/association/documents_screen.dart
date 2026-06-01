// lib/association/documents_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:a/cloudinary_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool _isUploading = false;
  String _uploadingDoc = '';

  static const _docs = [
    {
      'key':       'agrement',
      'title':     "Agrément de l'association",
      'icon':      Icons.verified_user_outlined,
      'statusKey': 'agrementStatus',
      'dateKey':   'agrementDate',
      'urlKey':    'agrementUrl',
    },
    {
      'key':       'statuts',
      'title':     "Statuts de l'association",
      'icon':      Icons.description_outlined,
      'statusKey': 'statutsStatus',
      'dateKey':   'statutsDate',
      'urlKey':    'statutsUrl',
    },
    {
      'key':       'nif',
      'title':     "Identifiant Fiscal (NIF)",
      'icon':      Icons.article_outlined,
      'statusKey': 'nifStatus',
      'dateKey':   'nifDate',
      'urlKey':    'nifUrl',
    },
  ];

  Future<void> _uploadDocument(
      String docKey, String statusKey, String dateKey, String urlKey) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);

    setState(() {
      _isUploading  = true;
      _uploadingDoc = docKey;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // رفع إلى Cloudinary بدل Firebase Storage
      final downloadUrl = await CloudinaryService.uploadAuto(file);

      if (downloadUrl == null) {
        throw Exception('Upload failed');
      }

      final now = DateTime.now();
      final dateStr =
          'Ajouté le ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        statusKey: 'En attente',
        dateKey:   dateStr,
        urlKey:    downloadUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Document envoyé, en attente de validation'),
            backgroundColor: Color(0xFF1B5E20),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Upload doc: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du téléchargement'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showDocOptions(BuildContext context, Map doc, Map<String, dynamic> userData) {
    final hasDoc = (userData[doc['urlKey']] as String?)?.isNotEmpty == true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                doc['title'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Color(0xFF1B5E20)),
              title: Text(hasDoc ? 'Remplacer le document' : 'Ajouter le document'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadDocument(
                  doc['key'] as String,
                  doc['statusKey'] as String,
                  doc['dateKey'] as String,
                  doc['urlKey'] as String,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: Text('Utilisateur non connecté')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.orange.withValues(alpha: 0.1),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Veuillez garder vos documents à jour pour maintenir la validation de votre association.",
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    !snapshot.data!.exists) {
                  return const Center(child: Text('Aucun document trouvé'));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final doc    = _docs[i];
                    final status = data[doc['statusKey']] ?? 'Manquant';
                    final date   = data[doc['dateKey']]   ?? 'Non encore ajouté';
                    final isUploading =
                        _isUploading && _uploadingDoc == doc['key'];

                    return _buildDocCard(
                      context,
                      title:       doc['title'] as String,
                      date:        date,
                      status:      status,
                      icon:        doc['icon'] as IconData,
                      isUploading: isUploading,
                      onTap: () => _showDocOptions(context, doc, data),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : () => _showAddDocSheet(context),
                icon: _isUploading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.add_a_photo, color: Colors.white),
                label: Text(
                  _isUploading
                      ? 'Téléchargement en cours...'
                      : "Ajouter un nouveau document",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDocSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (ctx, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          return SafeArea(
            child: Wrap(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    "Quel document voulez-vous ajouter ?",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1B5E20)),
                  ),
                ),
                ..._docs.map((doc) {
                  final hasDoc =
                      (data[doc['urlKey']] as String?)?.isNotEmpty == true;
                  return ListTile(
                    leading:  Icon(doc['icon'] as IconData,
                        color: const Color(0xFF1B5E20)),
                    title:    Text(doc['title'] as String),
                    trailing: hasDoc
                        ? const Icon(Icons.check_circle,
                            color: Colors.green, size: 18)
                        : const Icon(Icons.upload_file,
                            color: Colors.grey, size: 18),
                    onTap: () {
                      Navigator.pop(ctx);
                      _uploadDocument(
                        doc['key'] as String,
                        doc['statusKey'] as String,
                        doc['dateKey'] as String,
                        doc['urlKey'] as String,
                      );
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        title: const Text(
          'Documents Officiels',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      );

  Widget _buildDocCard(
    BuildContext context, {
    required String title,
    required String date,
    required String status,
    required IconData icon,
    required bool isUploading,
    required VoidCallback onTap,
  }) {
    final Color statusColor = status == "Validé"
        ? Colors.green
        : (status == "Manquant" ? Colors.red : Colors.orange);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1B5E20)),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(date,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                isUploading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF1B5E20)))
                    : const Icon(Icons.more_vert,
                        color: Colors.grey, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}