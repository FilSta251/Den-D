import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../repositories/wedding_repository.dart';
import '../models/wedding_info.dart';
import '../services/onboarding_manager.dart';
import '../utils/constants.dart';

class ChatMessage {
  final String sender;
  final String message;
  ChatMessage({required this.sender, required this.message});
}

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen>
    with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final List<String> _questions = [
    tr('chat_question_name'),
    tr('chat_question_partner'),
    tr('chat_question_date'),
    tr('chat_question_budget'),
    tr('chat_question_venue'),
  ];
  int _currentQuestionIndex = 0;

  final Map<String, String> _weddingInfo = {
    "your_name": "--",
    "partner_name": "--",
    "wedding_date": "--",
    "wedding_budget": "--",
    "wedding_venue": "--",
  };

  bool _isBotTyping = false;
  bool _isChatComplete = false;
  late WeddingRepository _weddingRepository;

  @override
  void initState() {
    super.initState();
    debugPrint('[ChatBotScreen] Initializing ChatBotScreen');
    _weddingRepository = Provider.of<WeddingRepository>(context, listen: false);

    final currentUser = fb.FirebaseAuth.instance.currentUser;
    debugPrint(
        '[ChatBotScreen] Current user: ${currentUser?.uid}, Email: ${currentUser?.email}');

    _addBotMessage(tr('chatbot_greeting_1'));
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _addBotMessage(tr('chatbot_greeting_2'));
      }
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _addBotMessage(_questions[_currentQuestionIndex]);
      }
    });
  }

  void _addBotMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(sender: 'bot', message: message));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(sender: 'user', message: message));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _finishChat() async {
    if (!mounted) return;

    debugPrint('[ChatBotScreen] Finishing chat and marking as completed');

    setState(() => _isChatComplete = true);

    final userId = fb.FirebaseAuth.instance.currentUser?.uid;
    await OnboardingManager.markChatbotCompleted(userId: userId);
    debugPrint('[ChatBotScreen] Chatbot marked as completed for user: $userId');

    try {
      debugPrint(
          '[ChatBotScreen] Testing Firestore permissions before navigation');
      await _weddingRepository.testFirestorePermissions();
      debugPrint('[ChatBotScreen] Firestore permissions test passed');
    } catch (e) {
      debugPrint('[ChatBotScreen] Firestore permissions test failed: $e');
    }

    if (!mounted) return;

    // 🔴 DOČASNĚ: Když je subscription disabled, přeskočíme na hlavní stránku
    if (!Billing.subscriptionEnabled) {
      debugPrint(
          '[ChatBotScreen] Subscription disabled - navigating directly to main menu');
      // Označíme subscription jako "zobrazenou" aby se neopakoval onboarding
      await OnboardingManager.markSubscriptionShown(userId: userId);
      await OnboardingManager.markOnboardingCompleted(userId: userId);
      Navigator.pushReplacementNamed(context, '/brideGroomMain');
      return;
    }

    debugPrint(
        '[ChatBotScreen] Navigating to subscription screen: /subscription');
    Navigator.pushReplacementNamed(context, '/subscription');
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty || _isChatComplete) return;

    debugPrint(
        '[ChatBotScreen] User submitted answer: "$text" for question $_currentQuestionIndex');
    _addUserMessage(text);

    String key;
    switch (_currentQuestionIndex) {
      case 0:
        key = "your_name";
        break;
      case 1:
        key = "partner_name";
        break;
      case 2:
        key = "wedding_date";
        break;
      case 3:
        key = "wedding_budget";
        break;
      case 4:
        key = "wedding_venue";
        break;
      default:
        return;
    }
    _weddingInfo[key] = text.trim().isEmpty ? "--" : text.trim();
    debugPrint(
        '[ChatBotScreen] Updated wedding info field "$key" with value "${_weddingInfo[key]}"');

    _controller.clear();
    _currentQuestionIndex++;
    if (_currentQuestionIndex < _questions.length) {
      setState(() {
        _isBotTyping = true;
      });
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _isBotTyping = false;
      });
      debugPrint(
          '[ChatBotScreen] Moving to next question: ${_questions[_currentQuestionIndex]}');
      _addBotMessage(_questions[_currentQuestionIndex]);
    } else {
      debugPrint('[ChatBotScreen] All questions answered, saving data');
      _addBotMessage(tr('chat_thank_you'));
      try {
        final fb.User? currentUser = fb.FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          debugPrint('[ChatBotScreen] Error: No authenticated user found');
          throw Exception(tr('error_user_not_logged_in'));
        }

        debugPrint(
            '[ChatBotScreen] Current Firebase Auth user UID: ${currentUser.uid}');
        debugPrint(
            '[ChatBotScreen] Current Firebase Auth user email: ${currentUser.email}');
        debugPrint(
            '[ChatBotScreen] Current Firebase Auth user email verified: ${currentUser.emailVerified}');

        if (!mounted) return;

        final weddingRepo =
            Provider.of<WeddingRepository>(context, listen: false);

        debugPrint(
            '[ChatBotScreen] Testing Firebase permissions before saving data');
        try {
          await weddingRepo.testFirestorePermissions();
          debugPrint('[ChatBotScreen] Firebase permissions test passed');
        } catch (e) {
          debugPrint('[ChatBotScreen] Firebase permissions test failed: $e');
        }

        DateTime weddingDate;
        try {
          debugPrint(
              '[ChatBotScreen] Parsing wedding date: ${_weddingInfo["wedding_date"]}');
          weddingDate =
              DateFormat('dd.MM.yyyy').parse(_weddingInfo["wedding_date"]!);
          debugPrint(
              '[ChatBotScreen] Wedding date parsed successfully: $weddingDate');
        } catch (e) {
          debugPrint(
              '[ChatBotScreen] Error parsing wedding date with dd.MM.yyyy format: $e');
          try {
            weddingDate = DateTime.parse(_weddingInfo["wedding_date"]!);
            debugPrint(
                '[ChatBotScreen] Wedding date parsed with DateTime.parse: $weddingDate');
          } catch (e) {
            debugPrint(
                '[ChatBotScreen] Error parsing wedding date with DateTime.parse: $e');
            weddingDate = DateTime.now();
            debugPrint(
                '[ChatBotScreen] Using current date as fallback: $weddingDate');
          }
        }

        double budget;
        try {
          debugPrint(
              '[ChatBotScreen] Parsing budget: ${_weddingInfo["wedding_budget"]}');
          budget = double.parse(_weddingInfo["wedding_budget"]!);
          debugPrint('[ChatBotScreen] Budget parsed successfully: $budget');
        } catch (e) {
          debugPrint('[ChatBotScreen] Error parsing budget: $e');
          budget = 0.0;
          debugPrint('[ChatBotScreen] Using 0.0 as fallback budget');
        }

        final updatedWeddingInfo = WeddingInfo(
          userId: currentUser.uid,
          weddingDate: weddingDate,
          yourName: _weddingInfo["your_name"] ?? "--",
          partnerName: _weddingInfo["partner_name"] ?? "--",
          weddingVenue: _weddingInfo["wedding_venue"] ?? "--",
          budget: budget,
          notes: "--",
        );

        debugPrint(
            '[ChatBotScreen] Wedding info to save: ${updatedWeddingInfo.toJson()}');

        debugPrint(
            '[ChatBotScreen] Attempting to save wedding info to Firestore');
        await weddingRepo.updateWeddingInfo(updatedWeddingInfo);
        debugPrint('[ChatBotScreen] Wedding info saved successfully');
      } catch (e, stackTrace) {
        debugPrint('[ChatBotScreen] Error updating wedding info: $e');
        debugPrint('[ChatBotScreen] Stack trace: $stackTrace');

        try {
          final fb.User? currentUser = fb.FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            debugPrint(
                '[ChatBotScreen] Additional auth info - Email: ${currentUser.email}, EmailVerified: ${currentUser.emailVerified}');
            debugPrint(
                '[ChatBotScreen] User provider data: ${currentUser.providerData.map((p) => '${p.providerId}: ${p.uid}').join(', ')}');
          }
        } catch (authError) {
          debugPrint(
              '[ChatBotScreen] Error getting additional auth info: $authError');
        }
      }

      await Future.delayed(const Duration(seconds: 2));
      await _finishChat();
    }
  }

  @override
  void dispose() {
    debugPrint('[ChatBotScreen] Disposing ChatBotScreen');
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildBotTyping() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundImage: AssetImage('assets/images/chatbot.png'),
          ),
          SizedBox(width: 8),
          TypingIndicator(),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    if (message.sender == 'bot') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/chatbot.png',
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.smart_toy, color: Colors.white);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message.message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message.message,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('chatbot_title')),
        actions: [
          TextButton(
            onPressed: _finishChat,
            child: Text(
              tr('skip'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length + (_isBotTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isBotTyping && index == _messages.length) {
                    return _buildBotTyping();
                  }
                  return _buildMessage(_messages[index]);
                },
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).cardColor,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isChatComplete,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: tr('chat_hint'),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _handleSubmitted(_controller.text),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FadeTransition(
          opacity: _animation,
          child: const Text('.', style: TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 2),
        FadeTransition(
          opacity: _animation,
          child: const Text('.', style: TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 2),
        FadeTransition(
          opacity: _animation,
          child: const Text('.', style: TextStyle(fontSize: 24)),
        ),
      ],
    );
  }
}
