/**
 * 寸进 · CUNJIN —— 旧版 CSV 解码（纯模块，无 @kit 依赖）
 *
 * 本文件刻意**逐字复刻**旧版读取行为，保证迁移结果与旧版本 App 当时显示的一致：
 *   列表     ：Array.toString() -> "," 分隔，无转义；"" 视为空
 *   数字列表 ：同上，逐项 Number()
 *   矩阵     ：行间 ";"，行内 ","；"" 视为空
 *
 * 已知不可逆限制（必须如实记录，不能假装能恢复）：
 *   旧版用 "," 拼接 name / desc，因此**任何含逗号的卡片名或描述在旧数据中已经丢失边界**。
 *   本解码器无法还原原始文本，只能按旧版当时的切分结果重建，并在警告中记录长度不一致。
 *   含逗号的卡片会被旧版切分成多张"幽灵卡片"，本解码器同样如实重建这些条目，
 *   由调用方在 UI 中呈现，绝不静默丢弃。
 */

import { CardSettings, TaskCardData, WorkState, normalizePunchCard, normalizeNotes } from './TaskCardData';

/** 旧版卡片相关的 9 个 KV key 的原始字符串值。缺失用 undefined 表示。 */
export interface LegacyCardRaw {
  cardsName: string | undefined;
  cardsDesc: string | undefined;
  cardsLength: string | undefined;
  cardsTimeLimit: string | undefined;
  cardsTarget: string | undefined;
  cardsDone: string | undefined;
  cardsStart: string | undefined;
  cardsEnd: string | undefined;
  cardsPunchCard: string | undefined;
}

/** 旧版外观设置的 6 个 KV key 的原始字符串值。 */
export interface LegacySettingsRaw {
  useBackdrop: string | undefined;
  colorSchemeLight: string | undefined;
  colorSchemeDark: string | undefined;
  blurRadius: string | undefined;
  minBlockSize: string | undefined;
  appOpenTime: string | undefined;
}

/** 旧版计时状态的 3 个 KV key 的原始字符串值。 */
export interface LegacyWorkRaw {
  workingCardName: string | undefined;
  workStart: string | undefined;
  workLastEnd: string | undefined;
}

export interface LegacyCardDecodeResult {
  cards: TaskCardData[];
  warnings: string[];
  /** 旧版全部 key 都是 "no" 哨兵（存储未就绪时读到的伪数据），不应迁移。 */
  sentinelDetected: boolean;
}

/** 旧版 getValueOfKey 在 store 未就绪时返回的字面量。 */
const LEGACY_SENTINEL: string = 'no';

function isEmpty(raw: string | undefined): boolean {
  return raw === undefined || raw === '';
}

/** 复刻旧版 `(result as string).split(",")` + `[0]=="" -> []`。 */
export function splitLegacyList(raw: string | undefined): string[] {
  if (isEmpty(raw)) {
    return [];
  }
  const parts = (raw as string).split(',');
  if (parts.length > 0 && parts[0] === '') {
    return [];
  }
  return parts;
}

/** 复刻旧版数字列表解析（逐项 Number()）。 */
export function parseLegacyNumberList(raw: string | undefined): number[] {
  const parts = splitLegacyList(raw);
  const out: number[] = [];
  for (let i = 0; i < parts.length; i++) {
    out.push(Number(parts[i]));
  }
  return out;
}

/**
 * 复刻旧版矩阵解析："" -> []；否则 ";" 分行、"," 分列、逐项 Number()。
 * 注意旧版行为：尾部分隔符会产生一个额外的 [0] 行，这里同样保留，以保证迁移结果与旧版显示一致。
 */
export function parseLegacyMatrix(raw: string | undefined): number[][] {
  if (isEmpty(raw)) {
    return [];
  }
  const rows = (raw as string).split(';');
  const out: number[][] = [];
  for (let r = 0; r < rows.length; r++) {
    const cells = rows[r].split(',');
    const line: number[] = [];
    for (let c = 0; c < cells.length; c++) {
      line.push(Number(cells[c]));
    }
    out.push(line);
  }
  return out;
}

