import 'package:flutter/material.dart';

class FiltersSheet extends StatefulWidget {
  final String? searchText;
  final int? yearFrom;
  final int? yearTo;
  final int? capo;
  final int? category;
  final String sortBy;
  final bool ascending;
  final Function(String?, int?, int?, int?, int?, String, bool) onApply;

  const FiltersSheet({
    super.key,
    this.searchText,
    this.yearFrom,
    this.yearTo,
    this.capo,
    this.category,
    this.sortBy = 'updatedAt',
    this.ascending = false,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    String? searchText,
    int? yearFrom,
    int? yearTo,
    int? capo,
    int? category,
    String sortBy = 'updatedAt',
    bool ascending = false,
    required Function(String?, int?, int?, int?, int?, String, bool) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FiltersSheet(
        searchText: searchText,
        yearFrom: yearFrom,
        yearTo: yearTo,
        capo: capo,
        category: category,
        sortBy: sortBy,
        ascending: ascending,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late TextEditingController _yearFromController;
  late TextEditingController _yearToController;
  late TextEditingController _capoController;
  int? _selectedCategory;
  late String _sortBy;
  late bool _ascending;

  @override
  void initState() {
    super.initState();
    _yearFromController =
        TextEditingController(text: widget.yearFrom?.toString() ?? '');
    _yearToController =
        TextEditingController(text: widget.yearTo?.toString() ?? '');
    _capoController =
        TextEditingController(text: widget.capo?.toString() ?? '');
    _selectedCategory = widget.category;
    _sortBy = widget.sortBy.isEmpty ? 'lastOpenedAt' : widget.sortBy;
    _ascending = widget.ascending;
  }

  @override
  void dispose() {
    _yearFromController.dispose();
    _yearToController.dispose();
    _capoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () {
                    _yearFromController.clear();
                    _yearToController.clear();
                    _capoController.clear();
                    setState(() {
                      _selectedCategory = null;
                      _sortBy = 'lastOpenedAt';
                      _ascending = false;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Year Range',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearFromController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'From',
                      hintText: 'e.g. 1990',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _yearToController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'To',
                      hintText: 'e.g. 2024',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Capo',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _capoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capo Position',
                hintText: 'e.g. 2',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Number',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _selectedCategory?.toString() ?? ''),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Filter by Number',
                hintText: 'e.g. 1, 2, 3...',
              ),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value.isEmpty ? null : int.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Sort By',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Recently Updated'),
                  selected: _sortBy == 'updatedAt',
                  onSelected: (selected) {
                    if (selected) setState(() => _sortBy = 'updatedAt');
                  },
                ),
                ChoiceChip(
                  label: const Text('Recently Used'),
                  selected: _sortBy == 'lastOpenedAt',
                  onSelected: (selected) {
                    if (selected) setState(() => _sortBy = 'lastOpenedAt');
                  },
                ),
                ChoiceChip(
                  label: const Text('Date Added'),
                  selected: _sortBy == 'createdAt',
                  onSelected: (selected) {
                    if (selected) setState(() => _sortBy = 'createdAt');
                  },
                ),
                ChoiceChip(
                  label: const Text('Number'),
                  selected: _sortBy == 'category',
                  onSelected: (selected) {
                    if (selected) setState(() => _sortBy = 'category');
                  },
                ),
                ChoiceChip(
                  label: const Text('Title'),
                  selected: _sortBy == 'title',
                  onSelected: (selected) {
                    if (selected) setState(() => _sortBy = 'title');
                  },
                ),
                ChoiceChip(
                  label: const Text('Year'),
                  selected: _sortBy == 'year',
                  onSelected: (selected) {
                    if (selected) setState(() => _sortBy = 'year');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('A-Z / Oldest first'),
              subtitle: Text(_ascending ? 'Ascending' : 'Descending'),
              value: _ascending,
              onChanged: (value) => setState(() => _ascending = value),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final yearFrom = int.tryParse(_yearFromController.text);
                  final yearTo = int.tryParse(_yearToController.text);
                  final capo = int.tryParse(_capoController.text);
                  widget.onApply(
                    widget.searchText,
                    yearFrom,
                    yearTo,
                    capo,
                    _selectedCategory,
                    _sortBy,
                    _ascending,
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
          ),
      ),
    );
  }
}
