import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/wikipedia_service.dart';

class WikipediaKnowledgeDialog extends StatefulWidget {
  final String query;
  final String subtitle;
  final WikipediaService wikipediaService;

  const WikipediaKnowledgeDialog({
    super.key,
    required this.query,
    required this.wikipediaService,
    this.subtitle = 'Wikipedia Insights',
  });

  static void show(
    BuildContext context, {
    required String query,
    required WikipediaService wikipediaService,
    String subtitle = 'Wikipedia Insights',
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => WikipediaKnowledgeDialog(
        query: query,
        wikipediaService: wikipediaService,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<WikipediaKnowledgeDialog> createState() => _WikipediaKnowledgeDialogState();
}

class _WikipediaKnowledgeDialogState extends State<WikipediaKnowledgeDialog> {
  late Future<WikipediaSummary?> _future;
  late final TextEditingController _searchController;
  late String _currentQuery;

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.query;
    _searchController = TextEditingController(text: _currentQuery);
    _loadSummary();
  }

  void _loadSummary() {
    _future = widget.wikipediaService.fetchSummary(_currentQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmit(String val) {
    if (val.trim().isNotEmpty) {
      setState(() {
        _currentQuery = val.trim();
        _loadSummary();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.search, size: 18, color: theme.colorScheme.primary),
                    onPressed: () => _onSearchSubmit(_searchController.text),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search Wikipedia...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: _onSearchSubmit,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<WikipediaSummary?>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.primary),
                        const SizedBox(height: 24),
                        Text(
                          'Searching Wikipedia...',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
                        const SizedBox(height: 20),
                        Text(
                          'No Wikipedia summary found for\n"$_currentQuery".',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, height: 1.4, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ],
                    );
                  }

                  final summary = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            if (summary.thumbnailUrl != null) ...[
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    summary.thumbnailUrl!,
                                    height: 150,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              summary.extract,
                              style: TextStyle(fontSize: 13, height: 1.6, color: theme.colorScheme.onSurface.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (summary.pageUrl != null)
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              foregroundColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Read Full Wikipedia Article', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final uri = Uri.parse(summary.pageUrl!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
