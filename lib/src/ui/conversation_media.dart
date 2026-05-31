part of '../../main.dart';

class ConversationMediaScreen extends StatefulWidget {
  const ConversationMediaScreen({
    super.key,
    required this.state,
    required this.conversation,
  });

  final CsacAppState state;
  final Conversation conversation;

  @override
  State<ConversationMediaScreen> createState() =>
      _ConversationMediaScreenState();
}

class _ConversationMediaScreenState extends State<ConversationMediaScreen> {
  final search = TextEditingController();
  ConversationMediaKind kind = ConversationMediaKind.all;
  List<ConversationMediaItem> items = const <ConversationMediaItem>[];
  bool loading = true;
  bool syncing = false;
  String? error;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    load(sync: true);
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void scheduleLoad() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), () => load());
  }

  Future<void> load({bool sync = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      loading = !sync;
      syncing = sync;
      error = null;
    });
    try {
      if (sync) {
        try {
          await widget.state.syncMessages(widget.conversation);
        } catch (_) {
          // Cached media should remain available when the network is offline.
        }
      }
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
        setState(() {
          loading = false;
          syncing = false;
        });
      }
    }
  }

  void setKind(ConversationMediaKind value) {
    setState(() => kind = value);
    load();
  }

  Future<void> openMessage(ConversationMediaItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: widget.conversation,
          focusMessageId: item.message.id,
        ),
      ),
    );
  }

  Future<void> openItem(ConversationMediaItem item) async {
    if (item.kind == ConversationMediaKind.image) {
      showImagePreview(
        context,
        item.url,
        heroTag: conversationMediaHeroTag(item),
      );
      return;
    }
    final opened = await launchUrl(
      Uri.parse(item.url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Open failed.'))),
      );
    }
  }

  Future<void> downloadItem(ConversationMediaItem item) async {
    switch (item.kind) {
      case ConversationMediaKind.image:
        await downloadImage(context, item.url);
        break;
      case ConversationMediaKind.voice:
        await downloadUrl(
          context,
          item.url,
          suggestedName: defaultDownloadName(
            item.url,
            fallbackExtension: '.mp3',
          ),
          typeLabel: context.strings.text('Audio files'),
          extensions: voiceExtensions,
        );
        break;
      case ConversationMediaKind.file:
      case ConversationMediaKind.all:
        await downloadUrl(
          context,
          item.url,
          suggestedName: defaultDownloadName(item.url),
          typeLabel: context.strings.text('Files'),
        );
        break;
    }
  }

  Future<void> showActions(ConversationMediaItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(context.strings.text('Open original')),
              onTap: () => Navigator.of(context).pop('open'),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(context.strings.text('Download')),
              onTap: () => Navigator.of(context).pop('download'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(context.strings.text('Copy link')),
              onTap: () => Navigator.of(context).pop('copy'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(context.strings.text('View in chat')),
              onTap: () => Navigator.of(context).pop('chat'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'open':
        await openItem(item);
        break;
      case 'download':
        await downloadItem(item);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: item.url));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.strings.text('Link copied.'))),
          );
        }
        break;
      case 'chat':
        await openMessage(item);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('Media and files')),
        actions: [
          IconButton(
            tooltip: strings.text('Refresh'),
            onPressed: syncing ? null : () => load(sync: true),
            icon: syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                controller: search,
                onChanged: (_) => scheduleLoad(),
                decoration: InputDecoration(
                  hintText: strings.text('Search media and files'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: strings.text('Clear'),
                          onPressed: () {
                            search.clear();
                            load();
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  _MediaKindChip(
                    label: strings.text('All'),
                    selected: kind == ConversationMediaKind.all,
                    onSelected: () => setKind(ConversationMediaKind.all),
                  ),
                  _MediaKindChip(
                    label: strings.text('Images'),
                    selected: kind == ConversationMediaKind.image,
                    onSelected: () => setKind(ConversationMediaKind.image),
                  ),
                  _MediaKindChip(
                    label: strings.text('Voice'),
                    selected: kind == ConversationMediaKind.voice,
                    onSelected: () => setKind(ConversationMediaKind.voice),
                  ),
                  _MediaKindChip(
                    label: strings.text('Files'),
                    selected: kind == ConversationMediaKind.file,
                    onSelected: () => setKind(ConversationMediaKind.file),
                  ),
                ],
              ),
            ),
            if (loading || syncing) const LinearProgressIndicator(minHeight: 2),
            if (error != null)
              MaterialBanner(
                content: Text(error!),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => error = null),
                    child: Text(strings.text('Dismiss')),
                  ),
                ],
              ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? _EmptyPanel(
                      message: strings.text('No media or files in this chat.'),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final grid = constraints.maxWidth >= 720;
                        if (!grid) {
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                            itemCount: items.length,
                            itemBuilder: (context, index) => _MotionListItem(
                              index: index,
                              child: _MediaListTile(
                                item: items[index],
                                preferences: widget.state.preferences,
                                onOpen: () => openItem(items[index]),
                                onMore: () => showActions(items[index]),
                              ),
                            ),
                          );
                        }
                        final crossAxisCount = constraints.maxWidth >= 1100
                            ? 4
                            : 3;
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.05,
                              ),
                          itemCount: items.length,
                          itemBuilder: (context, index) => _MotionListItem(
                            index: index,
                            child: _MediaGridTile(
                              item: items[index],
                              preferences: widget.state.preferences,
                              onOpen: () => openItem(items[index]),
                              onMore: () => showActions(items[index]),
                            ),
                          ),
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

