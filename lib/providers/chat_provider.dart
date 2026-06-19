import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/chat_session.dart';
import '../config/constants.dart';
import 'auth_provider.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatSession> _sessions = [];
  List<ChatMessage> _messages = [];
  String? _activeSessionId;
  String _selectedModel = 'gemini-3.1-flash-lite';
  bool _loading = false;

  List<ChatSession> get sessions => _sessions;
  List<ChatMessage> get messages => _messages;
  String? get activeSessionId => _activeSessionId;
  String get selectedModel => _selectedModel;
  bool get loading => _loading;

  void setActiveSession(String? sessionId) {
    _activeSessionId = sessionId;
    _messages = [];
    notifyListeners();
  }

  void setSelectedModel(String modelId) {
    _selectedModel = modelId;
    notifyListeners();
  }

  Future<void> fetchSessions(AuthProvider auth) async {
    _loading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/chat/sessions'),
        headers: auth.headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        _sessions = list.map((e) => ChatSession.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching chat sessions: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> createSession(AuthProvider auth, {String? title}) async {
    _loading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/chat/sessions'),
        headers: auth.headers,
        body: jsonEncode(title != null ? {'title': title} : {}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final newSession = ChatSession.fromJson(data);
        _sessions.insert(0, newSession);
        _activeSessionId = newSession.id;
        _messages = [];
      }
    } catch (e) {
      debugPrint("Error creating chat session: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSessionMessages(AuthProvider auth, String sessionId) async {
    _loading = true;
    notifyListeners();
    _activeSessionId = sessionId;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/chat/sessions/$sessionId'),
        headers: auth.headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['messages'] != null) {
          final List<dynamic> list = data['messages'];
          _messages = list.map((e) => ChatMessage.fromJson(e)).toList();
        } else {
          _messages = [];
        }
      }
    } catch (e) {
      debugPrint("Error fetching chat messages: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSession(AuthProvider auth, String sessionId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/chat/sessions/$sessionId'),
        headers: auth.headers,
      );

      if (response.statusCode == 200) {
        _sessions.removeWhere((s) => s.id == sessionId);
        if (_activeSessionId == sessionId) {
          _activeSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
          _messages = [];
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting chat session: $e");
      return false;
    }
  }

  Future<void> sendMessage(AuthProvider auth, String content) async {
    if (content.trim().isEmpty) return;

    // 1. Instantly log local user message for fast UI updates
    final localUserMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatSessionId: _activeSessionId ?? '',
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    _messages.add(localUserMessage);
    notifyListeners();

    _loading = true;
    notifyListeners();

    try {
      // Format messages list (include history context)
      final List<Map<String, String>> historyList = _messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/chat'),
        headers: auth.headers,
        body: jsonEncode({
          'messages': historyList,
          'sessionId': _activeSessionId,
          'model': _selectedModel,
        }),
      );

      if (response.statusCode == 200) {
        final String assistantContent = response.body;
        
        // Retrieve new session ID if it was created on demand
        final serverSessionId = response.headers['x-session-id'];
        if (serverSessionId != null && serverSessionId.isNotEmpty) {
          _activeSessionId = serverSessionId;
        }

        final localAssistantMessage = ChatMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          chatSessionId: _activeSessionId ?? '',
          role: 'assistant',
          content: assistantContent,
          createdAt: DateTime.now(),
        );

        _messages.add(localAssistantMessage);
        await fetchSessions(auth); // Refresh session list to update titles
      }
    } catch (e) {
      debugPrint("Error sending message to Gemini: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
