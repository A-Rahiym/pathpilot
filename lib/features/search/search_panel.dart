/// Search bar + autocomplete dropdown widget.
/// Consumes SearchState via Riverpod and delegates actions to SearchController.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../speech/speech_controller.dart';
import 'search_controller.dart';

class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchControllerProvider);
    final searchController = ref.read(searchControllerProvider.notifier);
    final speechState = ref.watch(speechControllerProvider);
    final speechController = ref.read(speechControllerProvider.notifier);

    return Column(
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF232323),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search destination',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      searchController.clearSearchResults();
                      _textController.clear();
                      searchController.clearPendingSearch();
                    } else {
                      searchController.searchLocations(value);
                    }
                  },
                  onSubmitted: (value) {
                    if (value.isEmpty) return;
                    searchController.setPendingSearch(value);
                    searchController.handleLocationRequest(value);
                  },
                ),
              ),
              if (searchState.pendingSearch != null &&
                  !searchState.showSearchResults)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final query = searchState.pendingSearch;
                    if (query == null) return;
                    await searchController.handleLocationRequest(query);
                    searchController.clearPendingSearch();
                    searchController.clearSearchResults();
                    _textController.clear();
                  },
                  child: const Text('Navigate'),
                ),
              IconButton(
                icon: Icon(
                  speechState.isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                ),
                onPressed: speechState.isListening
                    ? () {
                        speechController.stopListening();
                      }
                    : () {
                        speechController.startListening();
                      },
              ),
            ],
          ),
        ),
        if (searchState.showSearchResults &&
            searchState.searchLabels.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF232323),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              itemCount: searchState.searchLabels.length,
              itemBuilder: (context, index) {
                final label = searchState.searchLabels[index];
                final result = searchState.searchResults.isNotEmpty
                    ? searchState.searchResults[index]
                    : null;
                return ListTile(
                  title: Text(
                    label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    result != null
                        ? '${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}'
                        : 'Address details...',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () async {
                    _textController.text = label;
                    await searchController.handleSearchResultTap(index);
                    searchController.clearPendingSearch();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
