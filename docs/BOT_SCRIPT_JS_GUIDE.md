# CsAC Bot JavaScript 开发文档

本文档说明当前 ServerBot 后端采用的 Bot 脚本开发方式：受限 JavaScript。

状态说明：当前 `后端/ServerBot` 已切换为 JavaScript 脚本运行时，旧的 `onGroupMsg(event) { ... }` 自研语法已废弃，不再作为后端运行时编译目标。

## 1. 设计目标

新的 Bot 脚本语言直接采用 JavaScript 语法，让开发者可以使用熟悉的语言能力。

目标：

| 目标 | 说明 |
| --- | --- |
| 易学 | 开发者按 JS 习惯写 `const`、`let`、函数、数组、对象、JSON |
| 安全 | 不开放 Node.js 的 `fs`、`process`、`child_process`、原生网络等危险能力 |
| 可控 | 所有平台能力通过 `bot` 和 `csac` SDK 暴露，方便做权限、限速和审计 |
| 可迁移 | 旧脚本可以较容易迁移到新 JS 写法 |
| 可测试 | ACOP 编辑器可直接运行当前代码，返回日志和错误堆栈 |

一句话：使用 JavaScript 语法，不使用完整 Node.js 环境。

## 2. 最小示例

### 2.1 私聊测试

```javascript
bot.on('private.message', async (ctx) => {
  if (ctx.text.trim() === '测试bot') {
    await ctx.reply('bot正在运行')
  }
})
```

### 2.2 群聊关键词回复

```javascript
bot.on('group.message', async (ctx) => {
  if (ctx.text.includes('你好')) {
    await ctx.reply(`你好，${ctx.sender.nickname}`)
  }
})
```

### 2.3 `/help` 指令

```javascript
bot.command('/help', async (ctx) => {
  await ctx.reply('可用指令：/help, /ping, 测试bot')
})

bot.command('/ping', async (ctx) => {
  await ctx.reply('pong')
})

bot.on('private.message', async (ctx) => {
  if (ctx.text.trim() === '测试bot') {
    await ctx.reply('bot正在运行')
  }
})
```

## 3. 运行环境

### 3.1 支持的 JavaScript 能力

建议支持 ECMAScript 2020 左右的常用语法。

| 能力 | 是否支持 | 示例 |
| --- | --- | --- |
| `const` / `let` | 支持 | `const text = ctx.text.trim()` |
| 普通函数 | 支持 | `function normalize(s) { return s.trim() }` |
| 箭头函数 | 支持 | `async (ctx) => {}` |
| `async` / `await` | 支持 | `await ctx.reply('ok')` |
| 数组 / 对象 | 支持 | `{ text: 'hello' }`、`[1, 2, 3]` |
| 解构 | 支持 | `const { text } = ctx` |
| 模板字符串 | 支持 | `` `hello ${name}` `` |
| `JSON.parse` / `JSON.stringify` | 支持 | `JSON.parse(res.body)` |
| `Math` / `Date` | 支持 | `Date.now()` |
| `Map` / `Set` | 支持 | `new Map()` |
| 正则表达式 | 支持 | `/^\/echo\s+(.+)/` |
| `Promise` | 支持 | `await Promise.all([...])` |

### 3.2 不支持的 Node.js 能力

为了安全，默认不提供 Node.js 系统能力。

| 能力 | 状态 | 原因 |
| --- | --- | --- |
| `require` | 不支持 | 防止加载任意模块 |
| `import` 外部包 | 不支持 | 防止绕过沙箱 |
| `fs` | 不支持 | 防止读写服务器文件 |
| `process` | 不支持 | 防止读取环境变量或退出进程 |
| `child_process` | 不支持 | 防止执行系统命令 |
| `net` / `dgram` | 不支持 | 防止任意网络连接 |
| 原生 `fetch` | 不支持 | 网络请求必须走 `csac.http` 做权限与审计 |
| `eval` / `new Function` | 不支持 | 防止动态代码绕过检查 |
| 无限定时器 | 不支持 | 使用 `bot.schedule(...)` |

