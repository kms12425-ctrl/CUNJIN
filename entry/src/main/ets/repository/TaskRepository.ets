/**
 * 寸进 · CUNJIN —— 唯一持久化入口
 *
 * 存储布局（新格式，全部 JSON）：
 *   cards_v2           TaskCardData[]  —— 唯一卡片事实来源
 *   settings_v2        CardSettings    —— 外观设置
 *   work_state_v2      WorkState       —— 计时状态
 *   migration_v2_done  "true"          —— 迁移完成标记（最后写入）
 *
 * 旧格式（只读，永不删除，便于回滚）：
 *   9 个 cards_* key + 3 个 DATA_work_* key + 6 个外观 key（见 LegacyCodec）
 *
 * 数据安全承诺：
 *   - 写入串行化（write chain），避免并发 put 互相覆盖。
 *   - 迁移只有在"新 JSON 写入成功并回读校验通过"之后才写完成标记。
 *   - 若 cards_v2 已有有效数据，迁移直接让位，绝不用旧数据覆盖新数据。
 *   - 旧 key 一律不删。
 */

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { CardSettings, TaskCardData, WorkState, createDefaultSettings } from '../model/TaskCardData';
import {
  deserializeCards, deserializeSettings, deserializeWorkState,
  serializeCards, serializeSettings, serializeWorkState
} from '../model/CardCodec';
import {
  LegacyCardRaw, LegacySettingsRaw, LegacyWorkRaw,
  decodeLegacyCards, decodeLegacySettings, decodeLegacyWorkState,
  isLegacySentinel
} from '../model/LegacyCodec';
import { Storage } from './Storage';

const DOMAIN: number = 0x0000;
const TAG: string = 'Cunjin.Repository';

const KEY_CARDS: string = 'cards_v2';
const KEY_SETTINGS: string = 'settings_v2';
const KEY_WORK: string = 'work_state_v2';
const KEY_MIGRATION: string = 'migration_v2_done';

// ---- 旧版只读 key ----
const LEGACY_NAME: string = 'cards_name';
const LEGACY_DESC: string = 'cards_desc';
const LEGACY_LENGTH: string = 'cards_length';
const LEGACY_TIME_LIMIT: string = 'cards_time_limit';
const LEGACY_TARGET: string = 'cards_target';
const LEGACY_DONE: string = 'cards_done';
const LEGACY_START: string = 'cards_start';
const LEGACY_END: string = 'cards_end';
const LEGACY_PUNCH: string = 'cards_punch_card';
const LEGACY_WORK_NAME: string = 'DATA_work_working_card_name';
const LEGACY_WORK_START: string = 'DATA_work_start';
const LEGACY_WORK_LAST_END: string = 'DATA_work_last_end';
const LEGACY_USE_BACKDROP: string = 'use_backdrop';
const LEGACY_SCHEME_LIGHT: string = 'color_scheme_light';
const LEGACY_SCHEME_DARK: string = 'color_scheme_dark';
const LEGACY_BLUR: string = 'blur_radius';
const LEGACY_MIN_BLOCK: string = 'Min_block_size';
const LEGACY_APP_OPEN: string = 'APP_open_time';

/** 迁移结果，便于上层记录与日志。 */
export interface MigrationOutcome {
  migrated: boolean;
  reason: string;
  cardCount: number;
  warnings: string[];
  /** 是否为"全新安装"的第一次启动（用于保持旧版 Welcome 文案行为）。 */
  firstRun: boolean;
}

export class TaskRepository {
  private static context: common.Context | null = null;
  private static initTask: Promise<void> | null = null;
  private static chain: Promise<void> = new Promise<void>((resolve) => {
    resolve();
  });
  private static failure: string = '';

  /** 由 EntryAbility.onCreate 调用一次。幂等，失败可重试。 */
  static init(context: common.Context): Promise<void> {
    TaskRepository.context = context;
    if (TaskRepository.initTask === null) {
      const attempt = Storage.init(context);
      TaskRepository.initTask = attempt;
      attempt.catch(() => {
        if (TaskRepository.initTask === attempt) {
          TaskRepository.initTask = null;
        }
      });
    }
    return TaskRepository.initTask as Promise<void>;
  }

  /** 等待存储就绪。未初始化时给出明确错误，而不是永远挂起。 */
  static async waitReady(): Promise<void> {
    if (TaskRepository.initTask === null) {
      if (TaskRepository.context === null) {
        throw new Error('TaskRepository 未初始化：请先调用 TaskRepository.init(context)');
      }
      await TaskRepository.init(TaskRepository.context);
      return;
    }
    await (TaskRepository.initTask as Promise<void>);
  }

