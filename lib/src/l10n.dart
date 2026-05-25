import 'package:flutter/widgets.dart';

import 'preferences.dart';

Locale localeForLanguage(CsacLanguage language) {
  switch (language) {
    case CsacLanguage.en:
      return const Locale('en');
    case CsacLanguage.zh:
      return const Locale('zh', 'CN');
  }
}

class CsacStrings {
  const CsacStrings(this.locale);

  final Locale locale;

  bool get isZh => locale.languageCode == 'zh';

  static CsacStrings of(BuildContext context) {
    return Localizations.of<CsacStrings>(context, CsacStrings) ??
        const CsacStrings(Locale('zh', 'CN'));
  }

  String text(String key) {
    if (!isZh) {
      return key;
    }
    return _zh[key] ?? key;
  }

  String format(String key, Map<String, Object?> values) {
    var result = text(key);
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }
}

class CsacStringsDelegate extends LocalizationsDelegate<CsacStrings> {
  const CsacStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'en' || locale.languageCode == 'zh';
  }

  @override
  Future<CsacStrings> load(Locale locale) async {
    return CsacStrings(locale);
  }

  @override
  bool shouldReload(CsacStringsDelegate old) => false;
}

extension CsacStringsContext on BuildContext {
  CsacStrings get strings => CsacStrings.of(this);
}

