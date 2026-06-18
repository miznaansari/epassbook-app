import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _campaigns = [];
  bool _loading = false;

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _frequency = 'DAILY';
  final _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCampaigns();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _fetchCampaigns() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/notifications/campaigns'),
        headers: auth.headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          _campaigns = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching notification campaigns: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddCampaignDialog() async {
    _titleController.clear();
    _messageController.clear();
    _frequency = 'DAILY';
    _timeController.text = '12:00';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Create Alert Schedule", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'ALERT TITLE', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'ALERT MESSAGE', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _frequency,
                      decoration: const InputDecoration(labelText: 'FREQUENCY'),
                      items: const [
                        DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                        DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                        DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => _frequency = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _timeController,
                      decoration: const InputDecoration(labelText: 'TIME (HH:MM)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    final title = _titleController.text.trim();
                    final message = _messageController.text.trim();
                    final time = _timeController.text.trim();
                    if (title.isEmpty || message.isEmpty || time.isEmpty) return;

                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final response = await http.post(
                      Uri.parse('${AppConfig.baseUrl}/api/notifications/campaigns'),
                      headers: auth.headers,
                      body: jsonEncode({
                        'title': title,
                        'message': message,
                        'frequency': _frequency,
                        'time': time,
                        'isActive': true
                      }),
                    );

                    if (response.statusCode == 200 && mounted) {
                      Navigator.pop(context);
                      _fetchCampaigns();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Alert schedule created successfully!")),
                      );
                    } else if (mounted) {
                      final body = jsonDecode(response.body);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(body['error'] ?? "Failed to create schedule.")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                  child: const Text("Create", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Alert Schedules", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
            onPressed: _showAddCampaignDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCampaigns,
        color: AppTheme.primaryPurple,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
            : _campaigns.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80.0, horizontal: 40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade700),
                            const SizedBox(height: 16),
                            const Text("No notification schedules configured.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _showAddCampaignDialog,
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                              child: const Text("Setup Alert Schedule", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _campaigns.length,
                    itemBuilder: (context, index) {
                      final c = _campaigns[index];
                      final isActive = c['isActive'] ?? true;
                      
                      return Card(
                        color: AppTheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.05))),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: isActive ? AppTheme.emeraldGreen.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                            child: Icon(Icons.alarm_on_rounded, color: isActive ? AppTheme.emeraldGreen : Colors.grey),
                          ),
                          title: Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(c['message'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Text("Frequency: ${c['frequency']} | Time: ${c['time']}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.emeraldGreen.withOpacity(0.15) : AppTheme.roseRed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? "Active" : "Inactive",
                              style: TextStyle(fontSize: 9, color: isActive ? AppTheme.emeraldGreen : AppTheme.roseRed, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
