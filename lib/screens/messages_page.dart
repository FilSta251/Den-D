import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/message.dart';
import '../repositories/message_repository.dart';
import '../repositories/user_repository.dart';

/// Stránka pro zobrazení konverzací a odesílání zpráv.
/// Pouťívá StreamBuilder pro real-time aktualizace zpráv a
/// obsahuje textovĂ© pole s tláčítkem pro odeslání zprávy.
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Odesílá zprávu, pokud není text prázdný.
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final messageRepo = Provider.of<MessageRepository>(context, listen: false);
    try {
      await messageRepo.sendMessage(content);
      _messageController.clear();
      // Po odeslání zprávy automaticky scrollujeme na konec seznamu.
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('error_sending_message', args: [e.toString()]),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Získáme aktuální uťivatelskĂ© ID z UserRepository.
    final currentUserId =
        Provider.of<UserRepository>(context, listen: false).cachedUser?.id ??
            '';

    final messageRepo = Provider.of<MessageRepository>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('messages_title')),
      ),
      body: Column(
        children: [
          // Seznam zpráv s real-time aktualizací.
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: messageRepo.messageStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text(tr('error_loading_messages',
                          args: [snapshot.error.toString()])));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    // Porovnáme senderId se získaným aktuálním uťivatelským ID.
                    final isSentByCurrentUser =
                        message.senderId == currentUserId;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Align(
                        alignment: isSentByCurrentUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSentByCurrentUser
                                ? Colors.pinkAccent.withOpacity(0.8)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: TextStyle(
                                  color: isSentByCurrentUser
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('HH:mm').format(message.timestamp),
                                style: TextStyle(
                                  color: isSentByCurrentUser
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          // TextovĂ© pole a tláčítko pro odeslání zprávy.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: tr('message_input_hint'),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