### 3.3 全局对象

运行时只提供少量安全全局对象。

| 全局对象 | 说明 |
| --- | --- |
| `bot` | 注册事件、指令和定时任务 |
| `csac` | 调用 CsAC 平台能力 |
| `logger` | 写入 Bot 日志 |
| `console` | 映射到 Bot 日志，建议只用于调试 |
| `JSON` | 标准 JSON 工具 |
| `Math` | 标准数学工具 |
| `Date` | 标准时间工具 |
| `RegExp` | 标准正则 |

## 4. 脚本结构

脚本加载时会执行顶层代码一次，用于注册事件、指令和定时任务。之后每次事件到达时，运行对应 handler。

推荐结构：

```javascript
const VERSION = '1.0.0'

function cleanText(text) {
  return String(text || '').trim()
}

bot.on('private.message', async (ctx) => {
  const text = cleanText(ctx.text)
  if (text === '/version') {
    await ctx.reply(`Bot version: ${VERSION}`)
  }
})

bot.on('group.message', async (ctx) => {
  const text = cleanText(ctx.text)
  if (text === '/version') {
    await ctx.reply(`Bot version: ${VERSION}`)
  }
})
```

全局变量会在脚本运行时内存中保留，但不保证持久化。脚本保存、重载、ServerBot 重启都会清空内存状态。需要持久化的数据应使用 `csac.storage`。

## 5. 事件注册

### 5.1 `bot.on(eventName, handler)`

注册事件处理器。

```javascript
bot.on('private.message', async (ctx) => {
  await ctx.reply('收到私聊')
})
```

支持事件：

| 事件名 | 说明 |
| --- | --- |
| `private.message` | 私聊消息 |
| `group.message` | 群消息 |
| `group.member.join` | 群成员加入 |
| `group.member.leave` | 群成员离开或被移出 |
| `group.member.mute` | 群成员被禁言或解除禁言 |
| `group.disband` | 群解散 |
| `schedule.<name>` | 定时任务触发，由 `bot.schedule` 自动注册 |

### 5.2 快捷注册方法

为提升可读性，提供快捷方法。

```javascript
bot.onPrivateMessage(async (ctx) => {})
bot.onGroupMessage(async (ctx) => {})
bot.onGroupMemberJoin(async (ctx) => {})
bot.onGroupMemberLeave(async (ctx) => {})
bot.onGroupMemberMute(async (ctx) => {})
bot.onGroupDisband(async (ctx) => {})
```

等价于：

```javascript
bot.on('private.message', async (ctx) => {})
```

### 5.3 多个 handler

同一个事件允许注册多个 handler，按注册顺序执行。

```javascript
bot.on('private.message', async (ctx) => {
  logger.info('first handler')
})

bot.on('private.message', async (ctx) => {
  logger.info('second handler')
})
```

当前实现中，如果一个 handler 抛出异常，本次事件会停止执行后续 handler，并把错误写入 ServerBot 日志或脚本测试结果。

## 6. 指令系统

当前旧脚本没有内置 command 系统。新 JS 运行时建议直接提供 `bot.command(...)`。

### 6.1 精确指令

```javascript
bot.command('/help', async (ctx) => {
  await ctx.reply('帮助信息')
})
```

匹配规则：

| 规则 | 说明 |
| --- | --- |
| 默认去首尾空白 | `ctx.text.trim()` 后匹配 |
| 默认支持私聊和群聊 | 可以用选项限制 |
| 精确匹配 | `/help` 只匹配 `/help` |

### 6.2 正则指令

```javascript
bot.command(/^\/echo\s+(.+)$/i, async (ctx, match) => {
  await ctx.reply(match[1])
})
```

### 6.3 带选项的指令

```javascript
bot.command('/admin', { scope: 'group' }, async (ctx) => {
  const pms = await csac.groupInfo.botPermissions(ctx.group.id)
  await ctx.reply(pms.isAdmin ? 'Bot 是管理员' : 'Bot 不是管理员')
})
```