  static lastFailure(): string {
    return TaskRepository.failure;
  }

  private static async read(key: string): Promise<string | undefined> {
    await TaskRepository.waitReady();
    return await Storage.get(key);
  }

  private static async write(key: string, value: string): Promise<void> {
    await TaskRepository.waitReady();
    await Storage.put(key, value);
  }

  /** 串行化写入，保证多次保存按调用顺序落盘，不会互相覆盖。 */
  private static enqueue(label: string, task: () => Promise<void>): Promise<void> {
    const runner = async (): Promise<void> => {
      try {
        await task();
      } catch (error) {
        const err = error as Error;
        TaskRepository.failure = label + ': ' + err.message;
        hilog.error(DOMAIN, TAG, '%{public}s', 'write failed -> ' + TaskRepository.failure);
      }
    };
    const next: Promise<void> = TaskRepository.chain.then(runner);
    TaskRepository.chain = next;
    return next;
  }

  /** 等待所有排队中的写入落盘。加载前调用，避免"刚写入还没落盘就读到旧值"。 */
  static async flushPendingWrites(): Promise<void> {
    await TaskRepository.chain;
  }

  // ------------------------------------------------------------------ 卡片

  static async loadCards(): Promise<TaskCardData[]> {
    const text = await TaskRepository.read(KEY_CARDS);
    if (text === undefined || text === '') {
      return [];
    }
    return deserializeCards(text);
  }

  /** 同步排队保存，返回的 Promise 可用于测试等待落盘。 */
  static saveCards(cards: TaskCardData[]): Promise<void> {
    const payload = serializeCards(cards);
    return TaskRepository.enqueue('saveCards', async () => {
      await TaskRepository.write(KEY_CARDS, payload);
    });
  }

  /** 迁移专用：直接 await 写入（不经队列，保证顺序可控）。 */
  private static async writeCardsDirect(cards: TaskCardData[]): Promise<void> {
    await TaskRepository.write(KEY_CARDS, serializeCards(cards));
  }

  // ------------------------------------------------------------------ 设置

  static async loadSettings(defaults: CardSettings): Promise<CardSettings | undefined> {
    const text = await TaskRepository.read(KEY_SETTINGS);
    if (text === undefined || text === '') {
      return undefined;
    }
    return deserializeSettings(text, defaults);
  }

  static saveSettings(settings: CardSettings): Promise<void> {
    const payload = serializeSettings(settings);
    return TaskRepository.enqueue('saveSettings', async () => {
      await TaskRepository.write(KEY_SETTINGS, payload);
    });
  }

  // --------------------------------------------------------------- 计时状态

  static async loadWorkState(): Promise<WorkState | undefined> {
    const text = await TaskRepository.read(KEY_WORK);
    if (text === undefined || text === '') {
      return undefined;
    }
    return deserializeWorkState(text);
  }

  static saveWorkState(state: WorkState): Promise<void> {
    const payload = serializeWorkState(state);
    return TaskRepository.enqueue('saveWorkState', async () => {
      await TaskRepository.write(KEY_WORK, payload);
    });
  }

  // ------------------------------------------------------------------ 迁移

