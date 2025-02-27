import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomTextFieldScreen extends StatefulWidget {
  const CustomTextFieldScreen({super.key});

  @override
  _CustomTextFieldScreenState createState() => _CustomTextFieldScreenState();
}

class _CustomTextFieldScreenState extends State<CustomTextFieldScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Users"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No users found.'));
            }

            final users = snapshot.data!.docs;

            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final email = user['email'] ?? 'No email';
                final role = user['role'] ?? 'No role';

                return ListTile(
                  title: Text(email),
                  subtitle: Text(role),
                );
              },
            );
          },
        ),
      ),
    );
  }
}