选项：

| 选项 | 说明 |
| --- | --- |
| `scope: 'private'` | 只匹配私聊 |
| `scope: 'group'` | 只匹配群聊 |
| `scope: 'all'` | 私聊和群聊都匹配，默认值 |
| `prefix` | 指令前缀，默认不额外处理 |

### 6.4 指令示例

```javascript
bot.command('/id', async (ctx) => {
  if (ctx.isGroup) {
    await ctx.reply(`群 ID: ${ctx.group.id}，你的 UID: ${ctx.sender.uid}`)
    return
  }
  await ctx.reply(`你的 UID: ${ctx.sender.uid}`)
})
```

## 7. 定时任务

### 7.1 `bot.schedule(cron, handler)`

```javascript
bot.schedule('*/10 * * * *', async (ctx) => {
  logger.info(`定时任务触发: ${ctx.triggerTime}`)
})
```

cron 使用 5 字段格式：

```text
分 时 日 月 周
```

支持：

| 写法 | 说明 |
| --- | --- |
| `*` | 任意值 |
| `5` | 指定值 |
| `1,2,3` | 多个值 |
| `1-5` | 范围 |
| `*/5` | 步长 |

### 7.2 带名称的定时任务

```javascript
bot.schedule('daily-report', '0 9 * * *', async (ctx) => {
  logger.info('每天 9 点执行')
})
```

命名用于日志和去重。建议同一个脚本中每个定时任务都有稳定名称。

## 8. 上下文对象 `ctx`

每个事件 handler 都会收到 `ctx`。

通用字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `ctx.eventName` | string | 事件名 |
| `ctx.eventId` | string | 事件唯一 ID，便于去重和日志排查 |
| `ctx.time` | number | 事件时间戳，秒 |
| `ctx.bot` | object | 当前 Bot 信息 |
| `ctx.sender` | object | 触发事件的用户信息 |
| `ctx.text` | string | 消息文本，无文本时为空字符串 |
| `ctx.raw` | object | 原始事件数据 |
| `ctx.isPrivate` | boolean | 是否私聊事件 |
| `ctx.isGroup` | boolean | 是否群事件 |

### 8.1 `ctx.bot`

```javascript
{
  id: 1,
  uid: 10001,
  name: 'DemoBot',
  canNotify: false,
  canHttp: false
}
```

### 8.2 `ctx.sender`

```javascript
{
  uid: 1001,
  nickname: 'Alice',
  username: 'alice',
  avatar: 'upload/avatar.png',
  isBot: false
}
```

消息事件中 `ctx.sender` 表示发送者；成员变动事件中表示被操作用户或事件主体用户。

### 8.3 私聊消息上下文

```javascript
{
  eventName: 'private.message',
  isPrivate: true,
  isGroup: false,
  text: 'hello',
  message: {
    id: 123,
    type: 'text',
    text: 'hello',
    imageUrls: [],
    replyTo: 0,
    timestamp: 1710000000
  },
  sender: {
    uid: 1001,
    nickname: 'Alice'
  },
  private: {
    fromUid: 1001,
    toUid: 10001
  }
}
```

### 8.4 群消息上下文

```javascript
{
  eventName: 'group.message',
  isPrivate: false,
  isGroup: true,
  text: 'hello',
  group: {
    id: 10,
    name: 'Demo Group'
  },
  message: {
    id: 456,
    type: 'text',
    text: 'hello',
    imageUrls: [],
    replyTo: 0,
    timestamp: 1710000000
  },
  sender: {
    uid: 1001,
    nickname: 'Alice'
  }
}
```

### 8.5 成员入群上下文

```javascript
{
  eventName: 'group.member.join',
  isGroup: true,
  group: { id: 10 },
  member: { uid: 1002 }
}
```

### 8.6 禁言上下文

```javascript
{
  eventName: 'group.member.mute',
  isGroup: true,
  group: { id: 10 },
  member: { uid: 1002 },
  operator: { uid: 1001 },
  muteUntil: 1710003600,
  muted: true
}
```

