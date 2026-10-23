/**
 * 寸进 · CUNJIN —— 统一数据模型
 *
 * 设计约束（本次升级）：
 * 1. 本文件是纯数据模块，**不导入任何 @kit.* / @ohos.***，因此可以在本地单元测试中直接使用。
 * 2. 所有从存储读回的值都必须经过 normalize* 函数，避免 NaN / undefined / 长度不一致进入模型。
 * 3. 卡片 ID 一旦生成即持久化，保证增删排序后身份稳定。
 */

/**
 * 数据格式版本。写入 cards_v2 / settings_v2 / work_state_v2 时一并保存。
 *
 * v2 -> v3：TaskCardData 新增 `archived`。
 * v3 -> v4：CardSettings 新增 `hideArchived`（隐藏已归档卡片的显示开关）。
 * v4 -> v5：TaskCardData 新增 `notes`（与 punchCard 等长的每日备注）。
 * 兼容策略：读取时不校验版本（CardCodec 只做结构反序列化），
 * 缺少新字段的旧数据由 normalizeCard / normalizeSettings 补默认值，因此**无需迁移代码**，
 * 旧数据可直接读入，下一次保存时自动带上新字段。
 */
export const SCHEMA_VERSION: number = 5;

/** 单张任务卡片。字段语义与旧版 9 个平行数组一一对应。 */
export interface TaskCardData {
  id: string;
  name: string;
  desc: string;
  /** 卡片视觉长度（旧 DATA_cards_length），单位 vp。 */
  length: number;
  /** 完成期限（旧 DATA_cards_time_limit），单位天。 */
  timeLimitDays: number;
  /** 目标时长（旧 DATA_cards_target），单位小时。 */
  targetHours: number;
  /** 已完成时长（旧 DATA_cards_done），单位小时。 */
  doneHours: number;
  /** 开始时间戳（ms）。 */
  startAt: number;
  /** 截止时间戳（ms）。 */
  endAt: number;
  /** 每日打卡时长（小时）。长度恒为 timeLimitDays + 1，最后一位为逾期追加。 */
  punchCard: number[];
  /**
   * 是否已归档（schema 3 新增）。
   * 归档是纯手动操作，只影响显示（半透明），不隐藏卡片、不改变数组顺序、不影响计时与统计。
   * 旧数据（schema 2）没有该字段，normalizeCard 会补成 false。
   */
  archived: boolean;
  /**
   * 每日备注（schema 5 新增）。长度恒为 timeLimitDays + 1，与 punchCard 一一对应，
   * 下标含义完全相同：第 i 位 = 从 startAt 算起第 i 天的一句话。
   */
  notes: string[];
}

/** 外观设置。字段语义与旧版 use_backdrop / color_scheme_* / blur_radius / Min_block_size / APP_open_time 对应。 */
export interface CardSettings {
  schemaVersion: number;
  useBackdrop: boolean;
  colorSchemeLight: string[];
  colorSchemeDark: string[];
  blurRadius: number;
  minCardSize: number;
  appOpenTime: number;
  /**
   * 是否在卡片流里隐藏已归档的卡片（schema 4 新增）。
   * 只是显示开关：隐藏用 visibility 实现，ForEach 仍然遍历全部卡片，
   * 因此卡片下标不会变，STATUS_card_expanding 等下标状态不受影响。
   */
  hideArchived: boolean;
}

/** 计时状态。字段语义与旧版 DATA_work_* 三个 key 对应。 */
export interface WorkState {
  schemaVersion: number;
  workingCardName: string;
  workStart: number;
  workLastEnd: number;
}

/** 旧版 9 个平行数组的完整快照，仅供迁移与保存时打包使用。 */
export interface CardArrays {
  name: string[];
  desc: string[];
  length: number[];
  timeLimitDays: number[];
  targetHours: number[];
  doneHours: number[];
  startAt: number[];
  endAt: number[];
  punchCard: number[][];
  /** 每日备注，与 punchCard 同形（每张卡一条等长数组）。 */
  notes: string[][];
  /**
   * 是否已归档，按**下标**与其它数组一一对应。
   * 刻意不放在"id 旁表"里：旁表要靠 id 反查下标，新建卡片的占位 id（空串）
   * 与 cardIds 重建之间存在窗口期，会把它错判成"已归档"。
   */
  archived: boolean[];
}

function isFiniteNumber(value: number): boolean {
  return typeof value === 'number' && Number.isFinite(value);
}

function safeString(value: string, fallback: string): string {
  if (typeof value === 'string') {
    return value;
  }
  return fallback;
}

function safeNumber(value: number, fallback: number): number {
  if (isFiniteNumber(value)) {
    return value;
  }
  return fallback;
}

function safePositive(value: number, fallback: number): number {
  const n = safeNumber(value, fallback);
  if (n <= 0) {
    return fallback;
  }
  return n;
}

function safeStringArray(value: string[], fallback: string[]): string[] {
  if (Array.isArray(value) && value.length > 0) {
    const out: string[] = [];
    for (let i = 0; i < value.length; i++) {
      out.push(safeString(value[i], ''));
    }
    return out;
  }
  return fallback.slice(0);
}

/**
 * 把任意长度的打卡数组规整为 timeLimitDays + 1 长。
 * 旧数据在逾期追加时会写最后一位，因此长度不足时补 0，超出时截断。
 * 与旧版 WORK_create_punch_card(length) 的 `index <= length` 语义保持一致：
 * timeLimitDays == 0 时得到 1 格，而不是 2 格。
 */
