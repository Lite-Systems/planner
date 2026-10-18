import 'package:planner/core/widgets/app_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:planner/core/utils/app_colors.dart';
import 'package:planner/core/utils/app_layout.dart';
import 'package:planner/core/utils/no_animation_route.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../providers/project_provider.dart';
import '../../../models/project.dart';
import '../widgets/project_dialog.dart';
import '../widgets/project_card.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();
  String? _selectedId;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _sortOrder = 'name';
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Project> _filteredProjects(List<Project> projects) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = projects.where((project) {
      final matchesSearch =
          query.isEmpty ||
          project.name.toLowerCase().contains(query) ||
          (project.customer?.toLowerCase().contains(query) ?? false) ||
          project.description.toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == 'all' || project.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      if (_sortOrder == 'date') {
        final aDate = a.endDate;
        final bDate = b.endDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  bool get _hasFilters =>
      _searchQuery.trim().isNotEmpty ||
      _statusFilter != 'all' ||
      _sortOrder != 'name';

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = 'all';
      _sortOrder = 'name';
    });
  }

  void _openProject(Project project) {
    if (widget.embedded) {
      setState(() => _selectedId = project.id);
      return;
    }
    Navigator.push(
      context,
      NoAnimationPageRoute(
        builder: (_) => ProjectDetailScreen(project: project),
      ),
    );
  }

  Widget _list(ProjectProvider provider, {required bool showHeader}) {
    final projects = _filteredProjects(provider.projects);
    final list = projects.isEmpty
        ? Center(child: Text('noProjectsYet'.tr()))
        : ListView.builder(
            controller: _scrollController,
            primary: false,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return ProjectCard(
                project: project,
                onTap: () => _openProject(project),
              );
            },
          );
    if (!showHeader) {
      return Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                top: 8,
                start: 16,
                end: 16,
              ),
              child: _filterButton(context),
            ),
          ),
          _filterPanel(context),
          Expanded(child: list),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'projects'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _filterButton(context),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const FaIcon(FontAwesomeIcons.plus, size: 18),
                onPressed: () => ProjectDialog.show(context),
              ),
            ],
          ),
        ),
        _filterPanel(context),
        Expanded(child: list),
      ],
    );
  }

  Widget _filterButton(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            _filtersExpanded
                ? FontAwesomeIcons.chevronUp
                : FontAwesomeIcons.sliders,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text('filterProjects'.tr()),
          if (_hasFilters) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _activeFilterCount.toString(),
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int get _activeFilterCount {
    var count = 0;
    if (_searchQuery.trim().isNotEmpty) count++;
    if (_statusFilter != 'all') count++;
    if (_sortOrder != 'name') count++;
    return count;
  }

  Widget _filterPanel(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: _filtersExpanded
          ? Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevatedBackground(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.separator(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoSearchTextField(
                    placeholder: 'searchProjects'.tr(),
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 12),
                  CupertinoSlidingSegmentedControl<String>(
                    backgroundColor: AppColors.elevatedBackground(context),
                    thumbColor: AppColors.cardBackground(context),
                    groupValue: _statusFilter,
                    children: {
                      'all': Text('allProjects'.tr()),
                      'active': Text('active'.tr()),
                      'archived': Text('archived'.tr()),
                    },
                    onValueChanged: (value) {
                      if (value != null) setState(() => _statusFilter = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'sortBy'.tr(),
                          style: TextStyle(
                            color: AppColors.secondaryLabel(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      CupertinoSlidingSegmentedControl<String>(
                        backgroundColor: AppColors.elevatedBackground(context),
                        thumbColor: AppColors.cardBackground(context),
                        groupValue: _sortOrder,
                        children: {
                          'name': Text('nameLabel'.tr()),
                          'date': Text('endDate'.tr()),
                        },
                        onValueChanged: (value) {
                          if (value != null) setState(() => _sortOrder = value);
                        },
                      ),
                    ],
                  ),
                  if (_hasFilters)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: CupertinoButton(
                        padding: const EdgeInsets.only(top: 8),
                        onPressed: _clearFilters,
                        child: Text('clearFilters'.tr()),
                      ),
                    ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final split = widget.embedded && AppLayout.of(context).isExpanded;
    return CupertinoPageScaffold(
      navigationBar: split
          ? null
          : AppNavigationBar(
              middle: Text('projects'.tr()),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const FaIcon(FontAwesomeIcons.plus, size: 20),
                onPressed: () => ProjectDialog.show(context),
              ),
            ),
      child: SafeArea(
        child: Consumer<ProjectProvider>(
          builder: (context, provider, child) {
            if (split) {
              Project? selected;
              if (_selectedId != null) {
                for (final project in _filteredProjects(provider.projects)) {
                  if (project.id == _selectedId) {
                    selected = project;
                    break;
                  }
                }
              }
              return Row(
                children: [
                  SizedBox(
                    width: 420,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          end: BorderSide(
                            color: AppColors.separator(context),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: _list(provider, showHeader: true),
                    ),
                  ),
                  Expanded(
                    child: selected == null
                        ? Center(child: Text('selectProject'.tr()))
                        : ProjectDetailScreen(
                            key: ValueKey(selected.id),
                            project: selected,
                            embedded: true,
                          ),
                  ),
                ],
              );
            }
            return _list(provider, showHeader: false);
          },
        ),
      ),
    );
  }
}