/** 旧版矩阵序列化（仅用于回归对比，不再作为新格式）。 */
export function serializeLegacyMatrix(rows: number[][]): string {
  let output = '';
  for (let i = 0; i < rows.length; i++) {
    output += rows[i].toString();
    if (i !== rows.length - 1) {
      output += ';';
    }
  }
  return output;
}

function numberOr(raw: string | undefined, fallback: number): number {
  const n = Number(raw);
  if (Number.isFinite(n)) {
    return n;
  }
  return fallback;
}

/**
 * 判断整份快照是否全部是旧版 "no" 哨兵。
 * 只有在**所有**卡片 key 都是哨兵/空时才认定为哨兵，避免误伤名为 "no" 的真实卡片。
 */
export function isLegacySentinel(raw: LegacyCardRaw): boolean {
  const values: (string | undefined)[] = [
    raw.cardsName, raw.cardsDesc, raw.cardsLength, raw.cardsTimeLimit, raw.cardsTarget,
    raw.cardsDone, raw.cardsStart, raw.cardsEnd, raw.cardsPunchCard
  ];
  let sawSentinel = false;
  for (let i = 0; i < values.length; i++) {
    const value = values[i];
    if (value === undefined || value === '') {
      continue;
    }
    if (value === LEGACY_SENTINEL) {
      sawSentinel = true;
      continue;
    }
    return false;
  }
  return sawSentinel;
}

/**
 * 把旧版 9 个平行数组还原为统一卡片对象。
 *
 * 以 name 数组长度为准（旧版 UI 也是以 name 驱动 ForEach），
 * 其余数组缺项时使用安全默认值，并记录 warning。
 *
 * @param raw 旧版原始字符串
 * @param fallbackStartAt 当 start/end 缺失时使用的时间基准（迁移时刻）
 */
export function decodeLegacyCards(raw: LegacyCardRaw, fallbackStartAt: number): LegacyCardDecodeResult {
  const warnings: string[] = [];
  const sentinel = isLegacySentinel(raw);
  if (sentinel) {
    warnings.push('检测到旧版 "no" 哨兵数据（存储未就绪时写入的伪数据），已跳过迁移。');
    const empty: TaskCardData[] = [];
    const result: LegacyCardDecodeResult = { cards: empty, warnings: warnings, sentinelDetected: true };
    return result;
  }

  const names = splitLegacyList(raw.cardsName);
  const descs = splitLegacyList(raw.cardsDesc);
  const lengths = parseLegacyNumberList(raw.cardsLength);
  const timeLimits = parseLegacyNumberList(raw.cardsTimeLimit);
  const targets = parseLegacyNumberList(raw.cardsTarget);
  const dones = parseLegacyNumberList(raw.cardsDone);
  const starts = parseLegacyNumberList(raw.cardsStart);
  const ends = parseLegacyNumberList(raw.cardsEnd);
  const punchRows = parseLegacyMatrix(raw.cardsPunchCard);

  if (names.length === 0) {
    const result: LegacyCardDecodeResult = { cards: [], warnings: warnings, sentinelDetected: false };
    return result;
  }

  // 旧版逗号拼接导致的核心问题：name 比其它数组长。
  if (descs.length !== names.length) {
    warnings.push('cards_desc 数量(' + descs.length.toString() + ')与 cards_name(' +
      names.length.toString() + ')不一致，疑似历史数据中的逗号已被切分，描述可能错位。');
  }
  if (lengths.length !== names.length) {
    warnings.push('cards_length 数量与 cards_name 不一致，缺失项使用默认长度 200。');
  }
  if (timeLimits.length !== names.length) {
    warnings.push('cards_time_limit 数量与 cards_name 不一致，缺失项使用默认 1 天。');
  }
  if (dones.length !== names.length) {
    warnings.push('cards_done 数量与 cards_name 不一致，缺失项按 0 小时处理。');
  }

  const cards: TaskCardData[] = [];
  for (let i = 0; i < names.length; i++) {
    const name = names[i];
    const timeLimit = i < timeLimits.length && Number.isFinite(timeLimits[i]) ? Math.max(1, Math.floor(timeLimits[i])) : 1;
    const startAt = i < starts.length && Number.isFinite(starts[i]) && starts[i] > 0 ? starts[i] : fallbackStartAt;
    const endRaw = i < ends.length && Number.isFinite(ends[i]) ? ends[i] : 0;
    const endAt = endRaw > 0 ? endRaw : startAt + 86400000 * timeLimit;
    const done = i < dones.length && Number.isFinite(dones[i]) ? Math.max(0, dones[i]) : 0;
    const target = i < targets.length && Number.isFinite(targets[i]) ? targets[i] : 0;
    const length = i < lengths.length && Number.isFinite(lengths[i]) && lengths[i] > 0 ? lengths[i] : 200;
    const desc = i < descs.length ? descs[i] : '';
    const punchSource = i < punchRows.length ? punchRows[i] : [];

    const card: TaskCardData = {
      id: 'legacy_' + i.toString(),
      name: name,
      desc: desc,
      length: length,
      timeLimitDays: timeLimit,
      targetHours: target,
      doneHours: done,
      startAt: startAt,
      endAt: endAt,
      punchCard: normalizePunchCard(punchSource, timeLimit),
      // 旧数据没有"归档"概念，一律视为未归档
      archived: false,
      // 旧数据没有每日备注，补成与 punchCard 等长的空串数组
      notes: normalizeNotes([], timeLimit)
    };
    cards.push(card);
  }

  const result: LegacyCardDecodeResult = { cards: cards, warnings: warnings, sentinelDetected: false };
  return result;
}

