/**
 * 寸进 · CUNJIN —— 数组视图 <-> 统一对象模型 的双向映射（纯模块，无 @kit 依赖）
 *
 * 为什么保留数组视图：
 * 现有 Index.ets 的 1294 行 build() 与全部业务方法都以 `this.DATA_cards_*[index]` 访问数据。
 * 本阶段目标是"换掉存储格式与数据来源"，不是重写 UI。因此：
 *   - 持久化层唯一事实来源 = TaskCardData[]（JSON）
 *   - 页面内存状态 = 上述数组视图，**每次都由 fromCards() 从对象模型投影得到**
 * 两个方向各只有一处转换，避免出现两套互相独立的事实来源。
 *
 * 状态可观测性：
 * ArkUI V1 只观测数组第一层的赋值，因此所有"打卡/累加"都通过返回**新数组**实现，
 * 由调用方整体赋回 @State 字段，保证 UI 一定刷新。
 */

import { CardArrays, TaskCardData, createCardId, normalizePunchCard, normalizeNotes } from './TaskCardData';

/** 对象模型 -> 数组视图（用于加载后渲染）。 */
export function fromCards(cards: TaskCardData[]): CardArrays {
  const result: CardArrays = {
    name: [], desc: [], length: [], timeLimitDays: [], targetHours: [],
    doneHours: [], startAt: [], endAt: [], punchCard: [], notes: [], archived: []
  };
  for (let i = 0; i < cards.length; i++) {
    const card = cards[i];
    result.name.push(card.name);
    result.desc.push(card.desc);
    result.length.push(card.length);
    result.timeLimitDays.push(card.timeLimitDays);
    result.targetHours.push(card.targetHours);
    result.doneHours.push(card.doneHours);
    result.startAt.push(card.startAt);
    result.endAt.push(card.endAt);
    result.punchCard.push(card.punchCard.slice(0));
    result.notes.push(card.notes !== undefined ? card.notes.slice(0) : []);
    result.archived.push(card.archived === true);
  }
  return result;
}

/**
 * 数组视图 -> 对象模型（用于保存）。
 * existingIds 保证卡片身份稳定；缺失时用 nowMs + 下标生成新 id。
 */
export function toCards(arrays: CardArrays, existingIds: string[], nowMs: number): TaskCardData[] {
  const cards: TaskCardData[] = [];
  for (let i = 0; i < arrays.name.length; i++) {
    let id = i < existingIds.length ? existingIds[i] : '';
    if (typeof id !== 'string' || id === '') {
      id = createCardId(nowMs, i);
    }
    const timeLimit = i < arrays.timeLimitDays.length && Number.isFinite(arrays.timeLimitDays[i])
      ? Math.max(1, Math.floor(arrays.timeLimitDays[i])) : 1;
    const punchSource = i < arrays.punchCard.length ? arrays.punchCard[i] : [];
    const notesSource = i < arrays.notes.length ? arrays.notes[i] : [];
    const card: TaskCardData = {
      id: id,
      name: arrays.name[i],
      desc: i < arrays.desc.length ? arrays.desc[i] : '',
      length: i < arrays.length.length && Number.isFinite(arrays.length[i]) && arrays.length[i] > 0
        ? arrays.length[i] : 200,
      timeLimitDays: timeLimit,
      targetHours: i < arrays.targetHours.length && Number.isFinite(arrays.targetHours[i])
        ? arrays.targetHours[i] : 0,
      doneHours: i < arrays.doneHours.length && Number.isFinite(arrays.doneHours[i])
        ? Math.max(0, arrays.doneHours[i]) : 0,
      startAt: i < arrays.startAt.length && Number.isFinite(arrays.startAt[i]) ? arrays.startAt[i] : nowMs,
      endAt: i < arrays.endAt.length && Number.isFinite(arrays.endAt[i]) && arrays.endAt[i] > 0
        ? arrays.endAt[i] : nowMs + 86400000 * timeLimit,
      punchCard: normalizePunchCard(punchSource, timeLimit),
      // 归档状态与其它字段一样按下标投影：不会因为 id 反查或重建窗口期而错位
      archived: i < arrays.archived.length ? arrays.archived[i] === true : false,
      // 备注与 punchCard 同形，缺失时补空串，长度由 normalizeNotes 对齐
      notes: normalizeNotes(notesSource, timeLimit)
    };
    cards.push(card);
  }
  return cards;
}

