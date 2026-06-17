part of '../../main.dart';

enum _AcopBlockCategory { event, control, message, data, platform, utility }

enum _AcopBlockFieldKind { text, number, select, multiline }

enum _AcopUnsavedExitAction { save, discard, cancel }

class _AcopVariableSuggestion {
  const _AcopVariableSuggestion(this.labelKey, this.expression);

  final String labelKey;
  final String expression;
}

class _AcopBlockFieldTemplate {
  const _AcopBlockFieldTemplate({
    required this.key,
    required this.labelKey,
    required this.kind,
    this.defaultValue = '',
    this.options = const <String>[],
  });

  final String key;
  final String labelKey;
  final _AcopBlockFieldKind kind;
  final String defaultValue;
  final List<String> options;
}

class _AcopBlockTemplate {
  const _AcopBlockTemplate({
    required this.id,
    required this.titleKey,
    required this.category,
    required this.color,
    required this.icon,
    required this.fields,
    required this.builder,
    this.descriptionKey = '',
    this.permissions = const <String>[],
  });

  final String id;
  final String titleKey;
  final String descriptionKey;
  final _AcopBlockCategory category;
  final Color color;
  final IconData icon;
  final List<_AcopBlockFieldTemplate> fields;
  final String Function(Map<String, String> fields) builder;
  final List<String> permissions;
}

class _AcopWorkspaceBlock {
  _AcopWorkspaceBlock({
    required this.id,
    required this.template,
    required this.values,
  });

  final String id;
  final _AcopBlockTemplate template;
  final Map<String, String> values;
  bool collapsed = false;

  String buildCode() => template.builder(values);
}

class _AcopBlockDraft {
  const _AcopBlockDraft({required this.code});

  final String code;
}

class _AcopImportedBlock {
  const _AcopImportedBlock(this.templateId, this.values);

  final String templateId;
  final Map<String, String> values;
}

class _AcopBlockEditorScreen extends StatefulWidget {
  const _AcopBlockEditorScreen({
    required this.initialCode,
    required this.showGeneratedCode,
  });

  final String initialCode;
  final bool showGeneratedCode;

  @override
  State<_AcopBlockEditorScreen> createState() => _AcopBlockEditorScreenState();
}

class _AcopBlockEditorScreenState extends State<_AcopBlockEditorScreen> {
  final workspace = <_AcopWorkspaceBlock>[];
  int blockSerial = 0;
  bool codeCopied = false;
  bool allowPop = false;
  int compactSection = 1;
  _AcopBlockCategory selectedCategory = _AcopBlockCategory.event;
  late final String initialGeneratedCode;

  @override
  void initState() {
    super.initState();
    _addStarterBlocks();
    initialGeneratedCode = generatedCode;
  }

  bool get hasUnsavedChanges =>
      generatedCode.trim() != initialGeneratedCode.trim();

  String get generatedCode {
    final parts = workspace
        .map((block) => block.buildCode().trimRight())
        .where((code) => code.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '// Add blocks to generate JavaScript.';
    return '${parts.join('\n\n')}\n';
  }

  List<String> get requiredPermissions {
    return workspace
        .expand((block) => block.template.permissions)
        .toSet()
        .toList()
      ..sort();
  }

  void _addStarterBlocks() {
    final current = widget.initialCode.trim();
    for (final imported in _importAcopBlocks(current)) {
      workspace.add(_materializeImportedBlock(imported));
    }
  }

  _AcopWorkspaceBlock _materializeImportedBlock(_AcopImportedBlock imported) {
    final template = _templateById(imported.templateId);
    return _AcopWorkspaceBlock(
      id: 'block_${++blockSerial}',
      template: template,
      values: {
        for (final field in template.fields)
          field.key: imported.values[field.key] ?? field.defaultValue,
      },
    );
  }

  void addBlock(_AcopBlockTemplate template, {Map<String, String>? values}) {
    setState(() {
      workspace.add(
        _AcopWorkspaceBlock(
          id: 'block_${++blockSerial}',
          template: template,
          values: {
            for (final field in template.fields)
              field.key: values?[field.key] ?? field.defaultValue,
          },
        ),
      );
      codeCopied = false;
    });
  }

  void importCurrentCode() {
    setState(() {
      workspace
        ..clear()
        ..addAll(
          _importAcopBlocks(generatedCode).map(_materializeImportedBlock),
        );
      codeCopied = false;
    });
  }

  void removeBlock(_AcopWorkspaceBlock block) {
    setState(() {
      workspace.remove(block);
      codeCopied = false;
    });
  }

  void duplicateBlock(_AcopWorkspaceBlock block) {
    addBlock(block.template, values: Map<String, String>.from(block.values));
  }

  void moveBlock(int index, int delta) {
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= workspace.length) return;
    setState(() {
      final block = workspace.removeAt(index);
      workspace.insert(nextIndex, block);
      codeCopied = false;
    });
  }

  void updateField(_AcopWorkspaceBlock block, String key, String value) {
    setState(() {
      block.values[key] = value;
      codeCopied = false;
    });
  }

  void toggleBlockCollapsed(_AcopWorkspaceBlock block) {
    setState(() => block.collapsed = !block.collapsed);
  }

  Future<void> copyCode() async {
    await Clipboard.setData(ClipboardData(text: generatedCode));
    if (!mounted) return;
    setState(() => codeCopied = true);
    CsacToastMessenger.maybeOf(
      context,
    )?.showToast(CsacToast(content: Text(context.strings.text('Copied.'))));
  }

  void applyCode() {
    allowPop = true;
    Navigator.of(context).pop(_AcopBlockDraft(code: generatedCode));
  }