`muteUntil` 为 `0` 或小于当前时间时可视为解除禁言。

## 9. `ctx` 快捷方法

### 9.1 `ctx.reply(content, options)`

回复当前消息。

私聊中等价于给发送者发消息；群聊中等价于回复当前群消息。

```javascript
await ctx.reply('hello')
```

支持对象形式：

```javascript
await ctx.reply({
  text: '这是一张图片',
  images: ['https://example.com/a.png']
})
```

返回：

```javascript
{
  success: true,
  messageId: 123
}
```

### 9.2 `ctx.send(content)`

发送消息但不引用原消息。

```javascript
await ctx.send('不带回复引用')
```

### 9.3 `ctx.notice(title, content)`

给当前发送者发送系统通知。需要 `notify` 权限。

```javascript
await ctx.notice('处理完成', '你的请求已处理完成')
```

### 9.4 `ctx.requireGroupAdmin()`

要求 Bot 在当前群是群主或管理员。如果不是，自动回复提示并返回 `false`。

```javascript
bot.command('/mute', { scope: 'group' }, async (ctx) => {
  if (!(await ctx.requireGroupAdmin())) return
  await ctx.reply('Bot 有管理权限')
})
```

### 9.5 `ctx.fail(message)`

回复错误消息并结束当前逻辑时使用。

```javascript
if (!ctx.isGroup) {
  return ctx.fail('这个指令只能在群里使用')
}
```

## 10. 平台 SDK：`csac`

所有会产生副作用或访问平台资源的能力都通过 `csac` 暴露。

### 10.1 `csac.private`

私聊 API。

```javascript
await csac.private.sendMessage(uid, 'hello')
await csac.private.sendImage(uid, 'https://example.com/a.png')
await csac.private.replyMessage(uid, messageId, 'reply')
await csac.private.recallMessage(uid, messageId)
```

说明：

| 方法 | 说明 |
| --- | --- |
| `sendMessage(uid, text)` | 发送私聊文本，要求 Bot 与目标用户是好友 |
| `sendImage(uid, url)` | 发送私聊图片，要求 Bot 与目标用户是好友 |
| `replyMessage(uid, messageId, text)` | 回复私聊消息 |
| `recallMessage(uid, messageId)` | 撤回 Bot 自己发送的私聊消息 |

### 10.2 `csac.group`

群聊 API。

```javascript
await csac.group.sendMessage(groupId, 'hello')
await csac.group.sendImage(groupId, 'https://example.com/a.png')
await csac.group.replyMessage(groupId, messageId, 'reply')
await csac.group.recallMessage(groupId, messageId)
await csac.group.setEssence(groupId, messageId)
await csac.group.unsetEssence(groupId, messageId)
await csac.group.muteMember(groupId, uid, 60)
await csac.group.unmuteMember(groupId, uid)
await csac.group.leave(groupId)
```

说明：

| 方法 | 说明 |
| --- | --- |
| `sendMessage(groupId, text)` | 发送群文本，要求 Bot 在群内且未被禁言 |
| `sendImage(groupId, url)` | 发送群图片，要求 Bot 在群内且未被禁言 |
| `replyMessage(groupId, messageId, text)` | 回复群消息 |
| `recallMessage(groupId, messageId)` | 撤回群消息，要求 Bot 是群主或管理员 |
| `setEssence(groupId, messageId)` | 设置精华，要求 Bot 是群主或管理员 |
| `unsetEssence(groupId, messageId)` | 取消精华，要求 Bot 是群主或管理员 |
| `muteMember(groupId, uid, seconds)` | 禁言成员，要求 Bot 是群主或管理员 |
| `unmuteMember(groupId, uid)` | 解除禁言，要求 Bot 是群主或管理员 |
| `leave(groupId)` | Bot 退出群，如果 Bot 是群主则按平台规则处理 |

### 10.3 `csac.user`

用户查询 API。

```javascript
const user = await csac.user.get(uid)
```

返回：

