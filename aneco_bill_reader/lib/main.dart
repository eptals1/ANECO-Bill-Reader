import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light().copyWith(
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 20),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: TextTheme(
          bodyLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(fontSize: 20, color: Colors.white),
        ),
      ),
      home: HomeScreen(toggleTheme: toggleTheme, isDarkMode: isDarkMode),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  HomeScreen({required this.toggleTheme, required this.isDarkMode});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts flutterTts = FlutterTts();
  bool isPlaying = false;
  bool isPaused = false;
  String textToRead = "Your ANECO bill details will be read aloud here.";
  File? _image; // Image to be picked
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  // Check if the permissions are granted at startup
  Future<void> _checkPermissions() async {
    PermissionStatus cameraStatus = await Permission.camera.status;
    PermissionStatus storageStatus = await Permission.storage.status;

    // Only request permissions if they are not granted
    if (!cameraStatus.isGranted || !storageStatus.isGranted) {
      _showPermissionDialog();
    }
  }

  // Request permission dialog if permission is denied
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Permission Required"),
            content: Text(
              "Camera and Storage access are needed to scan your bill. Do you want to allow it?",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close popup
                },
                child: Text("No"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context); // Close popup
                  await Permission.camera.request();
                  await Permission.storage.request();
                },
                child: Text("Yes"),
              ),
            ],
          ),
    );
  }

  // Update the text after OCR processing
  void _processImage(File image) async {
    // Perform text recognition
    final inputImage = InputImage.fromFile(image);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    if (recognizedText.text.isNotEmpty) {
      // Extract important details using regex or simple string searches
      String accountNumber = _extractDetail(
        recognizedText.text,
        "Account Number:",
      );
      String accountName = _extractDetail(recognizedText.text, "Account Name:");
      String powerRate = _extractDetail(recognizedText.text, "Power Rate");
      String presentReading = _extractDetail(
        recognizedText.text,
        "Present Reading",
      );
      String previousReading = _extractDetail(
        recognizedText.text,
        "Previous Reading",
      );
      String consumption = _extractDetail(
        recognizedText.text,
        "kWh Consumption",
      );
      String substation = _extractDetail(recognizedText.text, "Substation");
      String dueDate = _extractDetail(recognizedText.text, "Due Date");
      String arrears = _extractDetail(recognizedText.text, "Arrears");
      String surcharge = _extractDetail(recognizedText.text, "Surcharge");
      String surchargeEVAT = _extractDetail(
        recognizedText.text,
        "Surcharge EVAT",
      );
      String totalAmount = _extractDetail(recognizedText.text, "TOTAL AMOUNT");

      setState(() {
        // Combining all the extracted fields into a readable format
        textToRead = """
          Account Number: $accountNumber
          Account Name: $accountName
          Power Rate: $powerRate
          Present Reading: $presentReading
          Previous Reading: $previousReading
          kWh Consumption: $consumption
          Substation: $substation
          Due Date: $dueDate
          Arrears: $arrears
          Surcharge: $surcharge
          Surcharge EVAT: $surchargeEVAT
          TOTAL AMOUNT: $totalAmount
          """;
        _image = null; // Remove image after processing
      });
    } else {
      setState(() {
        textToRead =
            "No text found. Please try again."; // Handle no text detected
      });
    }
  }

  String _extractDetail(String text, String keyword) {
    // Regex to find the detail after the keyword, case-insensitive,
    // allowing whitespace around the keyword.
    final RegExp regExp = RegExp(
      r'(?<=\s*\b$keyword\b\s*)(.*?)',
      caseSensitive: true,
    );
    final match = regExp.firstMatch(text);
    return match != null ? match.group(0)?.trim() ?? 'N/A' : 'N/A';
  }

  // Pick an image using the camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _processImage(_image!); // Process the image after selection
    }
  }

  // Show the dialog to choose between Camera or Gallery
  void _showSourceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Select Image Source"),
            content: Text(
              "Would you like to use the camera or select from the gallery?",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  _pickImage(ImageSource.camera); // Open Camera
                },
                child: Text("Camera"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  _pickImage(ImageSource.gallery); // Open Gallery
                },
                child: Text("Gallery"),
              ),
            ],
          ),
    );
  }

  // Handle TTS: speak, pause, repeat
  Future<void> speak() async {
    if (textToRead.isNotEmpty) {
      await flutterTts.speak(textToRead);
      setState(() {
        isPlaying = true;
        isPaused = false;
      });
    }
  }

  Future<void> pause() async {
    await flutterTts.pause();
    setState(() {
      isPlaying = false;
      isPaused = true;
    });
  }

  Future<void> repeat() async {
    await flutterTts.stop();
    await speak(); // Re-trigger the speaking functionality
  }

  @override
  void initState() {
    super.initState();
    _checkPermissions(); // Check permissions on app startup
    flutterTts.setLanguage("en-US"); // Set default language for TTS
    flutterTts.setSpeechRate(0.5); // Set speech rate
    flutterTts.setVolume(1.0); // Set volume
  }

  @override
  void dispose() {
    flutterTts.stop(); // Stop speaking when the app is closed
    _textRecognizer.close(); // Close the text recognizer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ANECO Bill Reader"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              "Welcome! Tap the button to scan your bill.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed:
                  _showSourceDialog, // Open the source dialog on button press
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                textStyle: TextStyle(fontSize: 24),
              ),
              child: Text("Scan Bill"),
            ),
            SizedBox(height: 20),
            Text(
              "Audio Controls",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.play_arrow, size: 40),
                  onPressed: isPlaying ? null : speak,
                ),
                IconButton(
                  icon: Icon(Icons.pause, size: 40),
                  onPressed: isPlaying && !isPaused ? pause : null,
                ),
                IconButton(
                  icon: Icon(Icons.replay, size: 40),
                  onPressed: repeat,
                ),
              ],
            ),
            SizedBox(height: 30),
            // Make the extracted text scrollable
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    //textToRead,
                    //style: TextStyle(fontSize: 20),
                    //textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