/**
 * 不可变打卡：返回新矩阵，保证 ArkUI V1 能观测到变化。
 * 越界/非法输入原样返回（浅拷贝），不写 NaN。
 */
export function applyPunch(rows: number[][], cardIndex: number, dayIndex: number,
  record: number): number[][] {
  if (!Number.isFinite(record)) {
    return rows.slice(0);
  }
  if (!Number.isInteger(cardIndex) || cardIndex < 0 || cardIndex >= rows.length) {
    return rows.slice(0);
  }
  const row = rows[cardIndex];
  if (row === undefined || !Array.isArray(row) || row.length === 0) {
    return rows.slice(0);
  }
  let day = dayIndex;
  if (!Number.isInteger(day)) {
    return rows.slice(0);
  }
  if (day < 0) {
    day = 0;
  }
  if (day >= row.length) {
    day = row.length - 1;
  }
  const next: number[][] = rows.slice(0);
  const nextRow: number[] = row.slice(0);
  const current = Number.isFinite(nextRow[day]) ? nextRow[day] : 0;
  nextRow[day] = current + record;
  next[cardIndex] = nextRow;
  return next;
}

/**
 * 不可变累加完成时长：返回新数组。
 * 越界返回浅拷贝，绝不写入 `-1` 这类非索引属性（旧版 WORK_end_card 的真实丢数据路径）。
 */
export function creditDone(done: number[], cardIndex: number, hours: number): number[] {
  const next: number[] = done.slice(0);
  if (!Number.isInteger(cardIndex) || cardIndex < 0 || cardIndex >= next.length) {
    return next;
  }
  if (!Number.isFinite(hours) || hours <= 0) {
    return next;
  }
  const current = Number.isFinite(next[cardIndex]) ? next[cardIndex] : 0;
  next[cardIndex] = current + hours;
  return next;
}

/** 生成一张新卡片的打卡数组（长度 = 期限天数 + 1）。 */
export function createPunchCard(timeLimitDays: number): number[] {
  return normalizePunchCard([], timeLimitDays);
}

/** 计算相对天数（与旧版 UTIL_get_relative_days_passed 完全一致，避免行为漂移）。 */
export function relativeDaysPassed(from: number, to: number): number {
  return Math.floor(to / 1000 / 3600 / 24) - Math.floor(from / 3600 / 1000 / 24);
}

/** 把"今天"限制在打卡数组范围内。 */
export function clampDayIndex(day: number, punchLength: number): number {
  if (punchLength <= 0) {
    return 0;
  }
  if (!Number.isFinite(day) || day < 0) {
    return 0;
  }
  if (day >= punchLength) {
    return punchLength - 1;
  }
  return Math.floor(day);
}

// ---------------------------------------------------------------------------
// 排序（换位）支持
//
// 页面用 9 个平行数组作为投影，而持久化用的是 TaskCardData[]。
// toCards() 是按**下标**把 existingIds[i] 配给第 i 张卡片的，
// 所以任何一次重排都必须让「9 个数组」和「id 列表」同步移动，
// 否则顺序虽然保存对了，但每张卡会拿到上一任占位者的 id（身份漂移）。
//
// 这里提供纯函数版本，便于在本地单元测试中直接验证。
// ---------------------------------------------------------------------------

function isValidReorderIndex(index: number, length: number): boolean {
  return Number.isInteger(index) && index >= 0 && index < length;
}

