import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:notes/screens/home.dart';

class EditScreen extends StatefulWidget {
  final String? documentId; // Nullable to support create mode

  const EditScreen({super.key, this.documentId});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late TextEditingController titleController;
  late TextEditingController noticeController;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    noticeController = TextEditingController();
    if (widget.documentId != null && widget.documentId!.isNotEmpty) {
      fetchNoticeDetails();
    }
  }

  Future<void> fetchNoticeDetails() async {
    try {
      final doc = await firestore
          .collection('notices')
          .doc(widget.documentId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        titleController.text = data['title'] ?? '';
        noticeController.text = data['text'] ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> saveOrUpdateNotice() async {
    try {
      FocusScope.of(context).requestFocus(FocusNode()); // Remove focus
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // Wait for keyboard to hide

      if (widget.documentId != null && widget.documentId!.isNotEmpty) {
        await firestore.collection('notices').doc(widget.documentId).update({
          'title': titleController.text,
          'text': noticeController.text,
        });
      } else {
        await firestore.collection('notices').add({
          'title': titleController.text,
          'text': noticeController.text,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> deleteNotice() async {
    try {
      if (widget.documentId != null && widget.documentId!.isNotEmpty) {
        await firestore.collection('notices').doc(widget.documentId).delete();

        Get.offAll(() => const HomePage());

        Get.snackbar(
          'Deleted',
          'Note deleted',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.black87,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Delete failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  void addDocumentToHomeCollection(String title, String content) async {
    try {
      await firestore.collection('selected').doc('selected').set({
        'title': title,
        'content': content,
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Displayed on Home')));
    } catch (e) {
      print('Error adding to home: $e');
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    noticeController.dispose();
    super.dispose();
  }

  void _showActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1f1d20),
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.save, color: Colors.grey),
            title: const Text('Save', style: TextStyle(color: Colors.grey)),
            onTap: () {
              saveOrUpdateNotice();
              Navigator.pop(context);
            },
          ),
          if (widget.documentId != null && widget.documentId!.isNotEmpty) ...[
            ListTile(
              leading: const Icon(
                CupertinoIcons.bookmark_fill,
                color: Colors.grey,
              ),
              title: const Text(
                'Display on Home',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                addDocumentToHomeCollection(
                  titleController.text,
                  noticeController.text,
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () async {
                Navigator.pop(context);

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Delete'),
                    content: const Text(
                      'Are you sure you want to delete this note?',
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await deleteNotice();

                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomePage()),
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 30),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Title",
                      hintStyle: TextStyle(
                        color: Colors.grey.withOpacity(0.8),
                        fontSize: 30,
                      ),
                    ),
                  ),
                  TextField(
                    controller: noticeController,
                    maxLines: null,
                    style: const TextStyle(color: Colors.grey, fontSize: 18),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Notice Content",
                      hintStyle: TextStyle(
                        color: Colors.grey.withOpacity(0.8),
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showActions,
        backgroundColor: const Color(0xFF1f1d20),
        child: const Icon(Icons.menu, color: Colors.grey),
      ),
    );
  }
}