  /**
   * 一次性把旧 CSV 数据迁移到新 JSON。
   * 幂等：成功后写 migration_v2_done，之后直接返回。
   */
  static async ensureLegacyMigrated(defaults: CardSettings): Promise<MigrationOutcome> {
    await TaskRepository.waitReady();

    const flag = await TaskRepository.read(KEY_MIGRATION);
    if (flag === 'true') {
      const outcome: MigrationOutcome = {
        migrated: false, reason: 'already-migrated', cardCount: 0, warnings: [], firstRun: false
      };
      return outcome;
    }

    // 新数据已存在 -> 保护新数据，绝不用旧数据覆盖
    const existingText = await TaskRepository.read(KEY_CARDS);
    if (existingText !== undefined && existingText !== '') {
      const existing = deserializeCards(existingText);
      if (existing.length > 0) {
        await TaskRepository.write(KEY_MIGRATION, 'true');
        const outcome: MigrationOutcome = {
          migrated: false, reason: 'new-data-exists', cardCount: existing.length, warnings: [],
          firstRun: false
        };
        return outcome;
      }
    }

    const legacyName = await TaskRepository.read(LEGACY_NAME);
    const legacyDesc = await TaskRepository.read(LEGACY_DESC);
    const legacyLength = await TaskRepository.read(LEGACY_LENGTH);
    const legacyTimeLimit = await TaskRepository.read(LEGACY_TIME_LIMIT);
    const legacyTarget = await TaskRepository.read(LEGACY_TARGET);
    const legacyDone = await TaskRepository.read(LEGACY_DONE);
    const legacyStart = await TaskRepository.read(LEGACY_START);
    const legacyEnd = await TaskRepository.read(LEGACY_END);
    const legacyPunch = await TaskRepository.read(LEGACY_PUNCH);

    const cardRaw: LegacyCardRaw = {
      cardsName: legacyName,
      cardsDesc: legacyDesc,
      cardsLength: legacyLength,
      cardsTimeLimit: legacyTimeLimit,
      cardsTarget: legacyTarget,
      cardsDone: legacyDone,
      cardsStart: legacyStart,
      cardsEnd: legacyEnd,
      cardsPunchCard: legacyPunch
    };

    if (isLegacySentinel(cardRaw)) {
      // 旧版存储未就绪时写入的伪数据。不迁移，也不覆盖任何东西。
      await TaskRepository.write(KEY_MIGRATION, 'true');
      const outcome: MigrationOutcome = {
        migrated: false, reason: 'legacy-sentinel', cardCount: 0,
        warnings: ['旧版数据全部为 "no" 哨兵，已跳过迁移并保留原 key。'], firstRun: false
      };
      return outcome;
    }

    const decoded = decodeLegacyCards(cardRaw, Date.now());

    const settingsRaw: LegacySettingsRaw = {
      useBackdrop: await TaskRepository.read(LEGACY_USE_BACKDROP),
      colorSchemeLight: await TaskRepository.read(LEGACY_SCHEME_LIGHT),
      colorSchemeDark: await TaskRepository.read(LEGACY_SCHEME_DARK),
      blurRadius: await TaskRepository.read(LEGACY_BLUR),
      minBlockSize: await TaskRepository.read(LEGACY_MIN_BLOCK),
      appOpenTime: await TaskRepository.read(LEGACY_APP_OPEN)
    };
    const workRaw: LegacyWorkRaw = {
      workingCardName: await TaskRepository.read(LEGACY_WORK_NAME),
      workStart: await TaskRepository.read(LEGACY_WORK_START),
      workLastEnd: await TaskRepository.read(LEGACY_WORK_LAST_END)
    };

    const migratedSettings = decodeLegacySettings(settingsRaw, defaults,
      defaults.blurRadius, defaults.minCardSize);
    const migratedWork = decodeLegacyWorkState(workRaw,
      { schemaVersion: defaults.schemaVersion, workingCardName: '', workStart: 0, workLastEnd: 0 });

    // "全新安装"判定：新存储与旧存储都没有任何卡片痕迹。
    // 用于保持旧版首启显示 Welcome 文案的行为（与是否已写入设置默认值无关）。
    const hadSettings = await TaskRepository.read(KEY_SETTINGS);
    const hasLegacyCards = (cardRaw.cardsName !== undefined && cardRaw.cardsName !== '') ||
      (cardRaw.cardsDesc !== undefined && cardRaw.cardsDesc !== '');
    const firstRun = (existingText === undefined || existingText === '') &&
      (hadSettings === undefined || hadSettings === '') && !hasLegacyCards;

    // 先写数据，再校验，最后才写标记
    if (decoded.cards.length > 0) {
      await TaskRepository.writeCardsDirect(decoded.cards);
    }
    await TaskRepository.write(KEY_SETTINGS, serializeSettings(migratedSettings));
    await TaskRepository.write(KEY_WORK, serializeWorkState(migratedWork));

    if (decoded.cards.length > 0) {
      const verifyText = await TaskRepository.read(KEY_CARDS);
      const verified = verifyText === undefined ? [] : deserializeCards(verifyText);
      if (verified.length !== decoded.cards.length) {
        const failed: MigrationOutcome = {
          migrated: false,
          reason: 'verify-failed',
          cardCount: verified.length,
          warnings: decoded.warnings.concat(['回读校验失败：期望 ' + decoded.cards.length.toString() +
            ' 张，实际 ' + verified.length.toString() + ' 张。已保留旧 key，未写迁移标记。']),
          firstRun: false
        };
        return failed;
      }
    }

    await TaskRepository.write(KEY_MIGRATION, 'true');
    const ok: MigrationOutcome = {
      migrated: decoded.cards.length > 0,
      reason: decoded.cards.length > 0 ? 'ok' : 'no-legacy-cards',
      cardCount: decoded.cards.length,
      warnings: decoded.warnings,
      firstRun: firstRun
    };
    return ok;
  }

  /** 便于测试注入初始默认值（不影响正常运行）。 */
  static defaultSettingsForTest(light: string[], dark: string[]): CardSettings {
    return createDefaultSettings(light, dark, 25, 450);
  }
}
