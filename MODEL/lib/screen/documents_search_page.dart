import 'package:flutter/material.dart';
import 'package:afroforma/services/database_service.dart';
import 'package:afroforma/models/document.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:io';
// using dart:io Process

class DocumentsSearchPage extends StatefulWidget {
  const DocumentsSearchPage({Key? key}) : super(key: key);

  @override
  _DocumentsSearchPageState createState() => _DocumentsSearchPageState();
}

class _DocumentsSearchPageState extends State<DocumentsSearchPage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  Document? _result;
  String _mode = 'number'; // or 'url'
  bool _searchPerformed = false; // New state variable

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _result = null;
      _searchPerformed = true; // Set to true after a search is initiated
    });
    try {
      Document? d;
      if (_mode == 'number') {
        d = await DatabaseService().getDocumentByCertificateNumber(query);
      } else {
        d = await DatabaseService().getDocumentByValidationUrl(query);
      }
      setState(() => _result = d);
    } catch (e) {
      // show error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
    // Save to history
    if (_result != null) {
      final prefs = await SharedPreferences.getInstance();
      final key = _mode == 'number' ? 'search_history_numbers' : 'search_history_urls';
      final items = prefs.getStringList(key) ?? [];
      items.remove(_controller.text.trim());
      items.insert(0, _controller.text.trim());
      if (items.length > 20) items.removeRange(20, items.length);
      await prefs.setStringList(key, items);
      setState(() {});
    }
  }

  Future<List<String>> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _mode == 'number' ? 'search_history_numbers' : 'search_history_urls';
    return prefs.getStringList(key) ?? [];
  }

  void _openDocument() {
    if (_result == null) return;
    try {
      final path = _result!.path;
      if (!File(path).existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fichier introuvable.')));
        return;
      }
      if (Platform.isMacOS) {
        Process.run('open', [path]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [path]);
      } else if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', '', path]);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouverture non supportée.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher un certificat'),
        leading: const Icon(Icons.search), // Added search icon
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(labelText: _mode == 'number' ? 'Numéro certificat' : 'URL de validation'),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA0522D), // Brown color
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text(
                          'Rechercher',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                )
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(label: const Text('Par numéro'), selected: _mode == 'number', onSelected: (v) => setState(() => _mode = 'number')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Par URL'), selected: _mode == 'url', onSelected: (v) => setState(() => _mode = 'url')),
              ],
            ),
            const SizedBox(height: 20),
            if (_result != null) ...[
              ListTile(
                title: Text(_result!.title),
                subtitle: Text('Fichier: ${_result!.fileName}\nCert#: ${_result!.certificateNumber}\nURL: ${_result!.validationUrl}'),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copier numéro',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _result!.certificateNumber));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Numéro copié')));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.link),
                    tooltip: 'Copier URL',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _result!.validationUrl));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copiée')));
                    },
                  ),
                  TextButton(onPressed: _openDocument, child: const Text('Ouvrir')),
                ],
              ),
            ] else if (!_loading && _searchPerformed) ...[ // Only show if search performed and no results
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA0522D), Color(0xFF8B4513)], // Brown gradient
                      ),
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFA0522D).withOpacity(0.3), // Adjusted shadow color
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search_off, // A relevant icon for no results
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Aucun certificat trouvé',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Veuillez vérifier le numéro ou l\'URL, ou essayez une autre recherche.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            ] else if (!_loading && !_searchPerformed) ...[ // Initial state: no search performed yet
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA0522D), Color(0xFF8B4513)], // Brown gradient
                      ),
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFA0522D).withOpacity(0.3), // Adjusted shadow color
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search, // Icon for search
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Recherchez un certificat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Entrez le numéro de certificat ou l\'URL de validation pour trouver un document.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            ]
            ,
            const SizedBox(height: 12),
            FutureBuilder<List<String>>(
              future: _loadHistory(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                if (items.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Historique', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final v = items[i];
                          return ListTile(
                            title: Text(v, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                _controller.text = v;
                                _search();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
