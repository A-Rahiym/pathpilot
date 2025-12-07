import 'package:google_generative_ai/google_generative_ai.dart';
// import '../services/places_service.dart';
import '../core/constants.dart';

class DirectionsController {
  void sayHello(String message) {
    print("🤖 $message");
  }
}

// Reusable function
Future<void> runWelcomeMessage() async {
  final controller = DirectionsController();

  final model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: AppConstants.googleStudiogeminikey,
  );

  final userText = "start app";

  final response = await model.generateContent([
    Content.text("""
Generate a simple friendly welcome message for the user.
Keep it short.
User message: "$userText"
"""),
  ]);

  final message = response.text?.trim() ?? "Hello!";

  controller.sayHello(message);
}

// Entry point for dart run
void main() async {
  await runWelcomeMessage();
}