const _zh = <String, String>{
  'CsAC Mobile': 'CsAC 移动端',
  'Restoring session...': '正在恢复会话...',
  'Checking saved session...': '正在检查已保存的会话...',
  'Session expired. Cached history is available offline.': '会话已过期，可离线查看本地缓存历史。',
  'Unable to restore session.': '无法恢复会话。',
  'Username and password are required.': '请输入用户名和密码。',
  'Username': '用户名',
  'Password': '密码',
  'Login': '登录',
  'Developer options': '开发者选项',
  'Default server': '默认服务器',
  'Current server: {server}': '当前服务器：{server}',
  'New messages: {count}': '新消息：{count} 条',
  'Select a conversation': '选择一个会话',
  'Chats': '聊天',
  'Search': '搜索',
  'Notices': '通知',
  'Me': '我的',
  'Not logged in': '未登录',
  'Offline': '离线',
  'Add friend': '添加好友',
  'Join group': '加入群组',
  'Search conversations': '搜索会话',
  'Clear': '清除',
  'No conversations yet.': '暂无会话。',
  'No matching conversations.': '没有匹配的会话。',
  'Refresh': '刷新',
  'Search messages': '搜索消息',
  'Logout': '退出登录',
  'Group chat': '群聊',
  'Private chat': '私聊',
  'Enter a valid UID.': '请输入有效的 UID。',
  'Friend request sent.': '好友申请已发送。',
  'User UID': '用户 UID',
  'Lookup user': '查找用户',
  'Request message': '申请消息',
  'Send request': '发送申请',
  'Enter a valid room ID.': '请输入有效的房间 ID。',
  'Join request sent.': '入群申请已发送。',
  'Room ID': '房间 ID',
  'Invite code': '邀请码',
  'Answer': '答案',
  'Apply to join': '申请加入',
  'Public groups': '公开群组',
  'Search public groups': '搜索公开群组',
  'No public groups.': '暂无公开群组。',
  'Join': '加入',
  'Room {id}': '房间 {id}',
  'Search cached messages': '搜索缓存消息',
  'All': '全部',
  'Friends': '好友',
  'Groups': '群组',
  'Images': '图片',
  'Essence': '精华',
  'Dismiss': '关闭',
  'Type to search cached messages.': '输入关键词搜索缓存消息。',
  'No matching messages.': '没有匹配的消息。',
  '(empty)': '（空）',
  'Open': '打开',
  'Notice copied': '通知已复制',
  'Copy': '复制',
  'Close': '关闭',
  '{count} unread': '{count} 条未读',
  'Mark all read': '全部标为已读',
  'No notices.': '暂无通知。',
  'Mark read': '标为已读',
  'No friend requests.': '暂无好友申请。',
  'Refuse': '拒绝',
  'Agree': '同意',
  'No group applications.': '暂无群组审核。',
  'Group: {name}': '群组：{name}',
  'Pass': '通过',
  'Session expired. Log in again to sync latest data.': '会话已过期，请重新登录以同步最新数据。',
  'Unread notices': '未读通知',
  'Friend requests': '好友申请',
  'Group reviews': '群组审核',
  'Refresh all': '全部刷新',
  'Settings': '设置',
  'System': '跟随系统',
  'Light': '浅色',
  'Dark': '深色',
  'English': 'English',
  '中文': '中文',
  'Refreshed.': '已刷新。',
  'Refresh failed: {error}': '刷新失败：{error}',
  'Clear local cache?': '清除本地缓存？',
  'Cached conversations and message history on this device will be removed. Your login session will be kept.':
      '此设备上的缓存会话和消息历史将被移除，登录会话会保留。',
  'Cancel': '取消',
  'Local cache cleared.': '本地缓存已清除。',
  'Clear cache failed: {error}': '清除缓存失败：{error}',
  'Theme': '主题',
  'Language': '语言',
  'Refresh app data': '刷新应用数据',
  'Reload conversations and counters': '重新加载会话和计数',
  'Clear local cache': '清除本地缓存',
  'Remove cached conversations and message history': '移除缓存会话和消息历史',
  'CsAC server address': 'CsAC 服务器地址',
  'Leave empty to use the default server.': '留空则使用默认服务器。',
  'Reset to default': '恢复默认',
  'Apply server': '应用服务器',
  'Server address saved. Please log in again.': '服务器地址已保存，请重新登录。',
  'Server address is unchanged.': '服务器地址未改变。',
  'Invalid server address.': '服务器地址无效。',
  'Save failed: {error}': '保存失败：{error}',
  'Clear session and return to login': '清除会话并返回登录',
  'Pending': '待处理',
  'Handled': '已处理',
  'Retry': '重试',
  'Add {name}': '添加 {name}',
  'Send': '发送',
  'Request failed: {error}': '申请失败：{error}',
  'Join {name}': '加入 {name}',
  'Apply': '申请',
  'Join failed: {error}': '加入失败：{error}',
  'Edit remark': '编辑备注',
  'Remark': '备注',
  'Save': '保存',
  'Remark updated.': '备注已更新。',
  'Update failed: {error}': '更新失败：{error}',
  'Delete {name}?': '删除 {name}？',
  'This friend will be removed from your list.': '该好友将从你的列表中移除。',
  'Delete': '删除',
  'Friend deleted.': '好友已删除。',
  'Delete failed: {error}': '删除失败：{error}',
  'Block {name}?': '拉黑 {name}？',
  'This friend will be blocked.': '该好友将被拉黑。',
  'Block': '拉黑',
  'Friend blocked.': '好友已拉黑。',
  'Block failed: {error}': '拉黑失败：{error}',
  'Leave {name}?': '退出 {name}？',
  'This group will be removed from your chats.': '该群组将从你的聊天列表中移除。',
  'Leave': '退出',
  'Left group.': '已退出群组。',
  'Leave failed: {error}': '退出失败：{error}',
  'Member action completed.': '成员操作已完成。',
  'Action failed: {error}': '操作失败：{error}',
  'Mute 10 minutes': '禁言 10 分钟',
  'Unmute': '解除禁言',
  'Set admin': '设为管理员',
  'Remove admin': '取消管理员',
  'Kick member': '移出成员',
  '{label} copied.': '{label} 已复制。',
  'UID': 'UID',
  'Online': '在线状态',
  'Delete friend': '删除好友',
  'Block friend': '拉黑好友',
  'Common groups': '共同群组',
  'Copy room ID': '复制房间 ID',
  'Description': '简介',
  'Notice': '公告',
  'Copy invite code': '复制邀请码',
  'Fixed code': '固定邀请码',
  'Question': '问题',
  'Leave group': '退出群组',
  'Members': '成员',
  'No members.': '暂无成员。',
  'Manage': '管理',
  'Group details': '群组详情',
  'User details': '用户详情',
  'Offline cache: {error}': '离线缓存：{error}',
  '[recalled]': '[已撤回]',
  'Message copied': '消息已复制',
  'Image link copied': '图片链接已复制',
  'Referenced message is not loaded.': '引用的消息尚未加载。',
  'Details': '详情',
  'No messages.': '暂无消息。',
  'Message': '消息',
  'Mention': '提及',
  'Image': '图片',
  'Reply #{id}': '回复 #{id}',
  'Reply {sender}: {message}': '回复 {sender}：{message}',
  'Mentioned': '提及我',
  'Reply': '回复',
  'Copy text': '复制文本',
  'Copy image link': '复制图片链接',
  'Open image': '打开图片',
  'Download image': '下载图片',
  'Recall': '撤回',
  'Remove essence': '取消精华',
  'Set essence': '设为精华',
  'Reply #{id}: {sender}': '回复 #{id}：{sender}',
  '@ {count} members': '@ {count} 位成员',
  'Mention members': '提及成员',
  'Toggle all': '全选/取消全选',
  '{count} selected': '已选择 {count} 个',
  'Done': '完成',
  'Essence messages': '精华消息',
  'No essence messages.': '暂无精华消息。',
  'Send image: {fileName}': '发送图片：{fileName}',
  'Caption': '说明文字',
  'Copy link': '复制链接',
  'Download': '下载',
  'Saved to {path}': '已保存到 {path}',
  'Download failed: {error}': '下载失败：{error}',
};
