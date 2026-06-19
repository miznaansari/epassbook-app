import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_session.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.fetchSessions(auth).then((_) {
        if (chatProvider.sessions.isNotEmpty) {
          chatProvider.fetchSessionMessages(auth, chatProvider.sessions.first.id);
        } else {
          chatProvider.setActiveSession(null);
        }
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Auto-create session if none active
    if (chatProvider.activeSessionId == null) {
      await chatProvider.createSession(auth, title: text.length > 20 ? "${text.substring(0, 18)}..." : text);
    }
    
    await chatProvider.sendMessage(auth, text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final sessions = chatProvider.sessions;
    final messages = chatProvider.messages;

    final activeSession = sessions.firstWhere(
      (s) => s.id == chatProvider.activeSessionId,
      orElse: () => ChatSession(id: '', title: 'Antigravity Finance AI', userId: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
    );

    // Scroll to bottom when message count changes
    if (messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chatProvider.activeSessionId == null ? "Finance AI Assistant" : activeSession.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Text(
              "Antigravity Finance AI",
              style: TextStyle(fontSize: 10, color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Theme(
            data: Theme.of(context).copyWith(
              canvasColor: AppTheme.surface,
            ),
            child: DropdownButton<String>(
              value: chatProvider.selectedModel,
              dropdownColor: AppTheme.surface,
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryPurple, size: 16),
              onChanged: (String? val) {
                if (val != null) {
                  chatProvider.setSelectedModel(val);
                }
              },
              items: const [
                DropdownMenuItem(value: 'gemini-3.1-flash-lite', child: Text('Gemini 3.1 Lite')),
                DropdownMenuItem(value: 'gemini-2.5-flash', child: Text('Gemini 2.5 Flash')),
                DropdownMenuItem(value: 'gemma-4-26b', child: Text('Gemma 4 26B')),
                DropdownMenuItem(value: 'gemma-4-31b', child: Text('Gemma 4 31B')),
              ],
            ),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.forum_outlined, color: Colors.white),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        backgroundColor: AppTheme.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Chat History", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.add_comment_rounded, color: AppTheme.primaryPurple),
                      onPressed: () async {
                        Navigator.pop(context);
                        chatProvider.setActiveSession(null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("New chat started. Type a message to initialize.")),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.border),
              Expanded(
                child: sessions.isEmpty
                    ? const Center(child: Text("No chats yet", style: TextStyle(color: Colors.grey, fontSize: 13)))
                    : ListView.builder(
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final s = sessions[index];
                          final isSelected = s.id == chatProvider.activeSessionId;
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: AppTheme.primaryPurple.withOpacity(0.1),
                            title: Text(s.title, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(DateFormat('MM/dd/yyyy').format(s.updatedAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.roseRed, size: 18),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: AppTheme.surface,
                                    title: const Text("Delete Chat"),
                                    content: const Text("Delete this session record?"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: AppTheme.roseRed))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await chatProvider.deleteSession(auth, s.id);
                                }
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              chatProvider.fetchSessionMessages(auth, s.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Chat bubble view
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: AppTheme.primaryPurple.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.auto_awesome_rounded, size: 48, color: AppTheme.primaryPurple),
                          ),
                          const SizedBox(height: 20),
                          const Text("Ask Antigravity Finance AI", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 8),
                          const Text(
                            "Get instant visual breakdowns, query salary cycle leftovers, or ask for budget reviews using database tools.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final m = messages[index];
                      final isUser = m.role == 'user';
                      return _buildMessageBubble(m.content, isUser);
                    },
                  ),
          ),

          if (chatProvider.loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("AI is thinking", style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(color: Colors.grey.shade600, strokeWidth: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Message input bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: const Border(top: BorderSide(color: AppTheme.border, width: 1.0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Type your query here...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryPurple,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _handleSendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String content, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryPurple : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: isUser ? null : Border.all(color: AppTheme.border),
        ),
        child: Text(
          content,
          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35),
        ),
      ),
    );
  }
}