```javascript
{
  success: true,
  uid: 1001,
  nickname: 'Alice',
  username: 'alice',
  avatar: 'upload/avatar.png',
  platform: 'web',
  lastActive: 1710000000,
  isBot: false
}
```

### 10.4 `csac.groupInfo`

群查询 API。

```javascript
const group = await csac.groupInfo.get(groupId)
const countResult = await csac.groupInfo.memberCount(groupId)
const isMember = await csac.groupInfo.hasMember(groupId, uid)
const pms = await csac.groupInfo.botPermissions(groupId)
```

返回示例：

```javascript
{
  success: true,
  groupId: 10,
  name: 'Demo Group',
  ownerUid: 1001,
  avatar: 'upload/group.png',
  memberCount: 42
}
```

Bot 权限返回：

```javascript
{
  success: true,
  isAdmin: true,
  isOwner: false
}
```

### 10.5 `csac.notice`

系统通知 API，需要 `notify` 权限。

```javascript
await csac.notice.send(uid, '标题', '通知内容')
```

### 10.6 `csac.http`

HTTP API，需要 `http` 权限。所有外部请求必须通过它，便于平台限速和审计。

```javascript
const res = await csac.http.get('https://api.example.com/status')
```

```javascript
const res = await csac.http.post('https://api.example.com/data', {
  json: { hello: 'world' }
})
```

返回：

```javascript
{
  success: true,
  status: 200,
  body: '{"ok":true}',
  contentType: 'application/json',
  json: { ok: true }
}
```

请求选项：

| 选项 | 说明 |
| --- | --- |
| `headers` | 请求头对象 |
| `body` | 字符串请求体 |
| `json` | JSON 请求体，自动序列化 |
| `timeoutMs` | 超时时间，不能超过平台上限 |

建议限制：

| 限制 | 建议值 |
| --- | --- |
| 默认超时 | 10 秒 |
| 最大响应体 | 1MB |
| 禁止内网地址 | 默认禁止访问 `127.0.0.1`、内网 IP、metadata 地址；域名解析到内网地址也会被拒绝 |
| 自动记录日志 | 记录域名、状态码、耗时，不记录敏感请求体 |

### 10.7 `csac.storage`

Bot 私有键值存储，用于替代不可靠的全局变量持久化。

```javascript
await csac.storage.set('hello.count', 1)
const count = await csac.storage.get('hello.count', 0)
await csac.storage.delete('hello.count')
```

API：

| 方法 | 说明 |
| --- | --- |
| `get(key, defaultValue)` | 读取 key，不存在时返回默认值 |
| `set(key, value)` | 写入 JSON 可序列化的值 |
| `delete(key)` | 删除 key |
| `list(prefix)` | 按前缀列出 key |
| `increment(key, step = 1)` | 原子递增数字 |

限制建议：

| 限制 | 建议值 |
| --- | --- |
| 单 Bot 总空间 | 5MB |
| 单 key 长度 | 128 字符 |
| 单 value 大小 | 64KB |

## 11. 返回值和错误处理

SDK 方法统一返回对象，不建议用裸布尔值。

成功：

```javascript
{
  success: true,
  messageId: 123
}
```

失败：

```javascript
{
  success: false,
  code: 'PERMISSION_DENIED',
  message: '缺少管理员权限'
}
```

常见错误码：

| code | 说明 |
| --- | --- |
| `ARG_ERROR` | 参数错误 |
| `NOT_FRIEND` | Bot 与目标用户不是好友 |
| `NOT_IN_GROUP` | Bot 不在群内 |
| `BOT_MUTED` | Bot 被禁言 |
| `PERMISSION_DENIED` | 缺少群管理员或平台权限 |
| `NOT_FOUND` | 用户、群或消息不存在 |
| `RATE_LIMITED` | 触发限速 |
| `HTTP_PERMISSION_REQUIRED` | 未获得 HTTP 权限 |
| `NOTICE_PERMISSION_REQUIRED` | 未获得通知权限 |
| `TIMEOUT` | 操作超时 |
| `INTERNAL_ERROR` | 平台内部错误 |

