/**
 * 寸进 · CUNJIN —— 备份文档（导出 / 导入）的纯函数层
 *
 * 目的：把"生成备份文本"和"解析备份文本"这两步做成可单测的纯函数，
 * 文件选择与磁盘读写在 repository/BackupFile.ets（不可单测，需真机）。
 *
 * ── 与既有持久化协议的关系 ────────────────────────────────
 * 这是**新增的导出文件格式**，不改动 KV 里已有的 `cards_v2` / `settings_v2` /
 * `work_state_v2` 任何一个字节。备份文件内部直接嵌入这三个 payload 的原始字符串
 * （由 CardCodec 的 serializeXxx 生成），因此：
 *   · JSON 持久化协议未变；
 *   · 旧 KV key 未变；
 *   · 导入时仍然只用 CardCodec 的反序列化函数，不引入第二套数据格式。
 *
 * 结构：
 *   { "format": "cunjin-next-backup", "version": 1, "exportedAt": <ms>,
 *     "cards": "<cards_v2 原样字符串>", "settings": "<settings_v2 原样字符串>",
 *     "work": "<work_state_v2 原样字符串>" }
 */

import { CardSettings, TaskCardData, WorkState, normalizeCards } from './TaskCardData';
import {
  deserializeCards, deserializeWorkState, serializeCards, serializeSettings, serializeWorkState
} from './CardCodec';

/** 备份文件标识，导入时用于拒绝任意 JSON。 */
export const EXPORT_FORMAT: string = 'cunjin-next-backup';
/** 备份文件结构版本；导入时只接受 <= 该值的文件。 */
export const EXPORT_VERSION: number = 1;

interface ExportEnvelope {
  format: string;
  version: number;
  exportedAt: number;
  cards: string;
  settings: string;
  work: string;
}

export interface ExportParseResult {
  ok: boolean;
  /** 失败原因代码（英文，便于日志与测试断言） */
  reason: string;
  cardCount: number;
  cards: TaskCardData[];
  /** settings payload 原文；由调用方用自己的默认值反序列化 */
  settingsText: string;
  work: WorkState | undefined;
}

function failResult(reason: string): ExportParseResult {
  const result: ExportParseResult = {
    ok: false, reason: reason, cardCount: 0, cards: [], settingsText: '', work: undefined
  };
  return result;
}

/**
 * 生成备份文本。
 * 传入的 cards / settings / work 应当就是当前页面的真实状态。
 * exportedAt 由调用方传入，保持函数纯净、可测试。
 */
export function buildExportText(cards: TaskCardData[], settings: CardSettings, work: WorkState,
  exportedAt: number): string {
  const envelope: ExportEnvelope = {
    format: EXPORT_FORMAT,
    version: EXPORT_VERSION,
    exportedAt: exportedAt,
    cards: serializeCards(cards),
    settings: serializeSettings(settings),
    work: serializeWorkState(work)
  };
  return JSON.stringify(envelope);
}

/**
 * 解析备份文本。
 *
 * 失败一律返回 ok=false + reason，不抛异常：
 *   empty / not-json / wrong-format / unsupported-version / missing-cards / no-cards
 *
 * 其中 `no-cards` 是刻意的安全策略：**拒绝导入 0 张卡片的备份**，
 * 避免用户误选一个空文件就把现有卡片全部清空。
 * 若确实需要"清空"，请在应用内逐张删除，而不是走导入。
 */
export function parseExportText(text: string): ExportParseResult {
  if (text == undefined || text.length == 0) {
    return failResult('empty');
  }

  let envelope: ExportEnvelope;
  try {
    envelope = JSON.parse(text) as ExportEnvelope;
  } catch (error) {
    return failResult('not-json');
  }

  if (envelope == undefined || envelope.format !== EXPORT_FORMAT) {
    return failResult('wrong-format');
  }
  if (typeof envelope.version !== 'number' || envelope.version > EXPORT_VERSION) {
    return failResult('unsupported-version');
  }
  if (typeof envelope.cards !== 'string') {
    return failResult('missing-cards');
  }

  // 先反序列化，再规范一遍：导入的数据同样要经过与新数据相同的校验路径
  const cards = normalizeCards(deserializeCards(envelope.cards));
  if (cards.length == 0) {
    return failResult('no-cards');
  }

  const settingsText: string = typeof envelope.settings === 'string' ? envelope.settings : '';
  let work: WorkState | undefined = undefined;
  if (typeof envelope.work === 'string') {
    work = deserializeWorkState(envelope.work);
  }

  const result: ExportParseResult = {
    ok: true, reason: 'ok', cardCount: cards.length, cards: cards, settingsText: settingsText, work: work
  };
  return result;
}

/** 生成备份文件名（不含目录），形如 cunjin-backup-1700000000000.json */
export function exportFileName(exportedAt: number): string {
  return 'cunjin-backup-' + exportedAt.toString() + '.json';
}

/**
 * 生成"导入前自动快照"的文件名。
 * 与用户手动导出的备份区分开，便于在沙箱目录里辨认：
 *   cunjin-pre-import-1700000000000.json
 */
export function preImportFileName(importedAt: number): string {
  return 'cunjin-pre-import-' + importedAt.toString() + '.json';
}