class _MediaKindChip extends StatelessWidget {
  const _MediaKindChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _MediaListTile extends StatelessWidget {
  const _MediaListTile({
    required this.item,
    required this.preferences,
    required this.onOpen,
    required this.onMore,
  });

  final ConversationMediaItem item;
  final CsacPreferences preferences;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final time = displayMessageTime(item.message, preferences);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: _RoundedInkClip(
        child: ListTile(
          leading: _MediaThumbnail(
            item: item,
            heroTag: conversationMediaHeroTag(item),
          ),
          title: Text(
            item.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              item.message.sender,
              if (time.isNotEmpty) time,
              if (item.message.body.isNotEmpty &&
                  !item.message.body.startsWith('['))
                compactMessage(item.message.body),
            ].join(' | '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: onOpen,
          trailing: IconButton(
            tooltip: context.strings.text('More'),
            onPressed: onMore,
            icon: const Icon(Icons.more_vert),
          ),
        ),
      ),
    );
  }
}

class _MediaGridTile extends StatelessWidget {
  const _MediaGridTile({
    required this.item,
    required this.preferences,
    required this.onOpen,
    required this.onMore,
  });

  final ConversationMediaItem item;
  final CsacPreferences preferences;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = displayMessageTime(item.message, preferences);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: colors.surfaceContainerHighest,
                child: _MediaThumbnail(
                  item: item,
                  large: true,
                  heroTag: conversationMediaHeroTag(item),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          time.isEmpty
                              ? item.message.sender
                              : '${item.message.sender} | $time',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.strings.text('More'),
                    onPressed: onMore,
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({required this.item, this.large = false, this.heroTag});

  final ConversationMediaItem item;
  final bool large;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = large ? double.infinity : 48.0;
    if (item.kind == ConversationMediaKind.image) {
      final image = Image.network(
        item.url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _MediaFallbackIcon(icon: Icons.broken_image_outlined, large: large),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(large ? 0 : 8),
        child: heroTag == null
            ? image
            : Hero(
                tag: heroTag!,
                child: Material(type: MaterialType.transparency, child: image),
              ),
      );
    }
    final icon = item.kind == ConversationMediaKind.voice
        ? Icons.graphic_eq_rounded
        : Icons.insert_drive_file_outlined;
    final foreground = item.kind == ConversationMediaKind.voice
        ? colors.onSecondaryContainer
        : colors.onTertiaryContainer;
    final background = item.kind == ConversationMediaKind.voice
        ? colors.secondaryContainer
        : colors.tertiaryContainer;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(large ? 0 : 8),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: foreground, size: large ? 56 : 26),
    );
  }
}

String conversationMediaHeroTag(ConversationMediaItem item) {
  return 'media-image:${item.message.id}:${item.url}';
}

class _MediaFallbackIcon extends StatelessWidget {
  const _MediaFallbackIcon({required this.icon, this.large = false});

  final IconData icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: large ? double.infinity : 48,
      height: large ? double.infinity : 48,
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icon, size: large ? 48 : 26, color: colors.onSurfaceVariant),
    );
  }
}
