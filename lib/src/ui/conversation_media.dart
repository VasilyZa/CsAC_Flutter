part of '../../main.dart';

class ConversationMediaScreen extends StatefulWidget {
  const ConversationMediaScreen({
    super.key,
    required this.state,
    required this.conversation,
    required this.onOpenMessage,
  });

  final CsacAppState state;
  final Conversation conversation;
  final ValueChanged<int> onOpenMessage;

  @override
  State<ConversationMediaScreen> createState() =>
      _ConversationMediaScreenState();
}

class _ConversationMediaScreenState extends State<ConversationMediaScreen> {
  final search = TextEditingController();
  ConversationMediaKind kind = ConversationMediaKind.all;
  List<ConversationMediaItem> items = const <ConversationMediaItem>[];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.loadConversationMedia(
        widget.conversation,
        kind: kind,
        query: search.text,
      );
      if (!mounted) {
        return;
      }
      setState(() => items = loaded);
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void setKind(ConversationMediaKind value) {
    setState(() => kind = value);
    load();
  }

  Future<void> showItemActions(ConversationMediaItem item) async {
    final strings = context.strings;
    final action = await _showAdaptiveActionSheet<String>(
      context,
      title: item.title.isEmpty
          ? mediaTypeLabel(context, item.kind)
          : item.title,
      actions: const [
        _AdaptiveSheetAction(
          value: 'open',
          label: 'Open',
          icon: CupertinoIcons.arrow_up_right_square,
        ),
        _AdaptiveSheetAction(
          value: 'chat',
          label: 'View in chat',
          icon: CupertinoIcons.bubble_left_bubble_right,
        ),
        _AdaptiveSheetAction(
          value: 'copy',
          label: 'Copy link',
          icon: CupertinoIcons.link,
        ),
        _AdaptiveSheetAction(
          value: 'download',
          label: 'Download',
          icon: CupertinoIcons.cloud_download,
        ),
      ],
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'open':
        if (item.kind == ConversationMediaKind.image) {
          showImagePreview(context, item.url);
        } else {
          await launchUrl(
            Uri.parse(item.url),
            mode: LaunchMode.externalApplication,
          );
        }
        break;
      case 'chat':
        widget.onOpenMessage(item.message.id);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: item.url));
        if (mounted) {
          _showCupertinoToast(context, strings.text('Link copied.'));
        }
        break;
      case 'download':
        await saveMediaItem(context, widget.state, item);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        border: null,
        backgroundColor: colors.navBarBackground,
        middle: Text(strings.text('Media drawer')),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: loading ? null : load,
          child: const Icon(CupertinoIcons.refresh, size: 20),
        ),
      ),
      child: SafeArea(
        child: _AdaptivePageFrame(
          maxWidth: 900,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    CupertinoSearchTextField(
                      controller: search,
                      placeholder: strings.text('Search media'),
                      onSubmitted: (_) => load(),
                      onChanged: (_) => load(),
                    ),
                    const SizedBox(height: 10),
                    CupertinoSlidingSegmentedControl<ConversationMediaKind>(
                      groupValue: kind,
                      children: {
                        for (final value in ConversationMediaKind.values)
                          value: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              mediaTypeLabel(context, value),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                      },
                      onValueChanged: (value) {
                        if (value != null) {
                          setKind(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : error != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: _InlineError(message: error!, onRetry: load),
                      )
                    : items.isEmpty
                    ? _EmptyPanel(message: strings.text('No media files.'))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.sizeOf(context).width > 780
                              ? 3
                              : MediaQuery.sizeOf(context).width > 520
                              ? 2
                              : 1,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.55,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _ConversationMediaTile(
                            item: item,
                            onTap: () => showItemActions(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationMediaTile extends StatelessWidget {
  const _ConversationMediaTile({required this.item, required this.onTap});

  final ConversationMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final title = item.title.isEmpty ? mediaFileName(item) : item.title;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.separator.withValues(alpha: 0.35),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(
                alpha: colors.isDark ? 0.24 : 0.06,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 88,
              height: double.infinity,
              child: item.kind == ConversationMediaKind.image
                  ? Image.network(
                      item.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _MediaIconPanel(kind: item.kind),
                    )
                  : _MediaIconPanel(kind: item.kind),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          mediaKindIcon(item.kind),
                          size: 15,
                          color: colors.primaryColor,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            mediaTypeLabel(context, item.kind),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.label,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message.time.isEmpty
                          ? item.message.sender
                          : '${item.message.sender} · ${item.message.time}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaIconPanel extends StatelessWidget {
  const _MediaIconPanel({required this.kind});

  final ConversationMediaKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Container(
      color: colors.primaryColor.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(mediaKindIcon(kind), size: 34, color: colors.primaryColor),
    );
  }
}