  Future<void> handleClose() async {
    if (!hasUnsavedChanges) {
      allowPop = true;
      Navigator.of(context).pop();
      return;
    }
    final action = await _showAcopUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (action) {
      case _AcopUnsavedExitAction.save:
        applyCode();
        break;
      case _AcopUnsavedExitAction.discard:
        allowPop = true;
        Navigator.of(context).pop();
        break;
      case _AcopUnsavedExitAction.cancel:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final palette = _AcopBlockPalette(
      selectedCategory: selectedCategory,
      onCategoryChanged: (value) => setState(() => selectedCategory = value),
      onAdd: addBlock,
    );
    final workspacePanel = _AcopWorkspacePanel(
      workspace: workspace,
      onUpdateField: updateField,
      onDuplicate: duplicateBlock,
      onRemove: removeBlock,
      onMove: moveBlock,
      onToggleCollapsed: toggleBlockCollapsed,
    );
    final codePanel = _AcopGeneratedCodePanel(
      code: generatedCode,
      permissions: requiredPermissions,
      copied: codeCopied,
      onCopy: copyCode,
      onImport: importCurrentCode,
      onApply: applyCode,
    );
    final compactPanels = <Widget>[
      palette,
      workspacePanel,
      if (widget.showGeneratedCode) codePanel,
    ];
    if (compactSection >= compactPanels.length) {
      compactSection = compactPanels.length - 1;
    }
    return PopScope(
      canPop: allowPop || !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(handleClose());
      },
      child: CsacPageScaffold(
        backgroundColor: colors.systemBackground,
        appBar: CsacNavigationBar(
          title: Text(strings.text('JavaScript block editor')),
          actions: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => openAcopScriptGuide(context),
              child: const Icon(CupertinoIcons.question_circle),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: copyCode,
              child: Icon(
                codeCopied
                    ? CupertinoIcons.check_mark
                    : CupertinoIcons.doc_on_doc,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: applyCode,
              child: const Icon(CupertinoIcons.check_mark_circled),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;
              if (isWide) {
                return Row(
                  children: [
                    SizedBox(width: 330, child: palette),
                    Container(width: 0.5, color: colors.separator),
                    Expanded(flex: 3, child: workspacePanel),
                    if (widget.showGeneratedCode) ...[
                      Container(width: 0.5, color: colors.separator),
                      Expanded(flex: 2, child: codePanel),
                    ],
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: compactSection,
                        children: {
                          0: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(strings.text('Blocks')),
                          ),
                          1: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(strings.text('Workspace')),
                          ),
                          if (widget.showGeneratedCode)
                            2: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(strings.text('Generated code')),
                            ),
                        },
                        onValueChanged: (value) {
                          if (value != null) {
                            setState(() => compactSection = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: compactPanels[compactSection]),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AcopBlockPalette extends StatelessWidget {
  const _AcopBlockPalette({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onAdd,
  });

  final _AcopBlockCategory selectedCategory;
  final ValueChanged<_AcopBlockCategory> onCategoryChanged;
  final void Function(_AcopBlockTemplate template) onAdd;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final templates = _acopBlockTemplates
        .where((template) => template.category == selectedCategory)
        .toList();
    return CsacListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        Text(
          strings.text('Block palette'),
          style: TextStyle(
            color: colors.label,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          strings.text(
            'Blocks are based on the ACOP JavaScript guide and generate sandbox-safe bot code.',
          ),
          style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in _AcopBlockCategory.values)
              _AcopCategoryChip(
                label: _acopBlockCategoryLabel(context, category),
                selected: category == selectedCategory,
                onTap: () => onCategoryChanged(category),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (final template in templates) ...[
          _AcopPaletteBlock(template: template, onTap: () => onAdd(template)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AcopCategoryChip extends StatelessWidget {
  const _AcopCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: selected ? colors.primaryColor : colors.fill,
      borderRadius: BorderRadius.circular(999),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? CupertinoColors.white : colors.label,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AcopPaletteBlock extends StatelessWidget {
  const _AcopPaletteBlock({required this.template, required this.onTap});

  final _AcopBlockTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = template.color.computeLuminance() > 0.45
        ? CupertinoColors.black
        : CupertinoColors.white;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(14),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: template.color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(template.icon, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.text(template.titleKey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w800),
                  ),
                  if (template.descriptionKey.isNotEmpty)
                    Text(
                      context.strings.text(template.descriptionKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.plus_circle, color: fg),
          ],
        ),
      ),
    );
  }
}

class _AcopWorkspacePanel extends StatelessWidget {
  const _AcopWorkspacePanel({
    required this.workspace,
    required this.onUpdateField,
    required this.onDuplicate,
    required this.onRemove,
    required this.onMove,
    required this.onToggleCollapsed,
  });

  final List<_AcopWorkspaceBlock> workspace;
  final void Function(_AcopWorkspaceBlock block, String key, String value)
  onUpdateField;
  final void Function(_AcopWorkspaceBlock block) onDuplicate;
  final void Function(_AcopWorkspaceBlock block) onRemove;
  final void Function(int index, int delta) onMove;
  final void Function(_AcopWorkspaceBlock block) onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    if (workspace.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            context.strings.text('Add blocks from the palette to start.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: CsacColors.of(context).secondaryLabel),
          ),
        ),
      );
    }
    return CsacListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        for (final entry in workspace.indexed) ...[
          _AcopWorkspaceBlockCard(
            index: entry.$1,
            block: entry.$2,
            isFirst: entry.$1 == 0,
            isLast: entry.$1 == workspace.length - 1,
            onUpdateField: onUpdateField,
            onDuplicate: () => onDuplicate(entry.$2),
            onRemove: () => onRemove(entry.$2),
            onMoveUp: () => onMove(entry.$1, -1),
            onMoveDown: () => onMove(entry.$1, 1),
            onToggleCollapsed: () => onToggleCollapsed(entry.$2),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AcopWorkspaceBlockCard extends StatelessWidget {
  const _AcopWorkspaceBlockCard({
    required this.index,
    required this.block,
    required this.isFirst,
    required this.isLast,
    required this.onUpdateField,
    required this.onDuplicate,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleCollapsed,
  });

  final int index;
  final _AcopWorkspaceBlock block;
  final bool isFirst;
  final bool isLast;
  final void Function(_AcopWorkspaceBlock block, String key, String value)
  onUpdateField;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final accent = block.template.color;
    return CsacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: colors.isDark ? 0.20 : 0.12),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(block.template.icon, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.strings.text(block.template.titleKey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.label,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _AcopTinyIconButton(
                  icon: block.collapsed
                      ? CupertinoIcons.chevron_down
                      : CupertinoIcons.chevron_up,
                  onPressed: onToggleCollapsed,
                ),
                _AcopTinyIconButton(
                  icon: CupertinoIcons.arrow_up,
                  onPressed: isFirst ? null : onMoveUp,
                ),
                _AcopTinyIconButton(
                  icon: CupertinoIcons.arrow_down,
                  onPressed: isLast ? null : onMoveDown,
                ),
                _AcopTinyIconButton(
                  icon: CupertinoIcons.doc_on_doc,
                  onPressed: onDuplicate,
                ),
                _AcopTinyIconButton(
                  icon: CupertinoIcons.delete,
                  destructive: true,
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
          if (!block.collapsed)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final field in block.template.fields) ...[
                    _AcopBlockFieldEditor(
                      field: field,
                      value: block.values[field.key] ?? field.defaultValue,
                      onChanged: (value) =>
                          onUpdateField(block, field.key, value),
                    ),
                    if (field != block.template.fields.last)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AcopTinyIconButton extends StatelessWidget {
  const _AcopTinyIconButton({
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.all(5),
      onPressed: onPressed,
      child: Icon(
        icon,
        size: 18,
        color: onPressed == null
            ? colors.tertiaryLabel
            : destructive
            ? colors.destructive
            : colors.secondaryLabel,
      ),
    );
  }
}

class _AcopBlockFieldEditor extends StatefulWidget {
  const _AcopBlockFieldEditor({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final _AcopBlockFieldTemplate field;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_AcopBlockFieldEditor> createState() => _AcopBlockFieldEditorState();
}

class _AcopBlockFieldEditorState extends State<_AcopBlockFieldEditor> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _AcopBlockFieldEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != controller.text && widget.value != oldWidget.value) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> insertVariable() async {
    final selected = await showCupertinoOptionSheet<String>(
      context: context,
      title: context.strings.text('Insert variable'),
      options: [
        for (final item in _acopVariableSuggestions)
          CupertinoOption(
            value: item.expression,
            title: context.strings.text(item.labelKey),
            subtitle: item.expression,
          ),
      ],
    );
    if (selected == null) return;
    final current = controller.text;
    final separator = current.isEmpty || current.endsWith(' ') ? '' : ' ';
    final next = '$current$separator$selected';
    controller.text = next;
    controller.selection = TextSelection.collapsed(offset: next.length);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final strings = context.strings;
    if (field.kind == _AcopBlockFieldKind.select) {
      final selected = field.options.contains(widget.value)
          ? widget.value
          : field.defaultValue;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.text(field.labelKey),
            style: TextStyle(
              color: CsacColors.of(context).secondaryLabel,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          CupertinoSlidingSegmentedControl<String>(
            groupValue: selected,
            children: {
              for (final option in field.options)
                option: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(strings.text(option)),
                ),
            },
            onValueChanged: (value) {
              if (value != null) widget.onChanged(value);
            },
          ),
        ],
      );
    }
    return CsacTextField(
      controller: controller,
      keyboardType: field.kind == _AcopBlockFieldKind.number
          ? TextInputType.number
          : field.kind == _AcopBlockFieldKind.multiline
          ? TextInputType.multiline
          : TextInputType.text,
      maxLines: field.kind == _AcopBlockFieldKind.multiline ? 6 : 1,
      minLines: field.kind == _AcopBlockFieldKind.multiline ? 3 : null,
      style: field.kind == _AcopBlockFieldKind.multiline
          ? const TextStyle(fontFamily: 'monospace', fontSize: 13)
          : null,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: strings.text(field.labelKey),
        border: const OutlineInputBorder(),
        suffixIcon: CupertinoButton(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          onPressed: insertVariable,
          child: const Icon(
            CupertinoIcons.chevron_left_slash_chevron_right,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _AcopGeneratedCodePanel extends StatelessWidget {
  const _AcopGeneratedCodePanel({
    required this.code,
    required this.permissions,
    required this.copied,
    required this.onCopy,
    required this.onImport,
    required this.onApply,
  });

  final String code;
  final List<String> permissions;
  final bool copied;
  final Future<void> Function() onCopy;
  final VoidCallback onImport;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CsacCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.text('Required permissions'),
                    style: TextStyle(
                      color: colors.label,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (permissions.isEmpty)
                    Text(
                      strings.text('No extra permissions'),
                      style: TextStyle(color: colors.secondaryLabel),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final permission in permissions)
                          Chip(label: Text(strings.text(permission))),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: colors.fill,
                onPressed: onImport,
                child: Text(strings.text('Import code as blocks')),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: colors.fill,
                onPressed: () => unawaited(onCopy()),
                child: Text(
                  strings.text(copied ? 'Copied.' : 'Copy generated code'),
                ),
              ),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onPressed: onApply,
                child: Text(strings.text('Apply code')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: CupertinoScrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      color: Color(0xFFC9D1D9),
                      fontFamily: 'monospace',
                      fontFamilyFallback: ['Menlo', 'Consolas', 'Courier New'],
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<_AcopUnsavedExitAction?> _showAcopUnsavedChangesDialog(
  BuildContext context,
) {
  return showCupertinoCsacDialog<_AcopUnsavedExitAction>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(context.strings.text('Save changes?')),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          context.strings.text(
            'You have unsaved script changes. Save before leaving?',
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_AcopUnsavedExitAction.cancel),
          child: Text(context.strings.text('Cancel')),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () =>
              Navigator.of(dialogContext).pop(_AcopUnsavedExitAction.discard),
          child: Text(context.strings.text('Discard')),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () =>
              Navigator.of(dialogContext).pop(_AcopUnsavedExitAction.save),
          child: Text(context.strings.text('Save')),
        ),
      ],
    ),
  );
}

Future<void> openAcopScriptGuide(BuildContext context) {
  return Navigator.of(
    context,
  ).push(CsacPageRoute<void>(builder: (_) => const _AcopScriptGuidePage()));
}

class _AcopScriptGuidePage extends StatefulWidget {
  const _AcopScriptGuidePage();

  @override
  State<_AcopScriptGuidePage> createState() => _AcopScriptGuidePageState();
}

class _AcopScriptGuidePageState extends State<_AcopScriptGuidePage> {
  late final Future<String> guide = rootBundle.loadString(
    'docs/BOT_SCRIPT_JS_GUIDE.md',
  );

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CsacPageScaffold(
      backgroundColor: colors.systemBackground,
      appBar: CsacNavigationBar(
        title: Text(context.strings.text('JavaScript guide')),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: guide,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            final data = snapshot.data;
            if (snapshot.hasError || data == null) {
              return Center(
                child: Text(context.strings.text('Unable to load document.')),
              );
            }
            return Markdown(
              data: data,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              selectable: true,
            );
          },
        ),
      ),
    );
  }
}

String _acopTimestampLabel(int timestamp) {
  if (timestamp <= 0) return '-';
  final millis = timestamp > 1000000000000 ? timestamp : timestamp * 1000;
  return formatLocalDateTime(DateTime.fromMillisecondsSinceEpoch(millis));
}

String _acopBlockCategoryLabel(
  BuildContext context,
  _AcopBlockCategory category,
) {
  final strings = context.strings;
  return switch (category) {
    _AcopBlockCategory.event => strings.text('Events'),
    _AcopBlockCategory.control => strings.text('Control'),
    _AcopBlockCategory.message => strings.text('Messages'),
    _AcopBlockCategory.data => strings.text('Data'),
    _AcopBlockCategory.platform => strings.text('Platform APIs'),
    _AcopBlockCategory.utility => strings.text('Utilities'),
  };
}

_AcopBlockTemplate _templateById(String id) {
  return _acopBlockTemplates.firstWhere((template) => template.id == id);
}

List<_AcopImportedBlock> _importAcopBlocks(String code) {
  final source = code.trim();
  if (source.isEmpty || source == _defaultAcopScriptContent().trim()) {
    return const [
      _AcopImportedBlock('command.reply', {}),
      _AcopImportedBlock('group.keyword.reply', {}),
    ];
  }
  final blocks = <_AcopImportedBlock>[];
  final commandPattern = RegExp(
    r'''bot\.command\((['"])(.*?)\1(?:,\s*\{\s*scope:\s*(['"])(.*?)\3\s*\})?,\s*async\s*\(ctx\)\s*=>\s*\{\s*await\s+ctx\.reply\((['"])(.*?)\5\)\s*\}\)''',
    dotAll: true,
  );
  for (final match in commandPattern.allMatches(source)) {
    blocks.add(
      _AcopImportedBlock('command.reply', {
        'command': match.group(2) ?? '/ping',
        'scope': match.group(4) ?? 'all',
        'reply': match.group(6) ?? 'pong',
      }),
    );
  }
  final groupKeywordPattern = RegExp(
    r'''bot\.on\('group\.message',\s*async\s*\(ctx\)\s*=>\s*\{\s*if\s*\(ctx\.text\.includes\((['"])(.*?)\1\)\)\s*\{\s*await\s+ctx\.reply\((.*?)\)\s*\}\s*\}\)''',
    dotAll: true,
  );
  for (final match in groupKeywordPattern.allMatches(source)) {
    blocks.add(
      _AcopImportedBlock('group.keyword.reply', {
        'keyword': match.group(2) ?? '',
        'replyExpression': (match.group(3) ?? '').trim(),
      }),
    );
  }
  final privateKeywordPattern = RegExp(
    r'''bot\.on\('private\.message',\s*async\s*\(ctx\)\s*=>\s*\{\s*if\s*\(ctx\.text\.trim\(\)\s*===\s*(['"])(.*?)\1\)\s*\{\s*await\s+ctx\.reply\((['"])(.*?)\3\)\s*\}\s*\}\)''',
    dotAll: true,
  );
  for (final match in privateKeywordPattern.allMatches(source)) {
    blocks.add(
      _AcopImportedBlock('private.message.reply', {
        'keyword': match.group(2) ?? '',
        'reply': match.group(4) ?? '',
      }),
    );
  }
  if (source.contains('ctx.requireGroupAdmin()')) {
    blocks.add(const _AcopImportedBlock('require.group.admin', {}));
  }
  final logPattern = RegExp(
    r'''logger\.(info|warn|error)\((['"])(.*?)\2\)''',
    dotAll: true,
  );
  for (final match in logPattern.allMatches(source)) {
    blocks.add(
      _AcopImportedBlock('logger', {
        'level': match.group(1) ?? 'info',
        'message': match.group(3) ?? '',
      }),
    );
  }
  if (blocks.isEmpty) {
    return [
      _AcopImportedBlock('raw.code', {'code': source}),
    ];
  }
  return blocks;
}

String _f(Map<String, String> fields, String key) => fields[key] ?? '';

String _jsString(String value) => jsonEncode(value);

String _jsIdentifier(String value, String fallback) {
  final normalized = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_$]'), '_');
  if (RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(normalized)) {
    return normalized;
  }
  return fallback;
}

String _jsNumber(String value, String fallback) {
  final trimmed = value.trim();
  return num.tryParse(trimmed) == null ? fallback : trimmed;
}

String _jsExpression(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _indentJs(String code, [String indent = '  ']) {
  return code
      .trim()
      .split('\n')
      .map((line) => line.trim().isEmpty ? '' : '$indent$line')
      .join('\n');
}

const _acopVariableSuggestions = <_AcopVariableSuggestion>[
  _AcopVariableSuggestion('Message text variable', 'ctx.text'),
  _AcopVariableSuggestion('Sender UID variable', 'ctx.sender.uid'),
  _AcopVariableSuggestion('Sender nickname variable', 'ctx.sender.nickname'),
  _AcopVariableSuggestion('Group ID variable', 'ctx.group.id'),
  _AcopVariableSuggestion('Matched regex group variable', 'match[1]'),
  _AcopVariableSuggestion('Current time variable', 'Date.now()'),
];

const _acopEventColor = Color(0xFF4F46E5);
const _acopControlColor = Color(0xFFEA580C);
const _acopMessageColor = Color(0xFF0F766E);
const _acopDataColor = Color(0xFF2563EB);
const _acopPlatformColor = Color(0xFF9333EA);
const _acopUtilityColor = Color(0xFF475569);

final _acopBlockTemplates = <_AcopBlockTemplate>[
  _AcopBlockTemplate(
    id: 'command.reply',
    titleKey: 'Command reply',
    descriptionKey: 'bot.command from the JavaScript guide.',
    category: _AcopBlockCategory.event,
    color: _acopEventColor,
    icon: CupertinoIcons.chevron_left_slash_chevron_right,
    fields: const [
      _AcopBlockFieldTemplate(
        key: 'command',
        labelKey: 'Command',
        kind: _AcopBlockFieldKind.text,
        defaultValue: '/ping',
      ),
      _AcopBlockFieldTemplate(
        key: 'scope',
        labelKey: 'Scope',
        kind: _AcopBlockFieldKind.select,
        defaultValue: 'all',
        options: ['all', 'private', 'group'],
      ),
      _AcopBlockFieldTemplate(
        key: 'reply',
        labelKey: 'Reply text',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'pong',
      ),
    ],
    builder: (fields) {
      final command = _jsString(
        _f(fields, 'command').trim().isEmpty
            ? '/ping'
            : _f(fields, 'command').trim(),
      );
      final scope = _f(fields, 'scope').trim();
      final options = scope == 'all' ? '' : ', { scope: ${_jsString(scope)} }';
      return '''
bot.command($command$options, async (ctx) => {
  await ctx.reply(${_jsString(_f(fields, 'reply'))})
})''';
    },
  ),
  _AcopBlockTemplate(
    id: 'regex.command.reply',
    titleKey: 'Regex command reply',
    descriptionKey: 'Matches a regular expression command.',
    category: _AcopBlockCategory.event,
    color: _acopEventColor,
    icon: CupertinoIcons.search,
    fields: const [
      _AcopBlockFieldTemplate(
        key: 'pattern',
        labelKey: 'Regex pattern',
        kind: _AcopBlockFieldKind.text,
        defaultValue: r'^/echo\s+(.+)$',
      ),
      _AcopBlockFieldTemplate(
        key: 'flags',
        labelKey: 'Regex flags',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'i',
      ),
      _AcopBlockFieldTemplate(
        key: 'replyExpression',
        labelKey: 'Reply expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'match[1]',
      ),
    ],
    builder: (fields) {
      final pattern = _f(fields, 'pattern').replaceAll('/', r'\/');
      final flags = _f(fields, 'flags').replaceAll(RegExp(r'[^a-z]'), '');
      return '''
bot.command(/$pattern/$flags, async (ctx, match) => {
  await ctx.reply(${_jsExpression(_f(fields, 'replyExpression'), 'match[1]')})
})''';
    },
  ),
  _AcopBlockTemplate(
    id: 'private.message.reply',
    titleKey: 'Private keyword reply',
    descriptionKey: 'bot.on private.message keyword handler.',
    category: _AcopBlockCategory.event,
    color: _acopEventColor,
    icon: CupertinoIcons.person,
    fields: const [
      _AcopBlockFieldTemplate(
        key: 'keyword',
        labelKey: 'Keyword',
        kind: _AcopBlockFieldKind.text,
        defaultValue: '测试bot',
      ),
      _AcopBlockFieldTemplate(
        key: 'reply',
        labelKey: 'Reply text',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'bot正在运行',
      ),
    ],
    builder: (fields) =>
        '''
bot.on('private.message', async (ctx) => {
  if (ctx.text.trim() === ${_jsString(_f(fields, 'keyword'))}) {
    await ctx.reply(${_jsString(_f(fields, 'reply'))})
  }
})''',
  ),
  _AcopBlockTemplate(
    id: 'group.keyword.reply',
    titleKey: 'Group keyword reply',
    descriptionKey: 'bot.on group.message keyword handler.',
    category: _AcopBlockCategory.event,
    color: _acopEventColor,
    icon: CupertinoIcons.group,
    fields: const [
      _AcopBlockFieldTemplate(
        key: 'keyword',
        labelKey: 'Keyword',
        kind: _AcopBlockFieldKind.text,
        defaultValue: '你好',
      ),
      _AcopBlockFieldTemplate(
        key: 'replyExpression',
        labelKey: 'Reply expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: r'`你好，${ctx.sender.nickname || ctx.sender.uid}`',
      ),
    ],
    builder: (fields) =>
        '''
bot.on('group.message', async (ctx) => {
  if (ctx.text.includes(${_jsString(_f(fields, 'keyword'))})) {
    await ctx.reply(${_jsExpression(_f(fields, 'replyExpression'), _jsString('你好'))})
  }
})''',
  ),
  _AcopBlockTemplate(
    id: 'member.join.welcome',
    titleKey: 'Group join welcome',
    descriptionKey: 'Welcomes new group members.',
    category: _AcopBlockCategory.event,
    color: _acopEventColor,
    icon: CupertinoIcons.person_add,
    permissions: const ['group', 'user'],
    fields: const [
      _AcopBlockFieldTemplate(
        key: 'messageExpression',
        labelKey: 'Message expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: r'`欢迎 ${name} 加入群聊`',
      ),
    ],
    builder: (fields) =>
        '''
bot.on('group.member.join', async (ctx) => {
  const user = await csac.user.get(ctx.member.uid)
  const name = user.success ? user.nickname : `UID \${ctx.member.uid}`
  await csac.group.sendMessage(ctx.group.id, ${_jsExpression(_f(fields, 'messageExpression'), r'`欢迎 ${name} 加入群聊`')})
})''',
  ),
  _AcopBlockTemplate(
    id: 'schedule.log',
    titleKey: 'Scheduled task',
    descriptionKey: 'bot.schedule cron task.',
    category: _AcopBlockCategory.event,
    color: _acopEventColor,
    icon: CupertinoIcons.clock,
    fields: const [
      _AcopBlockFieldTemplate(
        key: 'name',
        labelKey: 'Task name',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'daily-log',
      ),
      _AcopBlockFieldTemplate(
        key: 'cron',
        labelKey: 'Cron expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: '0 9 * * *',
      ),
      _AcopBlockFieldTemplate(
        key: 'body',
        labelKey: 'JavaScript body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: "logger.info('daily job triggered')",
      ),
    ],
    builder: (fields) =>
        '''
bot.schedule(${_jsString(_f(fields, 'name'))}, ${_jsString(_f(fields, 'cron'))}, async (ctx) => {
${_indentJs(_f(fields, 'body'))}
})''',
  ),
  _block(
    'if.text.includes',
    'If message contains',
    'Creates an if block using ctx.text.includes.',
    _AcopBlockCategory.control,
    _acopControlColor,
    CupertinoIcons.text_bubble,
    const [
      _AcopBlockFieldTemplate(
        key: 'keyword',
        labelKey: 'Keyword',
        kind: _AcopBlockFieldKind.text,
        defaultValue: '你好',
      ),
      _AcopBlockFieldTemplate(
        key: 'body',
        labelKey: 'JavaScript body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: "await ctx.reply('你好')",
      ),
    ],
    (fields) =>
        '''
if (ctx.text.includes(${_jsString(_f(fields, 'keyword'))})) {
${_indentJs(_f(fields, 'body'))}
}''',
  ),
  _block(
    'if.expression',
    'If expression',
    'Generic if block with a JavaScript condition.',
    _AcopBlockCategory.control,
    _acopControlColor,
    CupertinoIcons.slider_horizontal_3,
    const [
      _AcopBlockFieldTemplate(
        key: 'condition',
        labelKey: 'Condition expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'ctx.text.length > 0',
      ),
      _AcopBlockFieldTemplate(
        key: 'body',
        labelKey: 'JavaScript body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: "await ctx.reply('ok')",
      ),
    ],
    (fields) =>
        '''
if (${_jsExpression(_f(fields, 'condition'), 'true')}) {
${_indentJs(_f(fields, 'body'))}
}''',
  ),
  _block(
    'else.if',
    'If / else',
    'Adds an else branch.',
    _AcopBlockCategory.control,
    _acopControlColor,
    CupertinoIcons.alt,
    const [
      _AcopBlockFieldTemplate(
        key: 'condition',
        labelKey: 'Condition expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'ctx.text.includes("help")',
      ),
      _AcopBlockFieldTemplate(
        key: 'ifBody',
        labelKey: 'If body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: "await ctx.reply('help')",
      ),
      _AcopBlockFieldTemplate(
        key: 'elseBody',
        labelKey: 'Else body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: "await ctx.reply('no match')",
      ),
    ],
    (fields) =>
        '''
if (${_jsExpression(_f(fields, 'condition'), 'true')}) {
${_indentJs(_f(fields, 'ifBody'))}
} else {
${_indentJs(_f(fields, 'elseBody'))}
}''',
  ),
  _block(
    'loop.for',
    'For loop',
    'Classic counted loop.',
    _AcopBlockCategory.control,
    _acopControlColor,
    CupertinoIcons.repeat,
    const [
      _AcopBlockFieldTemplate(
        key: 'index',
        labelKey: 'Index variable',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'i',
      ),
      _AcopBlockFieldTemplate(
        key: 'start',
        labelKey: 'Start',
        kind: _AcopBlockFieldKind.number,
        defaultValue: '0',
      ),
      _AcopBlockFieldTemplate(
        key: 'end',
        labelKey: 'End',
        kind: _AcopBlockFieldKind.number,
        defaultValue: '10',
      ),
      _AcopBlockFieldTemplate(
        key: 'step',
        labelKey: 'Step',
        kind: _AcopBlockFieldKind.number,
        defaultValue: '1',
      ),
      _AcopBlockFieldTemplate(
        key: 'body',
        labelKey: 'JavaScript body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: 'logger.info(String(i))',
      ),
    ],
    (fields) {
      final index = _jsIdentifier(_f(fields, 'index'), 'i');
      return '''
for (let $index = ${_jsNumber(_f(fields, 'start'), '0')}; $index < ${_jsNumber(_f(fields, 'end'), '10')}; $index += ${_jsNumber(_f(fields, 'step'), '1')}) {
${_indentJs(_f(fields, 'body'))}
}''';
    },
  ),
  _block(
    'loop.for.of',
    'For each item',
    'Iterates an array or list.',
    _AcopBlockCategory.control,
    _acopControlColor,
    CupertinoIcons.list_bullet,
    const [
      _AcopBlockFieldTemplate(
        key: 'item',
        labelKey: 'Item variable',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'item',
      ),
      _AcopBlockFieldTemplate(
        key: 'items',
        labelKey: 'Items expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: '[1, 2, 3]',
      ),
      _AcopBlockFieldTemplate(
        key: 'body',
        labelKey: 'JavaScript body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: 'logger.info(String(item))',
      ),
    ],
    (fields) {
      final item = _jsIdentifier(_f(fields, 'item'), 'item');
      return '''
for (const $item of ${_jsExpression(_f(fields, 'items'), '[]')}) {
${_indentJs(_f(fields, 'body'))}
}''';
    },
  ),
  _block(
    'loop.while',
    'While loop',
    'Repeats while a condition is true.',
    _AcopBlockCategory.control,
    _acopControlColor,
    CupertinoIcons.arrow_2_circlepath,
    const [
      _AcopBlockFieldTemplate(
        key: 'condition',
        labelKey: 'Condition expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'true',
      ),
      _AcopBlockFieldTemplate(
        key: 'body',
        labelKey: 'JavaScript body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: 'break',
      ),
    ],
    (fields) =>
        '''
while (${_jsExpression(_f(fields, 'condition'), 'true')}) {
${_indentJs(_f(fields, 'body'))}
}''',
  ),
  _block(
    'loop.repeat',
    'Repeat N times',
    'Scratch-like repeat loop.',
    _AcopBlockCategory.control,
    _acopControlColor,
    CupertinoIcons.repeat,
    const [
      _AcopBlockFieldTemplate(
        key: 'times',
        labelKey: 'Times',
        kind: _AcopBlockFieldKind.number,
        defaultValue: '3',
      ),
      _AcopBlockFieldTemplate(
        key: 'body',
        labelKey: 'JavaScript body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: "await ctx.reply('repeat')",
      ),
    ],
    (fields) =>
        '''
for (let i = 0; i < ${_jsNumber(_f(fields, 'times'), '3')}; i += 1) {
${_indentJs(_f(fields, 'body'))}
}''',
  ),
  _block(
    'try.catch',
    'Try / catch',
    'Wraps code with error handling.',
    _AcopBlockCategory.control,
    _acopControlColor,
    CupertinoIcons.exclamationmark_triangle,
    const [
      _AcopBlockFieldTemplate(
        key: 'tryBody',
        labelKey: 'Try body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: "await ctx.reply('ok')",
      ),
      _AcopBlockFieldTemplate(
        key: 'catchBody',
        labelKey: 'Catch body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: 'logger.error(error)',
      ),
    ],
    (fields) =>
        '''
try {
${_indentJs(_f(fields, 'tryBody'))}
} catch (error) {
${_indentJs(_f(fields, 'catchBody'))}
}''',
  ),
  _block(
    'return.statement',
    'Return',
    'Ends the current function or handler.',
    _AcopBlockCategory.control,
    _acopControlColor,
    CupertinoIcons.return_icon,
    const [
      _AcopBlockFieldTemplate(
        key: 'expression',
        labelKey: 'Return expression',
        kind: _AcopBlockFieldKind.text,
      ),
    ],
    (fields) {
      final expression = _f(fields, 'expression').trim();
      return expression.isEmpty
          ? 'return'
          : 'return ${_jsExpression(expression, 'null')}';
    },
  ),
  _block(
    'function.declare',
    'Function',
    'Declares a reusable JavaScript function.',
    _AcopBlockCategory.utility,
    _acopUtilityColor,
    CupertinoIcons.chevron_left_slash_chevron_right,
    const [
      _AcopBlockFieldTemplate(
        key: 'name',
        labelKey: 'Function name',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'handler',
      ),
      _AcopBlockFieldTemplate(
        key: 'params',
        labelKey: 'Parameters',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'ctx',
      ),
      _AcopBlockFieldTemplate(
        key: 'body',
        labelKey: 'JavaScript body',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: 'return true',
      ),
    ],
    (fields) =>
        '''
function ${_jsIdentifier(_f(fields, 'name'), 'handler')}(${_f(fields, 'params').trim().isEmpty ? 'ctx' : _f(fields, 'params').trim()}) {
${_indentJs(_f(fields, 'body'))}
}''',
  ),
  _block(
    'delay',
    'Delay',
    'Waits for a number of milliseconds.',
    _AcopBlockCategory.utility,
    _acopUtilityColor,
    CupertinoIcons.timer,
    const [
      _AcopBlockFieldTemplate(
        key: 'ms',
        labelKey: 'Milliseconds',
        kind: _AcopBlockFieldKind.number,
        defaultValue: '1000',
      ),
    ],
    (fields) =>
        'await new Promise((resolve) => setTimeout(resolve, ${_jsNumber(_f(fields, 'ms'), '1000')}))',
  ),
  _block(
    'require.group.admin',
    'Require group admin',
    'Stops when the bot lacks group admin permission.',
    _AcopBlockCategory.control,
    _acopControlColor,
    CupertinoIcons.shield,
    const [],
    (_) => 'if (!(await ctx.requireGroupAdmin())) return',
  ),
  _block(
    'reply.text',
    'Reply current message',
    'ctx.reply text.',
    _AcopBlockCategory.message,
    _acopMessageColor,
    CupertinoIcons.reply,
    const [
      _AcopBlockFieldTemplate(
        key: 'text',
        labelKey: 'Reply text',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'hello',
      ),
    ],
    (fields) => 'await ctx.reply(${_jsString(_f(fields, 'text'))})',
  ),
  _block(
    'reply.expression',
    'Reply expression',
    'ctx.reply with a JavaScript expression.',
    _AcopBlockCategory.message,
    _acopMessageColor,
    CupertinoIcons.function,
    const [
      _AcopBlockFieldTemplate(
        key: 'expression',
        labelKey: 'Reply expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: r'`你好，${ctx.sender.nickname || ctx.sender.uid}`',
      ),
    ],
    (fields) =>
        'await ctx.reply(${_jsExpression(_f(fields, 'expression'), _jsString('hello'))})',
  ),
  _block(
    'send.group.message',
    'Send group message',
    'csac.group.sendMessage.',
    _AcopBlockCategory.message,
    _acopMessageColor,
    CupertinoIcons.chat_bubble_2,
    const [
      _AcopBlockFieldTemplate(
        key: 'groupId',
        labelKey: 'Group ID expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'ctx.group.id',
      ),
      _AcopBlockFieldTemplate(
        key: 'text',
        labelKey: 'Message text',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'hello',
      ),
    ],
    (fields) =>
        'await csac.group.sendMessage(${_jsExpression(_f(fields, 'groupId'), 'ctx.group.id')}, ${_jsString(_f(fields, 'text'))})',
  ),
  _block(
    'send.private.message',
    'Send private message',
    'csac.private.sendMessage.',
    _AcopBlockCategory.message,
    _acopMessageColor,
    CupertinoIcons.chat_bubble_text,
    const [
      _AcopBlockFieldTemplate(
        key: 'uid',
        labelKey: 'UID expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'ctx.sender.uid',
      ),
      _AcopBlockFieldTemplate(
        key: 'text',
        labelKey: 'Message text',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'hello',
      ),
    ],
    (fields) =>
        'await csac.private.sendMessage(${_jsExpression(_f(fields, 'uid'), 'ctx.sender.uid')}, ${_jsString(_f(fields, 'text'))})',
  ),
  _block(
    'notice.send',
    'Send notice',
    'ctx.notice requires notify permission.',
    _AcopBlockCategory.message,
    _acopMessageColor,
    CupertinoIcons.bell,
    const [
      _AcopBlockFieldTemplate(
        key: 'title',
        labelKey: 'Title',
        kind: _AcopBlockFieldKind.text,
        defaultValue: '处理完成',
      ),
      _AcopBlockFieldTemplate(
        key: 'content',
        labelKey: 'Content',
        kind: _AcopBlockFieldKind.text,
        defaultValue: '你的请求已处理完成',
      ),
    ],
    (fields) =>
        'await ctx.notice(${_jsString(_f(fields, 'title'))}, ${_jsString(_f(fields, 'content'))})',
    permissions: const ['notify'],
  ),
  _block(
    'storage.get',
    'Read storage',
    'csac.storage.get.',
    _AcopBlockCategory.data,
    _acopDataColor,
    CupertinoIcons.archivebox,
    const [
      _AcopBlockFieldTemplate(
        key: 'variable',
        labelKey: 'Variable name',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'count',
      ),
      _AcopBlockFieldTemplate(
        key: 'key',
        labelKey: 'Storage key',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'hello.count',
      ),
      _AcopBlockFieldTemplate(
        key: 'fallback',
        labelKey: 'Default value expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: '0',
      ),
    ],
    (fields) =>
        'const ${_jsIdentifier(_f(fields, 'variable'), 'value')} = await csac.storage.get(${_jsString(_f(fields, 'key'))}, ${_jsExpression(_f(fields, 'fallback'), '0')})',
    permissions: const ['storage'],
  ),
  _block(
    'storage.set',
    'Write storage',
    'csac.storage.set.',
    _AcopBlockCategory.data,
    _acopDataColor,
    CupertinoIcons.tray_arrow_down,
    const [
      _AcopBlockFieldTemplate(
        key: 'key',
        labelKey: 'Storage key',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'hello.count',
      ),
      _AcopBlockFieldTemplate(
        key: 'value',
        labelKey: 'Value expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: '1',
      ),
    ],
    (fields) =>
        'await csac.storage.set(${_jsString(_f(fields, 'key'))}, ${_jsExpression(_f(fields, 'value'), '1')})',
    permissions: const ['storage'],
  ),
  _block(
    'storage.increment',
    'Increment storage',
    'csac.storage.increment counter.',
    _AcopBlockCategory.data,
    _acopDataColor,
    CupertinoIcons.plus_slash_minus,
    const [
      _AcopBlockFieldTemplate(
        key: 'variable',
        labelKey: 'Variable name',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'count',
      ),
      _AcopBlockFieldTemplate(
        key: 'key',
        labelKey: 'Storage key expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: r'`counter:${ctx.sender.uid}`',
      ),
      _AcopBlockFieldTemplate(
        key: 'step',
        labelKey: 'Step',
        kind: _AcopBlockFieldKind.number,
        defaultValue: '1',
      ),
    ],
    (fields) =>
        'const ${_jsIdentifier(_f(fields, 'variable'), 'count')} = await csac.storage.increment(${_jsExpression(_f(fields, 'key'), _jsString('counter'))}, ${_jsNumber(_f(fields, 'step'), '1')})',
    permissions: const ['storage'],
  ),
  _block(
    'http.get',
    'HTTP GET',
    'csac.http.get requires http permission.',
    _AcopBlockCategory.platform,
    _acopPlatformColor,
    CupertinoIcons.globe,
    const [
      _AcopBlockFieldTemplate(
        key: 'variable',
        labelKey: 'Variable name',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'res',
      ),
      _AcopBlockFieldTemplate(
        key: 'url',
        labelKey: 'URL',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'https://api.example.com/status',
      ),
    ],
    (fields) =>
        'const ${_jsIdentifier(_f(fields, 'variable'), 'res')} = await csac.http.get(${_jsString(_f(fields, 'url'))})',
    permissions: const ['http'],
  ),
  _block(
    'user.get',
    'Get user info',
    'csac.user.get.',
    _AcopBlockCategory.platform,
    _acopPlatformColor,
    CupertinoIcons.person_crop_circle,
    const [
      _AcopBlockFieldTemplate(
        key: 'variable',
        labelKey: 'Variable name',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'user',
      ),
      _AcopBlockFieldTemplate(
        key: 'uid',
        labelKey: 'UID expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'ctx.sender.uid',
      ),
    ],
    (fields) =>
        'const ${_jsIdentifier(_f(fields, 'variable'), 'user')} = await csac.user.get(${_jsExpression(_f(fields, 'uid'), 'ctx.sender.uid')})',
    permissions: const ['user'],
  ),
  _block(
    'group.info',
    'Get group info',
    'csac.groupInfo.get.',
    _AcopBlockCategory.platform,
    _acopPlatformColor,
    CupertinoIcons.info_circle,
    const [
      _AcopBlockFieldTemplate(
        key: 'variable',
        labelKey: 'Variable name',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'group',
      ),
      _AcopBlockFieldTemplate(
        key: 'groupId',
        labelKey: 'Group ID expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'ctx.group.id',
      ),
    ],
    (fields) =>
        'const ${_jsIdentifier(_f(fields, 'variable'), 'group')} = await csac.groupInfo.get(${_jsExpression(_f(fields, 'groupId'), 'ctx.group.id')})',
    permissions: const ['group'],
  ),
  _block(
    'logger',
    'Write log',
    'logger.info, logger.warn or logger.error.',
    _AcopBlockCategory.utility,
    _acopUtilityColor,
    CupertinoIcons.doc_text,
    const [
      _AcopBlockFieldTemplate(
        key: 'level',
        labelKey: 'Log level',
        kind: _AcopBlockFieldKind.select,
        defaultValue: 'info',
        options: ['info', 'warn', 'error'],
      ),
      _AcopBlockFieldTemplate(
        key: 'message',
        labelKey: 'Message text',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'message',
      ),
    ],
    (fields) {
      final level = switch (_f(fields, 'level')) {
        'warn' => 'warn',
        'error' => 'error',
        _ => 'info',
      };
      return 'logger.$level(${_jsString(_f(fields, 'message'))})';
    },
  ),
  _block(
    'constant',
    'Constant',
    'Creates a const variable.',
    _AcopBlockCategory.utility,
    _acopUtilityColor,
    CupertinoIcons.cube_box,
    const [
      _AcopBlockFieldTemplate(
        key: 'name',
        labelKey: 'Variable name',
        kind: _AcopBlockFieldKind.text,
        defaultValue: 'VERSION',
      ),
      _AcopBlockFieldTemplate(
        key: 'value',
        labelKey: 'Value expression',
        kind: _AcopBlockFieldKind.text,
        defaultValue: "'1.0.0'",
      ),
    ],
    (fields) =>
        'const ${_jsIdentifier(_f(fields, 'name'), 'VALUE')} = ${_jsExpression(_f(fields, 'value'), "''")}',
  ),
  _block(
    'raw.code',
    'Raw JavaScript',
    'Keeps hand-written JavaScript in the generated output.',
    _AcopBlockCategory.utility,
    _acopUtilityColor,
    CupertinoIcons.chevron_left_slash_chevron_right,
    const [
      _AcopBlockFieldTemplate(
        key: 'code',
        labelKey: 'JavaScript code',
        kind: _AcopBlockFieldKind.multiline,
        defaultValue: "logger.info('hello')",
      ),
    ],
    (fields) => _f(fields, 'code'),
  ),
];

_AcopBlockTemplate _block(
  String id,
  String titleKey,
  String descriptionKey,
  _AcopBlockCategory category,
  Color color,
  IconData icon,
  List<_AcopBlockFieldTemplate> fields,
  String Function(Map<String, String> fields) builder, {
  List<String> permissions = const <String>[],
}) {
  return _AcopBlockTemplate(
    id: id,
    titleKey: titleKey,
    descriptionKey: descriptionKey,
    category: category,
    color: color,
    icon: icon,
    fields: fields,
    builder: builder,
    permissions: permissions,
  );
}