推荐写法：

```javascript
const res = await ctx.reply('hello')

if (!res.success) {
  logger.warn('send failed', res)
}
```

异常处理：

```javascript
bot.on('private.message', async (ctx) => {
  try {
    const res = await csac.http.get('https://api.example.com/data')
    if (!res.success) {
      await ctx.reply(`请求失败：${res.message}`)
      return
    }
    await ctx.reply(res.body)
  } catch (err) {
    logger.error('handler crashed', err)
    await ctx.reply('处理失败，请稍后再试')
  }
})
```

## 12. 日志

### 12.1 `logger`

```javascript
logger.info('message')
logger.warn('message')
logger.error('message')
```

支持结构化日志：

```javascript
logger.info('command received', {
  uid: ctx.sender.uid,
  text: ctx.text
})
```

日志写入 ACOP 日志页。

### 12.2 `console`

为了兼容 JS 习惯，`console.log` 可映射到 `logger.info`。

```javascript
console.log('debug message')
console.warn('warn message')
console.error('error message')
```

生产脚本建议使用 `logger`。

## 13. 权限模型

### 13.1 平台权限

| 权限 | 说明 | 获取方式 |
| --- | --- | --- |
| `notify` | 允许发送系统通知 | ACOP 中申请，管理员审核 |
| `http` | 允许外部 HTTP 请求 | ACOP 中申请，管理员审核 |

### 13.2 群权限

| 操作 | 需要条件 |
| --- | --- |
| 发群消息 | Bot 在群内且未被禁言 |
| 群回复 | Bot 在群内且未被禁言，原消息存在 |
| 撤回群消息 | Bot 是群主或管理员 |
| 设置/取消精华 | Bot 是群主或管理员 |
| 禁言/解除禁言 | Bot 是群主或管理员 |

### 13.3 私聊权限

| 操作 | 需要条件 |
| --- | --- |
| 接收私聊事件 | 用户与 Bot 是好友 |
| 发送私聊 | 目标用户与 Bot 是好友 |
| 撤回私聊 | 只能撤回 Bot 自己发送的消息 |

## 14. 安全限制建议

运行时应默认开启以下限制。

| 限制 | 建议值 | 说明 |
| --- | --- | --- |
| 单次事件超时 | 3 秒 | 防止死循环和慢脚本 |
| 单次事件最大平台调用 | 后续补强 | 当前主要依赖 Bot 全局速率限制和事件超时 |
| 单 Bot 每秒速率 | 5 次写操作 | 对齐当前 ServerBot 默认限速 |
| 单脚本大小 | 256KB | 避免超大脚本 |
| 单响应日志长度 | 4KB | 防止日志爆炸 |
| HTTP 响应体 | 1MB | 已实现，防止拉取大文件 |
| 内存限制 | 后续补强 | 当前依赖进程级资源限制 |

循环仍然允许，但必须受超时和指令步数限制。

```javascript
bot.on('private.message', async (ctx) => {
  while (true) {
    // 运行时应中断这种脚本，并记录超时错误
  }
})
```

## 15. 完整示例

### 15.1 私聊命令 Bot

```javascript
bot.command('/help', { scope: 'private' }, async (ctx) => {
  await ctx.reply('命令：/help, /ping, /id, /time')
})

bot.command('/ping', { scope: 'private' }, async (ctx) => {
  await ctx.reply('pong')
})

bot.command('/id', { scope: 'private' }, async (ctx) => {
  await ctx.reply(`你的 UID 是 ${ctx.sender.uid}，Bot UID 是 ${ctx.bot.uid}`)
})

bot.command('/time', { scope: 'private' }, async (ctx) => {
  await ctx.reply(`当前时间：${new Date().toISOString()}`)
})

bot.on('private.message', async (ctx) => {
  if (ctx.text.trim() === '测试bot') {
    await ctx.reply('bot正在运行')
  }
})
```

### 15.2 群聊关键词 Bot

