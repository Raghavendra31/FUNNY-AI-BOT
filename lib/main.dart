import 'package:flutter/material.dart'; // Import Flutter material design package
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv package to manage environment variables
import 'package:logging/logging.dart'; // Import logging package for debugging and logging
import 'chat_screen.dart'; // Import the ChatScreen widget (your main chat UI)

// Main function where the app starts execution
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure widget binding is initialized before running any asynchronous code

  // Setup logger
  Logger.root.level = Level.ALL; // Set logging level to capture all logs
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}'); // Print log messages to console
  });

  final logger = Logger('Main'); // Create a logger instance specifically for Main

  try {
    // Load environment variables from .env file
    await dotenv.load(fileName: ".env");
    logger.info("✅ Environment variables loaded successfully"); // Log success message after loading .env

    // Ensure the Groq API key exists in the loaded environment variables
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY is missing in the .env file!'); // Throw an exception if the API key is missing
    }
  } catch (e) {
    // If any error occurs while loading environment variables
    logger.severe("❌ Failed to load .env file or missing API key", e); // Log the error
    runApp(ErrorApp(errorMessage: e.toString())); // Run a fallback ErrorApp displaying the error
    return; // Exit the main function early
  }

  runApp(const MyApp()); // Run the main app if everything is fine
}

// Main application widget
class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Constructor with optional key

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hide the debug banner
      title: 'Funny Groq ChatBot 🤖', // Set the app title
      theme: ThemeData(
        primarySwatch: Colors.teal, // Set the primary theme color to teal
        appBarTheme: const AppBarTheme(
          elevation: 0, // Remove shadow under AppBar
          centerTitle: true, // Center the title in AppBar
        ),
        scaffoldBackgroundColor: Colors.white, // Set the background color of scaffold to white
      ),
      home: const ChatScreen(), // Set ChatScreen as the home page of the app
    );
  }
}

// Widget to show error if app fails to initialize properly
class ErrorApp extends StatelessWidget {
  final String errorMessage; // Variable to hold the error message

  const ErrorApp({Key? key, required this.errorMessage}) : super(key: key); // Constructor accepting errorMessage

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hide the debug banner
      home: Scaffold(
        appBar: AppBar(title: const Text("Error")), // AppBar showing 'Error' title
        body: Center(
          child: Text(
            '❌ Error: $errorMessage', // Display the error message in the center of the screen
            textAlign: TextAlign.center, // Center align the error text
            style: const TextStyle(fontSize: 18, color: Colors.red), // Style the error text
          ),
        ),
      ),
    );
  }
}
