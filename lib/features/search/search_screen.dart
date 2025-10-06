import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recibos_flutter/core/di/service_locator.dart';
import 'package:recibos_flutter/core/services/search_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchService = sl<SearchService>();
  final _speech = stt.SpeechToText();

  late TabController _tabController;

  bool _isSearching = false;
  bool _showSuggestions = false;
  bool _isListening = false;
  bool _speechAvailable = false;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _recentSearches = [];
  List<Map<String, dynamic>> _popularSearches = [];
  List<Map<String, dynamic>> _savedFilters = [];

  int _totalResults = 0;
  String? _errorMessage;

  // Filtros avanzados
  String? _selectedCategory;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  double? _minAmount;
  double? _maxAmount;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Set initial query if provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      // Perform search with initial query
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery);
      });
    }

    _loadInitialData();
    _initSpeech();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _searchService.cancelDebounce();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    setState(() {});
  }

  Future<void> _loadInitialData() async {
    try {
      final recent = await _searchService.getSearchHistory(limit: 10, type: 'recent');
      final popular = await _searchService.getSearchHistory(limit: 10, type: 'popular');
      final filters = await _searchService.getSavedFilters();

      setState(() {
        _recentSearches = recent;
        _popularSearches = popular;
        _savedFilters = filters;
      });
    } catch (e) {
      // Silent fail for initial data
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _showSuggestions = true);

    // Get suggestions with debouncing
    _searchService.searchWithDebounce(
      query: query,
      onSearch: _loadSuggestions,
    );
  }

  Future<void> _loadSuggestions(String query) async {
    try {
      final suggestions = await _searchService.getSearchSuggestions(query: query, limit: 10);
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      // Silent fail for suggestions
    }
  }

  Future<void> _performSearch([String? query]) async {
    final searchQuery = query ?? _searchController.text.trim();

    if (searchQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _showSuggestions = false;
      _errorMessage = null;
    });

    try {
      final result = await _searchService.searchReceipts(
        query: searchQuery,
        category: _selectedCategory,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        minAmount: _minAmount,
        maxAmount: _maxAmount,
      );

      setState(() {
        _searchResults = (result['receipts'] as List).cast<Map<String, dynamic>>();
        _totalResults = result['total'] as int;
        _isSearching = false;
      });

      // Refresh history
      _loadInitialData();
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;

    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _searchController.text = result.recognizedWords;
        });

        if (result.finalResult) {
          _performSearch();
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _clearHistory() async {
    try {
      await _searchService.clearSearchHistory();
      setState(() {
        _recentSearches = [];
        _popularSearches = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.searchHistoryCleared)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing history: $e')),
        );
      }
    }
  }

  void _applyFilter(Map<String, dynamic> filter) {
    final filters = filter['filters'] as Map<String, dynamic>;

    setState(() {
      _selectedCategory = filters['category'];
      if (filters['dateFrom'] != null) {
        _dateFrom = DateTime.parse(filters['dateFrom']);
      }
      if (filters['dateTo'] != null) {
        _dateTo = DateTime.parse(filters['dateTo']);
      }
      _minAmount = filters['minAmount']?.toDouble();
      _maxAmount = filters['maxAmount']?.toDouble();
    });

    // Increment usage count
    _searchService.useSavedFilter(filter['id']);

    if (_searchController.text.isNotEmpty) {
      _performSearch();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _dateFrom = null;
      _dateTo = null;
      _minAmount = null;
      _maxAmount = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t.searchReceipts,
            border: InputBorder.none,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_speechAvailable)
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? theme.colorScheme.primary : null,
                    ),
                    onPressed: _isListening ? _stopListening : _startListening,
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _performSearch(),
                ),
              ],
            ),
          ),
          onChanged: _onSearchChanged,
          onSubmitted: _performSearch,
        ),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters panel
          if (_showFilters)
            _buildFiltersPanel(),

          // Content
          Expanded(
            child: _showSuggestions
                ? _buildSuggestionsView()
                : _searchResults.isNotEmpty
                    ? _buildSearchResults()
                    : _buildHistoryAndFilters(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_selectedCategory != null)
                Chip(
                  label: Text(_selectedCategory!),
                  onDeleted: () => setState(() => _selectedCategory = null),
                ),
              if (_dateFrom != null)
                Chip(
                  label: Text('From: ${_dateFrom!.toLocal().toString().split(' ')[0]}'),
                  onDeleted: () => setState(() => _dateFrom = null),
                ),
              if (_dateTo != null)
                Chip(
                  label: Text('To: ${_dateTo!.toLocal().toString().split(' ')[0]}'),
                  onDeleted: () => setState(() => _dateTo = null),
                ),
              if (_minAmount != null)
                Chip(
                  label: Text('Min: \$${_minAmount!.toStringAsFixed(2)}'),
                  onDeleted: () => setState(() => _minAmount = null),
                ),
              if (_maxAmount != null)
                Chip(
                  label: Text('Max: \$${_maxAmount!.toStringAsFixed(2)}'),
                  onDeleted: () => setState(() => _maxAmount = null),
                ),
            ],
          ),
          if (_selectedCategory != null || _dateFrom != null || _dateTo != null || _minAmount != null || _maxAmount != null)
            TextButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear filters'),
              onPressed: _clearFilters,
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsView() {
    if (_suggestions.isEmpty) {
      return const Center(child: Text('Type to see suggestions...'));
    }

    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final type = suggestion['type'] as String;

        IconData icon;
        switch (type) {
          case 'merchant':
            icon = Icons.store;
            break;
          case 'category':
            icon = Icons.category;
            break;
          case 'tag':
            icon = Icons.label;
            break;
          default:
            icon = Icons.search;
        }

        return ListTile(
          leading: Icon(icon, size: 20),
          title: Text(suggestion['suggestion'] as String),
          subtitle: Text('$type · ${suggestion['count']} receipts'),
          onTap: () {
            _searchController.text = suggestion['suggestion'] as String;
            _performSearch();
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            ElevatedButton(
              onPressed: () => _performSearch(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$_totalResults results found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final receipt = _searchResults[index];
              return ListTile(
                leading: const Icon(Icons.receipt),
                title: Text(receipt['merchantName'] ?? 'Unknown'),
                subtitle: Text('\$${receipt['amount']} · ${receipt['category']}'),
                trailing: Text(receipt['purchaseDate']?.toString().split('T')[0] ?? ''),
                onTap: () {
                  context.push('/detalle', extra: receipt);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryAndFilters() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Recent'),
              Tab(text: 'Popular'),
              Tab(text: 'Saved Filters'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecentSearches(),
                _buildPopularSearches(),
                _buildSavedFilters(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return const Center(child: Text('No recent searches'));
    }

    return Column(
      children: [
        ListTile(
          trailing: TextButton(
            onPressed: _clearHistory,
            child: const Text('Clear all'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final search = _recentSearches[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(search['query'] as String),
                subtitle: Text('${search['resultsCount']} results'),
                onTap: () {
                  _searchController.text = search['query'] as String;
                  _performSearch();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularSearches() {
    if (_popularSearches.isEmpty) {
      return const Center(child: Text('No popular searches'));
    }

    return ListView.builder(
      itemCount: _popularSearches.length,
      itemBuilder: (context, index) {
        final search = _popularSearches[index];
        return ListTile(
          leading: const Icon(Icons.trending_up),
          title: Text(search['query'] as String),
          subtitle: Text('${search['search_count']} searches'),
          onTap: () {
            _searchController.text = search['query'] as String;
            _performSearch();
          },
        );
      },
    );
  }

  Widget _buildSavedFilters() {
    if (_savedFilters.isEmpty) {
      return const Center(child: Text('No saved filters'));
    }

    return ListView.builder(
      itemCount: _savedFilters.length,
      itemBuilder: (context, index) {
        final filter = _savedFilters[index];
        return ListTile(
          leading: const Icon(Icons.filter_alt),
          title: Text(filter['name'] as String),
          subtitle: Text(filter['description'] ?? 'Used ${filter['useCount']} times'),
          onTap: () => _applyFilter(filter),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await _searchService.deleteSavedFilter(filter['id']);
              _loadInitialData();
            },
          ),
        );
      },
    );
  }
}