```javascript
const keywords = ['你好', 'hello', 'ping']

bot.on('group.message', async (ctx) => {
  const text = ctx.text.trim().toLowerCase()
  const hit = keywords.find((kw) => text.includes(kw.toLowerCase()))

  if (!hit) return

  if (hit === 'ping') {
    await ctx.reply('pong')
    return
  }

  await ctx.reply(`你好，${ctx.sender.nickname || ctx.sender.uid}`)
})
```

### 15.3 `/echo` 正则指令

```javascript
bot.command(/^\/echo\s+(.+)$/i, async (ctx, match) => {
  await ctx.reply(match[1])
})
```

### 15.4 群管理：禁言

```javascript
bot.command(/^\/mute\s+(\d+)\s+(\d+)$/i, { scope: 'group' }, async (ctx, match) => {
  const targetUid = Number(match[1])
  const seconds = Number(match[2])

  if (!(await ctx.requireGroupAdmin())) return

  const res = await csac.group.muteMember(ctx.group.id, targetUid, seconds)

  if (!res.success) {
    await ctx.reply(`禁言失败：${res.message}`)
    return
  }

  await ctx.reply(`已禁言 UID ${targetUid} ${seconds} 秒`)
})
```

### 15.5 HTTP JSON 请求

需要先在 ACOP 申请并通过 `http` 权限。

```javascript
bot.command('/quote', async (ctx) => {
  const res = await csac.http.get('https://api.quotable.io/random')

  if (!res.success) {
    await ctx.reply(`请求失败：${res.message}`)
    return
  }

  const data = res.json || JSON.parse(res.body)
  await ctx.reply(`${data.content} - ${data.author}`)
})
```

### 15.6 存储计数器

```javascript
bot.command('/count', async (ctx) => {
  const key = `counter:${ctx.sender.uid}`
  const count = await csac.storage.increment(key, 1)
  await ctx.reply(`你已经调用了 ${count} 次`)
})
```

### 15.7 入群欢迎

```javascript
bot.on('group.member.join', async (ctx) => {
  const user = await csac.user.get(ctx.member.uid)
  const name = user.success ? user.nickname : `UID ${ctx.member.uid}`
  await csac.group.sendMessage(ctx.group.id, `欢迎 ${name} 加入群聊`)
})
```

### 15.8 定时任务

```javascript
bot.schedule('daily-log', '0 9 * * *', async () => {
  logger.info('daily job triggered')
})
```

如果需要向某个群定时发送消息，建议让开发者显式配置群 ID 或通过存储保存配置。

```javascript
bot.command(/^\/bind-report\s+(\d+)$/i, { scope: 'group' }, async (ctx, match) => {
  if (!(await ctx.requireGroupAdmin())) return

  await csac.storage.set('report.groupId', Number(match[1]))
  await ctx.reply('日报群已绑定')
})

bot.schedule('daily-report', '0 9 * * *', async () => {
  const groupId = await csac.storage.get('report.groupId', 0)
  if (!groupId) return

  await csac.group.sendMessage(groupId, '早上好，今天也要加油')
})
```

## 16. 旧脚本迁移示例

### 16.1 私聊消息

旧写法：

```text
onPrivateMsg(event) {
  if (trim(event.content) == "测试bot") {
    sendPrivateMsg(event.from_uid, "bot正在运行")
  }
}
```

新写法：

```javascript
bot.on('private.message', async (ctx) => {
  if (ctx.text.trim() === '测试bot') {
    await ctx.reply('bot正在运行')
  }
})
```

### 16.2 群消息

旧写法：

```text
onGroupMsg(event) {
  if (contains(event.content, "你好")) {
    replyGroupMsg(event, "你好")
  }
}
```

新写法：

```javascript
bot.on('group.message', async (ctx) => {
  if (ctx.text.includes('你好')) {
    await ctx.reply('你好')
  }
})
```

### 16.3 HTTP 请求

旧写法：

```text
onPrivateMsg(event) {
  res = httpGet("https://api.example.com")
  sendPrivateMsg(event.from_uid, res.body)
}
```

