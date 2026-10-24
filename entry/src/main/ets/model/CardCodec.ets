/**
 * 寸进 · CUNJIN —— 新版 JSON 编解码（纯模块，无 @kit 依赖）
 *
 * 与旧版 CSV 的关键差异：
 * - 值内出现逗号、分号、双引号、换行、emoji 都不会破坏结构（JSON 自带转义）。
 * - 解析失败不抛异常，返回空结果，由调用方决定是否保留旧数据。
 */

import { CardSettings, TaskCardData, WorkState, normalizeCards, normalizeSettings, normalizeWorkState }
  from './TaskCardData';

/**
 * 序列化卡片列表。
 * 注意：TaskCardData 是 interface（纯数据），JSON.stringify 不会带出多余字段。
 */
export function serializeCards(cards: TaskCardData[]): string {
  return JSON.stringify(cards);
}

/** 反序列化卡片列表。任何结构异常都返回空数组，绝不抛异常。 */
export function deserializeCards(text: string): TaskCardData[] {
  if (typeof text !== 'string' || text === '') {
    return [];
  }
  try {
    const parsed = JSON.parse(text) as TaskCardData[];
    if (!Array.isArray(parsed)) {
      return [];
    }
    return normalizeCards(parsed);
  } catch (error) {
    console.error('deserializeCards failed: ' + JSON.stringify(error));
    return [];
  }
}

export function serializeSettings(settings: CardSettings): string {
  return JSON.stringify(settings);
}

/** 反序列化设置。失败返回 undefined，调用方据此使用默认值。 */
export function deserializeSettings(text: string, fallback: CardSettings): CardSettings | undefined {
  if (typeof text !== 'string' || text === '') {
    return undefined;
  }
  try {
    const parsed = JSON.parse(text) as CardSettings;
    if (parsed === undefined || parsed === null) {
      return undefined;
    }
    return normalizeSettings(parsed, fallback);
  } catch (error) {
    console.error('deserializeSettings failed: ' + JSON.stringify(error));
    return undefined;
  }
}

export function serializeWorkState(state: WorkState): string {
  return JSON.stringify(state);
}

/** 反序列化计时状态。失败返回 undefined（表示"从未有过计时状态"）。 */
export function deserializeWorkState(text: string): WorkState | undefined {
  if (typeof text !== 'string' || text === '') {
    return undefined;
  }
  try {
    const parsed = JSON.parse(text) as WorkState;
    if (parsed === undefined || parsed === null) {
      return undefined;
    }
    return normalizeWorkState(parsed);
  } catch (error) {
    console.error('deserializeWorkState failed: ' + JSON.stringify(error));
    return undefined;
  }
}