/** 旧版设置解码。颜色仍按 "," 切分（颜色值不含逗号，因此无损坏风险）。 */
export function decodeLegacySettings(raw: LegacySettingsRaw, fallback: CardSettings,
  blurRadiusDefault: number, minCardSizeDefault: number): CardSettings {
  const light = splitLegacyList(raw.colorSchemeLight);
  const dark = splitLegacyList(raw.colorSchemeDark);
  const result: CardSettings = {
    schemaVersion: fallback.schemaVersion,
    useBackdrop: raw.useBackdrop === 'true',
    colorSchemeLight: light.length > 0 ? light : fallback.colorSchemeLight.slice(0),
    colorSchemeDark: dark.length > 0 ? dark : fallback.colorSchemeDark.slice(0),
    blurRadius: numberOr(raw.blurRadius, blurRadiusDefault),
    minCardSize: numberOr(raw.minBlockSize, minCardSizeDefault),
    appOpenTime: numberOr(raw.appOpenTime, 0),
    // 旧版没有"隐藏已归档"概念，沿用兜底值（默认 false）
    hideArchived: fallback.hideArchived
  };
  if (result.blurRadius <= 0) {
    result.blurRadius = blurRadiusDefault;
  }
  if (result.minCardSize <= 0) {
    result.minCardSize = minCardSizeDefault;
  }
  return result;
}

/** 旧版计时状态解码。 */
export function decodeLegacyWorkState(raw: LegacyWorkRaw, fallback: WorkState): WorkState {
  const name = raw.workingCardName === undefined ? '' : raw.workingCardName;
  const result: WorkState = {
    schemaVersion: fallback.schemaVersion,
    workingCardName: name === LEGACY_SENTINEL ? '' : name,
    workStart: numberOr(raw.workStart, 0),
    workLastEnd: numberOr(raw.workLastEnd, fallback.workLastEnd)
  };
  if (!Number.isFinite(result.workStart) || result.workStart < 0) {
    result.workStart = 0;
  }
  if (!Number.isFinite(result.workLastEnd) || result.workLastEnd < 0) {
    result.workLastEnd = fallback.workLastEnd;
  }
  return result;
}