新写法：

```javascript
bot.on('private.message', async (ctx) => {
  const res = await csac.http.get('https://api.example.com')

  if (!res.success) {
    await ctx.reply(`请求失败：${res.message}`)
    return
  }

  await ctx.reply(res.body)
})
```

## 17. 与完整 Node.js 的区别

| 项 | Bot JS | Node.js |
| --- | --- | --- |
| 语法 | JavaScript | JavaScript |
| 文件系统 | 不支持 | 支持 `fs` |
| 子进程 | 不支持 | 支持 `child_process` |
| 第三方 npm 包 | 默认不支持 | 支持 |
| 网络请求 | 通过 `csac.http` | 任意网络库 |
| 权限控制 | 平台审核和限速 | 由运行环境控制 |
| 日志 | ACOP 日志页 | stdout/stderr 或日志系统 |
| 定时任务 | `bot.schedule` | `setTimeout`/cron 包 |

这样的设计能保留 JS 开发体验，同时避免 Bot 脚本读取服务器文件、执行系统命令或绕过平台权限。

## 18. ACOP 编辑器建议

ACOP 前端可以按 JS 脚本体验设计。

建议功能：

| 功能 | 说明 |
| --- | --- |
| 语法高亮 | JavaScript 模式 |
| 类型提示 | 内置 `bot`、`csac`、`ctx` 类型声明 |
| 事件模板 | 私聊、群聊、指令、定时任务模板 |
| 测试事件 | 可选择事件类型并填写 JSON 事件数据 |
| 测试日志 | 展示 `logger`、`console` 输出 |
| 权限提示 | 使用 `csac.http` 时提示需要 HTTP 权限 |
| 运行限制提示 | 展示超时、限速、响应体大小等限制 |

可以提供 TypeScript 声明文件给编辑器使用，但实际运行仍执行 JavaScript。

## 19. 实现建议

如果 ServerBot 继续使用 Go，可以选择以下实现路线。

| 方案 | 说明 |
| --- | --- |
| `goja` | Go 内嵌 JS 解释器，部署简单，无需 Node 进程 |
| QuickJS | 轻量 JS 引擎，隔离能力强，但 Go 集成复杂度更高 |
| 独立 Node Worker | 兼容性最好，但隔离、安全、资源限制和部署更复杂 |

推荐优先使用 `goja` 或 QuickJS 这类内嵌沙箱，不直接暴露 Node.js。

建议运行时结构：

| 模块 | 职责 |
| --- | --- |
| ScriptLoader | 从 `bot_scripts` 读取启用脚本 |
| JSRuntimePool | 每个 Bot 一个或多个 JS runtime |
| SDKBridge | 把 `csac` 方法绑定到 Go 数据库/服务调用 |
| EventDispatcher | 把主后端事件转为 `ctx` 并调用 handler |
| PermissionGuard | 检查 `can_notify`、`can_http`、群管理员等权限 |
| RateLimiter | 控制 Bot 调用频率 |
| LogWriter | 写入 `bot_logs` |
| TestRunner | ACOP 脚本测试，限制副作用或明确提示副作用 |

## 20. 推荐最终开发体验

开发者在 ACOP 里看到的默认模板可以是：

```javascript
bot.command('/help', async (ctx) => {
  await ctx.reply('你好，我是 CsAC Bot。可用指令：/help, /ping')
})

bot.command('/ping', async (ctx) => {
  await ctx.reply('pong')
})

bot.on('private.message', async (ctx) => {
  if (ctx.text.trim() === '测试bot') {
    await ctx.reply('bot正在运行')
  }
})

bot.on('group.message', async (ctx) => {
  if (ctx.text.includes('你好')) {
    await ctx.reply(`你好，${ctx.sender.nickname || ctx.sender.uid}`)
  }
})
```

这套方案比当前旧脚本语言多出完整 JS 语法、函数、对象、数组、JSON、正则、`async/await`、指令系统、存储和更清晰的 SDK，同时仍然保留平台可控的安全边界。
