import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notes/screens/notice.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Stream<QuerySnapshot> notesStream = FirebaseFirestore.instance
      .collection('notices')
      .snapshots();

  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  Color getRandomColor() {
    final colors = [
      Colors.amber.shade100,
      Colors.lightBlue.shade100,
      Colors.pink.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
    ];
    return colors[DateTime.now().millisecond % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notes',
          style: GoogleFonts.ubuntu(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => const EditScreen(documentId: ''));
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search notes...',
                hintStyle: const TextStyle(color: Colors.black45),
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: notesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final notes = snapshot.data?.docs ?? [];

                // Filter notes based on searchQuery
                final filteredNotes = notes.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final text = (data['text'] ?? '').toString().toLowerCase();
                  return title.contains(searchQuery) ||
                      text.contains(searchQuery);
                }).toList();

                if (filteredNotes.isEmpty) {
                  return const Center(child: Text("No notes found."));
                }

                return ListView.builder(
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final doc = filteredNotes[index];
                    final note = doc.data() as Map<String, dynamic>;
                    final noteText = note['text'] as String?;
                    final title = note['title'] as String?;

                    String plainText = '';
                    if (noteText != null && noteText.trim().isNotEmpty) {
                      try {
                        final deltaJson = jsonDecode(noteText);
                        final document = Document.fromJson(deltaJson);
                        plainText = document.toPlainText().trim();
                      } catch (e) {
                        plainText = '[Invalid note content]';
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        margin: const EdgeInsets.all(7),
                        elevation: 5,
                        color: getRandomColor(),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          title: Text(
                            title ?? 'No Title',
                            style: GoogleFonts.ubuntu(
                              color: Colors.black87,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            plainText,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ubuntu(
                              color: Colors.black45,
                              fontSize: 15,
                            ),
                          ),
                          onTap: () {
                            Get.to(() => EditScreen(documentId: doc.id));
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
