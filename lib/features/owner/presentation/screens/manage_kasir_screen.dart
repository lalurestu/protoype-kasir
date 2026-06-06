import 'package:flutter/material.dart';

class ManageKasirScreen extends StatelessWidget {
  const ManageKasirScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Kasir Staff'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Budi (Kasir 1)'),
            subtitle: Text('budi@store.com'),
            trailing: Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new kasir logic
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
