//pkg add
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//pkg add
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';


// class ProfileScreen extends StatelessWidget {

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  //add code
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadSavedProfileImage();
  }

  Future<void> _loadSavedProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileImagePath = prefs.getString('profile_image_path');
      if (_profileImagePath != null) {
        _profileImage = File(_profileImagePath!);
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final File imageFile = File(pickedFile.path);

      // Save image path to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', imageFile.path);

      setState(() {
        _profileImage = imageFile;
        _profileImagePath = imageFile.path;
      });
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Profile Picture'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }




  Future<String?> _getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return userDoc['role'] ?? 'Not Available';
    } catch (e) {
      return 'Not Available';
    }
  }
  Future<String?> _getUserFirstName(String uid) async {
    try {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return userDoc['firstName'] ?? 'Not Available';
    } catch (e) {
      return 'Not Available';
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
    //         Center(
    //           child: CircleAvatar(
    //             radius: 50,
    //             // backgroundImage: AssetImage('assets/images/profile_placeholder.png'),
    //           ),
    // ),

            //center
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : const AssetImage('assets/images/profile_placeholder.png') as ImageProvider,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImagePickerDialog,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.blue,
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),





            const SizedBox(height: 20),
            _buildProfileInfo('Email', user?.email ?? 'Not Available'),
            const SizedBox(height: 10),
            FutureBuilder<String?>(
              future: _getUserRole(user?.uid ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return _buildProfileInfo('Role', 'Error fetching role');
                } else {
                  return _buildProfileInfo('Role', snapshot.data ?? 'Not Available');
                }
              },
            ),
            const SizedBox(height: 10),
            FutureBuilder<String?>(
              future: _getUserFirstName(user?.uid ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return _buildProfileInfo('First Name', 'Error fetching role');
                } else {
                  return _buildProfileInfo('First Name', snapshot.data ?? 'Not Available');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildProfileInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}