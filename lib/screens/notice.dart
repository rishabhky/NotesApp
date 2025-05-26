import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:notes/screens/home.dart';
import 'package:http/http.dart' as http;

class EditScreen extends StatefulWidget {
  final String? documentId;

  const EditScreen({super.key, this.documentId});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late TextEditingController titleController;
  late QuillController _quillController;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    _quillController = QuillController.basic();

    if (widget.documentId != null && widget.documentId!.isNotEmpty) {
      fetchNoticeDetails();
    }
  }

  Future<void> summarizeAndShowDialog(
    BuildContext context,
    String inputText,
  ) async {
    final url = Uri.parse(
      "http://192.168.0.104:8000/summarize",
    ); // Replace with your IP or hosted URL

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": inputText}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['summary'];

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Summary"),
            content: Text(summary),
            actions: [
              TextButton(
                child: Text("Close"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } else {
        throw Exception("Failed to summarize");
      }
    } catch (e) {
      print("Error: $e");
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Error"),
          content: Text("Unable to summarize the notice."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
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

        final contentJson = data['text'];
        if (contentJson != null) {
          final docContent = Document.fromJson(jsonDecode(contentJson));
          setState(() {
            _quillController = QuillController(
              document: docContent,
              selection: const TextSelection.collapsed(offset: 0),
            );
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> saveOrUpdateNotice() async {
    try {
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 100));

      final content = jsonEncode(_quillController.document.toDelta().toJson());

      if (widget.documentId != null && widget.documentId!.isNotEmpty) {
        await firestore.collection('notices').doc(widget.documentId).update({
          'title': titleController.text,
          'text': content,
        });
      } else {
        await firestore.collection('notices').add({
          'title': titleController.text,
          'text': content,
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

  void addDocumentToHomeCollection(String title, String contentJson) async {
    try {
      await firestore.collection('selected').doc('selected').set({
        'title': title,
        'content': contentJson,
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Displayed on Home')));
    } catch (e) {
      print('Error adding to home: $e');
    }
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
                final content = jsonEncode(
                  _quillController.document.toDelta().toJson(),
                );
                addDocumentToHomeCollection(titleController.text, content);
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
            ListTile(
              leading: const Icon(Icons.summarize, color: Colors.grey),
              title: const Text(
                'Summarize',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                final noticeText = _quillController.document
                    .toPlainText()
                    .trim();

                if (noticeText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nothing to summarize")),
                  );
                  return;
                }
                // Or any source of text
                summarizeAndShowDialog(context, noticeText);
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    _quillController.dispose();
    super.dispose();
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
                  const SizedBox(height: 12),
                  QuillSimpleToolbar(
                    controller: _quillController,
                    config: const QuillSimpleToolbarConfig(
                      iconTheme: QuillIconTheme(
                        iconButtonSelectedData: IconButtonData(
                          color: Colors.white,
                          iconSize: 20,
                        ),
                        iconButtonUnselectedData: IconButtonData(
                          color: Colors.white54,
                          iconSize: 20,
                        ),
                      ),
                      showFontSize: true,
                      showBoldButton: true,
                      showItalicButton: true,
                      showListCheck: true,
                      showListBullets: true,
                      showListNumbers: true,

                      showStrikeThrough: false,
                      showUnderLineButton: true,
                      showCodeBlock: false,
                      showQuote: false,
                      showInlineCode: false,
                      showColorButton: false,
                      showBackgroundColorButton: false,
                      showClearFormat: false,
                      showDirection: false,
                      showAlignmentButtons: false,
                      showIndent: false,
                      showLink: false,
                      showUndo: false,
                      showRedo: false,
                      showSearchButton: false,
                      showHeaderStyle: true,
                      showFontFamily: false,
                      showSubscript: false,
                      showSuperscript: false,
                    ),
                  ),

                  const SizedBox(height: 12),
                  Container(
                    height: 500,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(200, 33, 33, 33),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: QuillEditor.basic(
                      controller: _quillController,
                      config: const QuillEditorConfig(
                        autoFocus: true,
                        expands: false,
                        padding: EdgeInsets.zero,
                        scrollable: true,
                        customStyles: DefaultStyles(
                          color: Color.fromRGBO(5, 5, 156, 0),
                          leading: DefaultListBlockStyle(
                            TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            HorizontalSpacing(0, 0),
                            VerticalSpacing(0, 0),
                            VerticalSpacing(2, 2),
                            BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                left: BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                            null,
                          ),
                          lists: DefaultListBlockStyle(
                            TextStyle(
                              color: Colors.white,
                              decorationColor: Colors.white,
                            ),
                            HorizontalSpacing(0, 0),
                            VerticalSpacing(0, 0),
                            VerticalSpacing(2, 2),
                            BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                left: BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                            null,
                          ),

                          paragraph: DefaultTextBlockStyle(
                            TextStyle(color: Colors.white),
                            HorizontalSpacing(0, 0),
                            VerticalSpacing(0, 0),
                            VerticalSpacing(0, 0),
                            null,
                          ),
                          h1: DefaultTextBlockStyle(
                            TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            HorizontalSpacing(0, 0),
                            VerticalSpacing(0, 0),
                            VerticalSpacing(0, 0),
                            null,
                          ),
                          h2: DefaultTextBlockStyle(
                            TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            HorizontalSpacing(0, 0),
                            VerticalSpacing(0, 0),
                            VerticalSpacing(0, 0),
                            null,
                          ),
                          h3: DefaultTextBlockStyle(
                            TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            HorizontalSpacing(0, 0),
                            VerticalSpacing(0, 0),
                            VerticalSpacing(0, 0),
                            null,
                          ),
                        ),
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
        backgroundColor: const Color.fromARGB(255, 197, 196, 198),
        child: const Icon(Icons.menu, color: Colors.black87),
      ),
    );
  }
}