function moveInStrings(source: string[], from: number, to: number): string[] {
  const out: string[] = source.slice(0);
  if (!isValidReorderIndex(from, out.length) || !isValidReorderIndex(to, out.length) || from === to) {
    return out;
  }
  const moved = out.splice(from, 1)[0];
  out.splice(to, 0, moved);
  return out;
}

function moveInNumbers(source: number[], from: number, to: number): number[] {
  const out: number[] = source.slice(0);
  if (!isValidReorderIndex(from, out.length) || !isValidReorderIndex(to, out.length) || from === to) {
    return out;
  }
  const moved = out.splice(from, 1)[0];
  out.splice(to, 0, moved);
  return out;
}

function moveInMatrix(source: number[][], from: number, to: number): number[][] {
  const out: number[][] = source.slice(0);
  if (!isValidReorderIndex(from, out.length) || !isValidReorderIndex(to, out.length) || from === to) {
    return out;
  }
  const moved = out.splice(from, 1)[0];
  out.splice(to, 0, moved);
  return out;
}

function swapInStrings(source: string[], first: number, second: number): string[] {
  const out: string[] = source.slice(0);
  if (!isValidReorderIndex(first, out.length) || !isValidReorderIndex(second, out.length)) {
    return out;
  }
  const temp = out[first];
  out[first] = out[second];
  out[second] = temp;
  return out;
}

function swapInNumbers(source: number[], first: number, second: number): number[] {
  const out: number[] = source.slice(0);
  if (!isValidReorderIndex(first, out.length) || !isValidReorderIndex(second, out.length)) {
    return out;
  }
  const temp = out[first];
  out[first] = out[second];
  out[second] = temp;
  return out;
}

function swapInMatrix(source: number[][], first: number, second: number): number[][] {
  const out: number[][] = source.slice(0);
  if (!isValidReorderIndex(first, out.length) || !isValidReorderIndex(second, out.length)) {
    return out;
  }
  const temp = out[first];
  out[first] = out[second];
  out[second] = temp;
  return out;
}

/** 备注矩阵（string[][]）的位移，语义与 moveInMatrix 完全一致。 */
function moveInStringMatrix(source: string[][], from: number, to: number): string[][] {
  const out: string[][] = source.slice(0);
  if (!isValidReorderIndex(from, out.length) || !isValidReorderIndex(to, out.length) || from === to) {
    return out;
  }
  const moved = out.splice(from, 1)[0];
  out.splice(to, 0, moved);
  return out;
}

/** 备注矩阵（string[][]）的交换，语义与 swapInMatrix 完全一致。 */
function swapInStringMatrix(source: string[][], first: number, second: number): string[][] {
  const out: string[][] = source.slice(0);
  if (!isValidReorderIndex(first, out.length) || !isValidReorderIndex(second, out.length)) {
    return out;
  }
  const temp = out[first];
  out[first] = out[second];
  out[second] = temp;
  return out;
}

/** 布尔数组（归档标记）的位移，与其它字段保持同一套语义。 */
function moveInBooleans(source: boolean[], from: number, to: number): boolean[] {
  const out: boolean[] = source.slice(0);
  if (!isValidReorderIndex(from, out.length) || !isValidReorderIndex(to, out.length) || from === to) {
    return out;
  }
  const moved = out.splice(from, 1)[0];
  out.splice(to, 0, moved);
  return out;
}

/** 布尔数组（归档标记）的交换。 */
function swapInBooleans(source: boolean[], first: number, second: number): boolean[] {
  const out: boolean[] = source.slice(0);
  if (!isValidReorderIndex(first, out.length) || !isValidReorderIndex(second, out.length)) {
    return out;
  }
  const temp = out[first];
  out[first] = out[second];
  out[second] = temp;
  return out;
}

