import 'package:flutter/material.dart';
import 'package:restaurant_dashboard_new/models/message.dart';
import 'package:restaurant_dashboard_new/services/message_service.dart';
import 'package:restaurant_dashboard_new/services/auth_service.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  late Future<List<Message>> _messagesFuture;
  final MessageService _messageService = MessageService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  Message? _selectedMessage;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      setState(() {
        _currentUser = currentUser;
      });

      _messagesFuture = _messageService.getMessages().then((messages) {
        if (messages.isNotEmpty) {
          setState(() {
            _selectedMessage = messages.first;
          });
        }
        return messages;
      });
    } catch (e) {
      // Handle error, e.g., show a snackbar
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Messages', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  _buildConversationList(),
                  const VerticalDivider(width: 1),
                  _buildChatView(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return Expanded(
      flex: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Message>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No messages found.'));
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isActive = _selectedMessage?.id == message.id;
                    return _buildConversationTile(
                      name: message.sender.username,
                      message: message.content,
                      time: '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                      avatar: 'https://i.pravatar.cc/150?u=${message.sender.id}', // Using a dynamic avatar service
                      isActive: isActive,
                      onTap: () {
                        setState(() {
                          _selectedMessage = message;
                        });
                      },
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

  Widget _buildConversationTile({
    required String name,
    required String message,
    required String time,
    required String avatar,
    int unread = 0,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(backgroundImage: NetworkImage(avatar)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (unread > 0)
            CircleAvatar(radius: 10, backgroundColor: Colors.orange, child: Text(unread.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)))
        ],
      ),
      tileColor: isActive ? Colors.orange.withOpacity(0.1) : null,
    );
  }

  Widget _buildChatView() {
    if (_selectedMessage == null) {
      return const Expanded(
        flex: 5,
        child: Center(
          child: Text('Select a conversation to start chatting.'),
        ),
      );
    }
    return Expanded(
      flex: 5,
      child: Column(
        children: [
          _buildChatHeader(),
          const Divider(height: 1),
          Expanded(
            child: _currentUser == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: _selectedMessage != null
                        ? _buildConversationHistory(_selectedMessage!)
                        : [],
                  ),
          ),
          _buildMessageInputField(),
        ],
      ),
    );
  }

  List<Widget> _buildConversationHistory(Message message) {
    // This is a placeholder. In a real app, you would fetch the full message history for the conversation.
    return [
      _buildChatMessage(isMe: message.sender.id != _currentUser!.id, message: message.content),
      _buildChatMessage(isMe: message.sender.id == _currentUser!.id, message: 'This is a reply from the other user.'),
    ];
  }

  Widget _buildChatHeader() {
    final otherUser = _selectedMessage!.sender.id == _currentUser!.id
        ? _selectedMessage!.recipient
        : _selectedMessage!.sender;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${otherUser.id}')),
          const SizedBox(width: 12),
          Text(otherUser.username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildChatMessage({required bool isMe, required String message}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isMe ? Colors.orange : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(message, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
      ),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty || _selectedMessage == null || _currentUser == null) {
      return;
    }

    try {
      final otherUser = _selectedMessage!.sender.id == _currentUser!.id
          ? _selectedMessage!.recipient
          : _selectedMessage!.sender;

      await _messageService.sendMessage(otherUser.id, _messageController.text);

      setState(() {
        // A more robust implementation would update the message list and history
        _messageController.clear();
      });
    } catch (e) {
      // Handle error
      print(e);
    }
  }

  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
            ),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            mini: true,
            onPressed: _sendMessage,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