export function normalizePunchCard(value: number[], timeLimitDays: number): number[] {
  const rawDays = safeNumber(timeLimitDays, 0);
  const days = rawDays > 0 ? Math.floor(rawDays) : 0;
  const size = Math.max(1, days + 1);
  const out: number[] = [];
  const source: number[] = Array.isArray(value) ? value : [];
  for (let i = 0; i < size; i++) {
    const cell = i < source.length ? source[i] : 0;
    const n = safeNumber(cell, 0);
    out.push(n < 0 ? 0 : n);
  }
  return out;
}

/**
 * 每日备注的结构规范化：长度与 punchCard 保持一致（timeLimitDays + 1），
 * 缺失补空串、多余截断、非字符串转成空串。绝不抛异常。
 */
export function normalizeNotes(value: string[], timeLimitDays: number): string[] {
  const rawDays = safeNumber(timeLimitDays, 0);
  const days = rawDays > 0 ? Math.floor(rawDays) : 0;
  const size = Math.max(1, days + 1);
  const out: string[] = [];
  const source: string[] = Array.isArray(value) ? value : [];
  for (let i = 0; i < size; i++) {
    out.push(i < source.length ? safeString(source[i], '') : '');
  }
  return out;
}

/** 单张卡片的结构校验 + 兜底。绝不抛异常。 */
export function normalizeCard(input: TaskCardData, fallbackId: string): TaskCardData {
  const id = safeString(input.id, '');
  const name = safeString(input.name, '');
  const timeLimitDays = Math.max(1, Math.floor(safePositive(input.timeLimitDays, 1)));
  const startAt = safeNumber(input.startAt, 0);
  const endAtRaw = safeNumber(input.endAt, 0);
  const endAt = endAtRaw > 0 ? endAtRaw : startAt + 86400000 * timeLimitDays;
  const result: TaskCardData = {
    id: id === '' ? fallbackId : id,
    name: name,
    desc: safeString(input.desc, ''),
    length: safePositive(input.length, 200),
    timeLimitDays: timeLimitDays,
    targetHours: safeNumber(input.targetHours, 0),
    doneHours: Math.max(0, safeNumber(input.doneHours, 0)),
    startAt: startAt,
    endAt: endAt,
    punchCard: normalizePunchCard(input.punchCard, timeLimitDays),
    // schema 3：旧数据没有 archived，缺省一律视为未归档
    archived: input.archived === true,
    // schema 5：旧数据没有 notes，缺省补成与 punchCard 等长的空串数组
    notes: normalizeNotes(input.notes, timeLimitDays)
  };
  return result;
}

/** 整个卡片列表的结构校验 + 兜底。丢弃空名字的条目（旧版不允许空名卡片）。 */
export function normalizeCards(input: TaskCardData[]): TaskCardData[] {
  const out: TaskCardData[] = [];
  if (!Array.isArray(input)) {
    return out;
  }
  for (let i = 0; i < input.length; i++) {
    const raw = input[i];
    if (raw === undefined || raw === null) {
      continue;
    }
    const card = normalizeCard(raw, 'card_' + i.toString());
    if (card.name === '') {
      continue;
    }
    out.push(card);
  }
  return out;
}

export function createDefaultSettings(light: string[], dark: string[], blurRadius: number,
  minCardSize: number): CardSettings {
  const settings: CardSettings = {
    schemaVersion: SCHEMA_VERSION,
    useBackdrop: false,
    colorSchemeLight: light.slice(0),
    colorSchemeDark: dark.slice(0),
    blurRadius: blurRadius,
    minCardSize: minCardSize,
    appOpenTime: 0,
    hideArchived: false
  };
  return settings;
}

export function normalizeSettings(input: CardSettings, fallback: CardSettings): CardSettings {
  const result: CardSettings = {
    schemaVersion: SCHEMA_VERSION,
    useBackdrop: typeof input.useBackdrop === 'boolean' ? input.useBackdrop : fallback.useBackdrop,
    colorSchemeLight: safeStringArray(input.colorSchemeLight, fallback.colorSchemeLight),
    colorSchemeDark: safeStringArray(input.colorSchemeDark, fallback.colorSchemeDark),
    blurRadius: safePositive(input.blurRadius, fallback.blurRadius),
    minCardSize: safePositive(input.minCardSize, fallback.minCardSize),
    appOpenTime: Math.max(0, Math.floor(safeNumber(input.appOpenTime, fallback.appOpenTime))),
    // schema 4：旧数据没有该字段，缺省沿用兜底值（默认 false）
    hideArchived: typeof input.hideArchived === 'boolean' ? input.hideArchived : fallback.hideArchived
  };
  return result;
}

export function createEmptyWorkState(): WorkState {
  const state: WorkState = {
    schemaVersion: SCHEMA_VERSION,
    workingCardName: '',
    workStart: 0,
    workLastEnd: 0
  };
  return state;
}

export function normalizeWorkState(input: WorkState): WorkState {
  const result: WorkState = {
    schemaVersion: SCHEMA_VERSION,
    workingCardName: safeString(input.workingCardName, ''),
    workStart: Math.max(0, safeNumber(input.workStart, 0)),
    workLastEnd: Math.max(0, safeNumber(input.workLastEnd, 0))
  };
  return result;
}

/**
 * 生成卡片 ID。时间戳由调用方传入，保持本模块纯净可测。
 * 同一次调用内用 seq 去重，避免同一毫秒新增多张卡片时冲突。
 */
export function createCardId(nowMs: number, seq: number): string {
  return 'card_' + Math.floor(nowMs).toString() + '_' + seq.toString();
}
