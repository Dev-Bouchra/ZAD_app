import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Mon Historique',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1B5E20),
          centerTitle: true,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.orange,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Tout"),
              Tab(text: "Reçu"),
              Tab(text: "Distribué"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildHistoryList(filter: null),
            _buildHistoryList(filter: "Reçu"),
            _buildHistoryList(filter: "Distribué"),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList({String? filter}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Utilisateur non connecté'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dons')
          .where('associationId', isEqualTo: user.uid)
          .where('status', whereIn: ['livre', 'recu_par_benevole'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        List<Map<String, dynamic>> activities = [];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? '';
          String type = '';

          if (status == 'livre') {
            type = 'Distribué';
          } else if (status == 'recu_par_benevole') {
            type = 'Reçu';
          } else {
            continue;
          }

          final createdAt = data['createdAt'] as Timestamp?;
          String date = '';
          if (createdAt != null) {
            final d = createdAt.toDate();
            date = '${d.day} ${_getMonthName(d.month)} ${d.year}';
          }

          final String title = data['title'] ?? 'Don';
          final String quantity = data['quantity'] ?? '';
          final String donorName = data['donorName'] ?? '';

          final String description =
              donorName.isNotEmpty ? '$title de $donorName' : title;

          activities.add({
            'title': description,
            'date': date,
            'type': type,
            'qty': quantity,
            'icon': _getIconForTitle(title),
          });
        }

        if (filter != null) {
          activities = activities.where((a) => a['type'] == filter).toList();
        }

        if (activities.isEmpty) {
          return const Center(
            child: Text('Aucun historique trouvé'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final item = activities[index];
            final bool isRecu = item['type'] == "Reçu";

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isRecu ? Colors.green[100] : Colors.orange[100],
                  child: Icon(
                    item['icon'] as IconData,
                    color: isRecu ? Colors.green : Colors.orange,
                  ),
                ),
                title: Text(
                  item['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("${item['date']} • ${item['qty']}"),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isRecu ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isRecu ? "+ Reçu" : "- Distribué",
                    style: TextStyle(
                      color: isRecu ? Colors.green : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month - 1];
  }

  IconData _getIconForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('repas') || t.contains('plat') || t.contains('cuisiné')) {
      return Icons.fastfood;
    } else if (t.contains('médicament') || t.contains('medicament')) {
      return Icons.medical_services;
    } else if (t.contains('vêtement') || t.contains('vetement')) {
      return Icons.checkroom;
    } else if (t.contains('pain')) {
      return Icons.bakery_dining;
    } else if (t.contains('fruit') || t.contains('légume')) {
      return Icons.apple;
    }
    return Icons.volunteer_activism;
  }
}