/**
 * 把第 from 张卡片移动到 to 位置（其余元素依次移位）。
 * 返回新的 CardArrays，不修改入参。
 */
export function moveCardToIndex(arrays: CardArrays, from: number, to: number): CardArrays {
  const result: CardArrays = {
    name: moveInStrings(arrays.name, from, to),
    desc: moveInStrings(arrays.desc, from, to),
    length: moveInNumbers(arrays.length, from, to),
    timeLimitDays: moveInNumbers(arrays.timeLimitDays, from, to),
    targetHours: moveInNumbers(arrays.targetHours, from, to),
    doneHours: moveInNumbers(arrays.doneHours, from, to),
    startAt: moveInNumbers(arrays.startAt, from, to),
    endAt: moveInNumbers(arrays.endAt, from, to),
    punchCard: moveInMatrix(arrays.punchCard, from, to),
    notes: moveInStringMatrix(arrays.notes, from, to),
    archived: moveInBooleans(arrays.archived, from, to)
  };
  return result;
}

/** 交换两张卡片的位置。返回新的 CardArrays，不修改入参。 */
export function swapCardPositions(arrays: CardArrays, first: number, second: number): CardArrays {
  const result: CardArrays = {
    name: swapInStrings(arrays.name, first, second),
    desc: swapInStrings(arrays.desc, first, second),
    length: swapInNumbers(arrays.length, first, second),
    timeLimitDays: swapInNumbers(arrays.timeLimitDays, first, second),
    targetHours: swapInNumbers(arrays.targetHours, first, second),
    doneHours: swapInNumbers(arrays.doneHours, first, second),
    startAt: swapInNumbers(arrays.startAt, first, second),
    endAt: swapInNumbers(arrays.endAt, first, second),
    punchCard: swapInMatrix(arrays.punchCard, first, second),
    notes: swapInStringMatrix(arrays.notes, first, second),
    archived: swapInBooleans(arrays.archived, first, second)
  };
  return result;
}

/** id 列表按"移动到指定位置"同步位移，保证 id 始终跟着自己的卡片。 */
export function moveIdToIndex(ids: string[], from: number, to: number): string[] {
  return moveInStrings(ids, from, to);
}

/** id 列表按交换位置同步位移。 */
export function swapIdPositions(ids: string[], first: number, second: number): string[] {
  const out: string[] = ids.slice(0);
  if (!isValidReorderIndex(first, out.length) || !isValidReorderIndex(second, out.length)) {
    return out;
  }
  const temp = out[first];
  out[first] = out[second];
  out[second] = temp;
  return out;
}

/** 新增卡片时同步扩展 id 列表（占位空串，由 toCards() 生成真正的 id）。 */
export function appendPlaceholderId(ids: string[]): string[] {
  const out: string[] = ids.slice(0);
  out.push('');
  return out;
}

/** 删除卡片时同步移除对应 id。 */
export function removeIdAt(ids: string[], index: number): string[] {
  const out: string[] = ids.slice(0);
  if (!isValidReorderIndex(index, out.length)) {
    return out;
  }
  out.splice(index, 1);
  return out;
}

/**
 * 删除第 removed 张卡片后，一个「卡片下标」状态应该变成什么。
 *
 * 这是删除卡片时最容易出错的一步：被删的正是当前展开的那张要收起，
 * 排在它后面的要整体前移一位，排在前面的保持不变。
 * 抽成纯函数，便于单测覆盖边界（-1、相等、在其后、非法下标）。
 *
 * @param index  被修正的下标（可为 -1，表示"没有选中任何卡片"）
 * @param removed 被删除的卡片下标
 * @returns 修正后的下标；被删的就是它本身时返回 -1
 */
export function shiftIndexAfterDelete(index: number, removed: number): number {
  if (index < 0 || removed < 0) {
    return index;
  }
  if (index === removed) {
    return -1;
  }
  if (index > removed) {
    return index - 1;
  }
  return index;
}

